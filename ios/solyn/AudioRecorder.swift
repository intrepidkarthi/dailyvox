//
//  AudioRecorder.swift
//  solyn
//
//  Handles audio recording for voice diary entries.
//  Recordings are stored locally in the app's sandboxed container.
//
//  Privacy: Audio files never leave the device unless explicitly exported by user.
//

import Foundation
import AVFoundation

/// Manages audio recording for voice diary entries.
/// All recordings are stored in the app's protected Application Support directory.
final class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    /// Screenshot mode seeds these so the store frame shows the dial mid-take —
    /// a simulator has no microphone, so a real recording cannot be captured,
    /// and a dial reading 0:00 with no ticks lit advertises nothing.
    @Published var currentTime: TimeInterval =
        ScreenshotScene.current == .recording ? 28 : 0
    @Published var level: Float =
        ScreenshotScene.current == .recording ? 0.62 : 0  // 0...1 normalized audio level

    // MARK: - Private Properties
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    /// Live partials for the dial and the Dynamic Island.
    ///
    /// Deliberately a separate object with its own audio engine rather than a
    /// rewrite of this class onto `AVAudioEngine`. The file recorder here is the
    /// product and it is proven; the live line is a nicety. Keeping them apart
    /// means the worst case is "no live text on some device", not "no
    /// recording" — and `LiveTranscriber.start()` is best-effort by design.
    ///
    /// Built lazily on the main actor: `LiveTranscriber` is `@MainActor` and this
    /// class is not, so a stored-property initialiser would be a cross-actor
    /// call at init time.
    @MainActor private(set) lazy var live = LiveTranscriber()

    /// The last live values seen, so the 2 Hz Live Activity push carries them
    /// without reaching across actors on every timer tick.
    private var lastPhrase = ""
    private var lastCaught: String?
    private var lastValence: Double = 0

    /// True when the SYSTEM paused us — a call, an alarm, Siri — rather than the
    /// user. Kept apart because only a system pause should auto-resume.
    private var interrupted = false
    
    // MARK: - Interruptions

    /// A phone call used to end the entry, silently.
    ///
    /// `AVAudioRecorder` stops when the session is interrupted and nothing here
    /// was listening, so the recording simply stopped — no save, no message, and
    /// the dial still counting up over a microphone that was no longer open.
    /// Someone talking through the thing that upset them lost it to a spam call.
    ///
    /// Now an interruption pauses, exactly as the Pause button does, and the
    /// audio captured so far is intact. If the system says it is safe to resume
    /// we do; otherwise the dial sits paused and the user decides. Nothing is
    /// ever thrown away on our side.
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            guard recorder?.isRecording == true else { return }
            interrupted = true
            pauseRecording()
            NotificationCenter.default.post(name: .dailyVoxRecordingInterrupted, object: true)

        case .ended:
            guard interrupted else { return }
            interrupted = false
            let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            guard options.contains(.shouldResume) else {
                // Left paused on purpose. Coming back to a dial that is clearly
                // waiting is better than one that silently restarted while the
                // phone was still at someone's ear.
                return
            }
            try? AVAudioSession.sharedInstance().setActive(true)
            resumeRecording()
            NotificationCenter.default.post(name: .dailyVoxRecordingInterrupted, object: false)

        @unknown default:
            break
        }
    }

    // MARK: - Recording

    func startRecording() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = try Self.newRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        recorder.record()

        self.recorder = recorder
        isRecording = true
        interrupted = false
        observeInterruptions()
        Self.activeRecording = true
        currentTime = 0
        level = 0

        Task { @MainActor in
            LiveActivityManager.shared.startRecordingActivity()
            self.live.start()
        }

        timer?.invalidate()
        var lastActivityPush: TimeInterval = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160...0 dB
            let normalized = max(0, min(1, (power + 60) / 60))
            self.level = normalized
            self.currentTime = recorder.currentTime

            // Throttle Live Activity updates to ~2 Hz to stay under ActivityKit
            // budget while still feeling responsive.
            if recorder.currentTime - lastActivityPush >= 0.5 {
                lastActivityPush = recorder.currentTime
                let elapsed = recorder.currentTime
                Task { @MainActor in
                    self.lastPhrase = self.live.phrase
                    self.lastCaught = self.live.caughtName
                    self.lastValence = self.live.valence
                    LiveActivityManager.shared.updateRecordingActivity(
                        elapsed: elapsed,
                        level: normalized,
                        phrase: self.lastPhrase,
                        caughtName: self.lastCaught,
                        valence: self.lastValence,
                        paused: !self.isRecording
                    )
                }
            }
        }
        #else
        throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording is only available on iOS."])
        #endif
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = recorder else { return nil }
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        Self.activeRecording = false
        level = 0
        let url = recorder.url
        let duration = recorder.currentTime
        self.recorder = nil

        Task { @MainActor in
            self.live.stop()
            LiveActivityManager.shared.endRecordingActivity()
        }

        return (url, duration)
    }

    /// Pause without ending the entry (B2b).
    ///
    /// `AVAudioRecorder.pause()` keeps the file open and the encoder primed, so
    /// `record()` resumes into the same file — one recording, one artefact. The
    /// elapsed `currentTime` also stops advancing on its own, which is what the
    /// dial reads.
    func pauseRecording() {
        guard let recorder, recorder.isRecording else { return }
        recorder.pause()
        isRecording = false
        level = 0
        Task { @MainActor in self.live.pause() }
    }

    func resumeRecording() {
        guard let recorder, !recorder.isRecording else { return }
        recorder.record()
        isRecording = true
        Task { @MainActor in self.live.resume() }
    }

    /// Stop and DELETE (B2b's ✕).
    ///
    /// Discard has to leave nothing behind, and the audio file is the part that
    /// outlives a thrown-away transcript. Nothing is returned because there is
    /// deliberately nothing to hand back.
    func discardRecording() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        Self.activeRecording = false
        level = 0
        currentTime = 0
        self.recorder = nil
        try? FileManager.default.removeItem(at: url)

        Task { @MainActor in
            self.live.stop()
            LiveActivityManager.shared.endRecordingActivity()
        }
    }

    // MARK: - File Management
    
    /// Returns the directory for storing recordings.
    /// Located in Application Support, which is protected by iOS sandbox.
    private static func recordingsDirectory() throws -> URL {
        let fileManager = FileManager.default
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory."])
        }
        let directory = base.appendingPathComponent("Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }

    /// Generates a unique filename for a new recording.
    /// Uses UUID to prevent filename collisions and avoid exposing metadata.
    private static func newRecordingURL() throws -> URL {
        let directory = try recordingsDirectory()
        let filename = UUID().uuidString + ".m4a"
        return directory.appendingPathComponent(filename)
    }
    
    /// Whether a recording is currently in progress (shared flag for cleanup guard).
    private static var activeRecording = false

    /// Cleans up old recording files that are no longer referenced.
    /// Called periodically to manage storage.
    static func cleanupOrphanedRecordings(keepURLs: Set<URL>) {
        guard !activeRecording else { return }
        do {
            let directory = try recordingsDirectory()
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files where !keepURLs.contains(file) {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            // Silently fail - cleanup is not critical
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {}
