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
    @Published var currentTime: TimeInterval = 0
    @Published var level: Float = 0  // 0...1 normalized audio level

    // MARK: - Private Properties
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    
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
        Self.activeRecording = true
        currentTime = 0
        level = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160...0 dB
            let normalized = max(0, min(1, (power + 60) / 60))
            self.level = normalized
            self.currentTime = recorder.currentTime
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
        return (url, duration)
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
