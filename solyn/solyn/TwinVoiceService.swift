//
//  TwinVoiceService.swift
//  solyn
//
//  Reads the Twin's replies aloud — in your own voice, if you have one.
//
//  Apple's Personal Voice is built from recordings of you reading sentences, so it carries
//  your accent and cadence, not just your timbre. That is the whole reason it is used here:
//  voice-conversion models we evaluated transferred timbre convincingly and accent not at all.
//
//  Nothing leaves the device. Personal Voice is generated and stored on-device, synthesis is
//  local, and Apple does not permit apps to capture its output — so there is no audio file to
//  cache, export or leak. The app can make it speak and nothing more, which happens to be
//  exactly what we want.
//

import AVFoundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.dailyvox.app", category: "TwinVoice")

@MainActor
final class TwinVoiceService: NSObject, ObservableObject {
    static let shared = TwinVoiceService()

    private let enabledKey = "twinVoice_enabled"
    private let usePersonalKey = "twinVoice_usePersonalVoice"

    private let synthesizer = AVSpeechSynthesizer()

    /// Master switch. Off by default: speech that starts without being asked for is a
    /// nasty surprise in an app people use in bed.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if !isEnabled { stop() }
        }
    }

    /// Prefer the user's Personal Voice when one exists and access was granted.
    @Published var preferPersonalVoice: Bool {
        didSet { UserDefaults.standard.set(preferPersonalVoice, forKey: usePersonalKey) }
    }

    @Published private(set) var personalVoiceStatus: PersonalVoiceStatus = .notDetermined
    @Published private(set) var isSpeaking = false

    enum PersonalVoiceStatus: Equatable {
        /// Not yet asked. We ask lazily, on first use, not at launch.
        case notDetermined
        /// Granted, and a Personal Voice exists on this device.
        case available(voiceName: String)
        /// Granted, but the user has not created a Personal Voice yet.
        case authorizedButNoneCreated
        /// The user declined. Falls back to a system voice.
        case denied
        /// Device or OS cannot do Personal Voice (needs iOS 17+ and iPhone 12 or later).
        case unsupported

        var canUsePersonalVoice: Bool {
            if case .available = self { return true }
            return false
        }
    }

    /// Screenshot and UI-test runs must never trigger the permission alert or start audio.
    private static let disabledForTesting =
        ProcessInfo.processInfo.arguments.contains("-UITesting") ||
        ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")

    private override init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        // Default the *preference* on — it only takes effect once the user grants access and
        // has actually made a voice, so it cannot surprise anyone.
        self.preferPersonalVoice = UserDefaults.standard.object(forKey: usePersonalKey) as? Bool ?? true
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Authorization

    /// Ask for Personal Voice access. Safe to call repeatedly; only prompts once.
    func refreshPersonalVoiceStatus() {
        guard !Self.disabledForTesting else { personalVoiceStatus = .unsupported; return }
        guard #available(iOS 17.0, *) else { personalVoiceStatus = .unsupported; return }

        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    if let v = Self.personalVoice() {
                        self.personalVoiceStatus = .available(voiceName: v.name)
                    } else {
                        self.personalVoiceStatus = .authorizedButNoneCreated
                    }
                case .denied, .unsupported:
                    self.personalVoiceStatus = (status == .denied) ? .denied : .unsupported
                case .notDetermined:
                    self.personalVoiceStatus = .notDetermined
                @unknown default:
                    self.personalVoiceStatus = .unsupported
                }
                logger.info("Personal Voice status: \(String(describing: self.personalVoiceStatus))")
            }
        }
    }

    private static func personalVoice() -> AVSpeechSynthesisVoice? {
        guard #available(iOS 17.0, *) else { return nil }
        return AVSpeechSynthesisVoice.speechVoices()
            .first { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    /// The voice we will actually use: the user's own if permitted and present, otherwise a
    /// system voice matching their language so the accent is at least in the right family.
    private var resolvedVoice: AVSpeechSynthesisVoice? {
        if preferPersonalVoice, personalVoiceStatus.canUsePersonalVoice, let mine = Self.personalVoice() {
            return mine
        }
        let lang = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        return AVSpeechSynthesisVoice(language: lang)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Speaking

    func speak(_ text: String) {
        guard !Self.disabledForTesting else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        // .playback so a reply still speaks with the ringer switch flipped — someone who taps
        // "read this aloud" means it. .spokenAudio ducks other audio rather than killing it.
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            logger.error("Audio session for speech failed: \(error.localizedDescription)")
        }
        #endif

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = resolvedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        deactivateSession()
    }

    func toggle(_ text: String) {
        if isSpeaking { stop() } else { speak(text) }
    }

    private func deactivateSession() {
        #if os(iOS)
        // Hand the session back so recording is not left fighting a playback category.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// Copy for Settings, so the UI never has to reason about the status enum.
    var statusDescription: String {
        switch personalVoiceStatus {
        case .available(let name):
            return "Using your Personal Voice (\(name))."
        case .authorizedButNoneCreated:
            return "No Personal Voice yet. Create one in Settings → Accessibility → Personal Voice, then come back — replies will use your own voice, accent and all."
        case .denied:
            return "Personal Voice access was declined, so replies use a system voice. You can change this in Settings → Accessibility → Personal Voice."
        case .notDetermined:
            return "DailyVox can read replies in your own voice if you have a Personal Voice set up."
        case .unsupported:
            return "Personal Voice needs iOS 17 or later on iPhone 12 or later. Replies will use a system voice."
        }
    }
}

extension TwinVoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false; self.deactivateSession() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false; self.deactivateSession() }
    }
}
