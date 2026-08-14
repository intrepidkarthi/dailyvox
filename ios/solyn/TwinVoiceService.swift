//
//  TwinVoiceService.swift
//  solyn
//
//  Reads the Twin's replies aloud, using the system voices already on the device.
//
//  Deliberately simple. An earlier revision led with Apple's Personal Voice, which does carry the
//  user's real accent — but it costs a ~30-minute enrollment (150 sentences read aloud in Settings)
//  that the app cannot perform on the user's behalf. If the creator won't do it, users won't either,
//  so the feature is built on voices already present and asks nothing of anyone.
//
//  Accent is therefore approximated, not reproduced: the picker exposes every installed voice for
//  the user's language, including regional variants (en-IN, en-GB, en-AU…), and defaults to the one
//  matching their locale. That is as close as this gets without a model that clones accent at a size
//  a phone can hold — see project_voice_cloning_spike for why none exists yet. Personal Voice, or a
//  cloning model when one qualifies, slots in behind `resolvedVoice` without touching callers.
//
//  Nothing leaves the device: AVSpeechSynthesizer synthesis is local.
//

import AVFoundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.dailyvox.app", category: "TwinVoice")

@MainActor
final class TwinVoiceService: NSObject, ObservableObject {
    static let shared = TwinVoiceService()

    private let enabledKey = "twinVoice_enabled"
    private let voiceKey = "twinVoice_voiceIdentifier"

    private let synthesizer = AVSpeechSynthesizer()

    /// Off by default. Speech that starts without being asked for is a nasty surprise in an app
    /// people use in bed.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if !isEnabled { stop() }
        }
    }

    /// Chosen voice, by AVSpeechSynthesisVoice identifier. Empty means "follow the locale".
    @Published var voiceIdentifier: String {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: voiceKey) }
    }

    @Published private(set) var isSpeaking = false

    private static let disabledForTesting =
        ProcessInfo.processInfo.arguments.contains("-UITesting") ||
        ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")

    private override init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        self.voiceIdentifier = UserDefaults.standard.string(forKey: voiceKey) ?? ""
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voices

    /// Installed voices for the user's language, deduplicated by name keeping the best quality.
    /// Scoped to one language so the picker is a short list rather than a hundred rows.
    var availableVoices: [AVSpeechSynthesisVoice] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        var bestByName: [String: AVSpeechSynthesisVoice] = [:]
        for v in AVSpeechSynthesisVoice.speechVoices() where v.language.hasPrefix(lang) {
            if let existing = bestByName[v.name], existing.quality.rawValue >= v.quality.rawValue { continue }
            bestByName[v.name] = v
        }
        let full = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        return bestByName.values.sorted {
            // Regional match to the full locale first — an en-IN user should find Indian English at
            // the top rather than hunting for it.
            let a = ($0.language == full), b = ($1.language == full)
            if a != b { return a }
            if $0.language != $1.language { return $0.language < $1.language }
            return $0.name < $1.name
        }
    }

    /// The voice actually used: the explicit choice, else the closest locale match.
    var resolvedVoice: AVSpeechSynthesisVoice? {
        if !voiceIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return chosen
        }
        let full = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        return AVSpeechSynthesisVoice(language: full)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    func label(for voice: AVSpeechSynthesisVoice) -> String {
        let region = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        return "\(voice.name) · \(region)"
    }

    // MARK: - Speaking

    func speak(_ text: String) {
        guard !Self.disabledForTesting else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        // .playback so a reply still speaks with the ringer switch flipped — someone who tapped
        // "read aloud" meant it. .spokenAudio ducks other audio rather than killing it.
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

    /// Short sample so a voice can be auditioned in Settings without going back to the chat.
    func preview() {
        speak("This is how your Twin will sound when it reads a reply back to you.")
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
        deactivateSession()
    }

    private func deactivateSession() {
        #if os(iOS)
        // Hand the session back so recording is not left fighting a playback category.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
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
