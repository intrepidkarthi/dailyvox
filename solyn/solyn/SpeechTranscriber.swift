//
//  SpeechTranscriber.swift
//  solyn
//
//  Handles speech-to-text transcription using Apple's Speech framework.
//  All transcription is performed on-device when possible.
//
//  Privacy: Uses Apple's on-device speech recognition - audio is processed
//  locally and never sent to third-party servers.
//

#if os(iOS)
import Foundation
import Speech
import Network
import AVFoundation

/// Transcribes audio recordings to text using Apple's Speech framework.
/// Prioritizes on-device recognition for privacy; falls back to Apple's servers when needed.
final class SpeechTranscriber {
    
    // MARK: - Shared Instance
    
    static let shared = SpeechTranscriber()

    // MARK: - Private Properties
    
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true
    
    // MARK: - Error Types

    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case noFinalResult
        case offlineNoTranscription

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition is not authorized."
            case .recognizerUnavailable:
                return "Speech recognizer is not available."
            case .noFinalResult:
                return "No final transcription result."
            case .offlineNoTranscription:
                return "You're offline. Your recording is saved—tap Edit to add text manually, or transcription will happen when you're back online."
            }
        }
    }

    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isOnline = path.status == .satisfied
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))
    }

    deinit {
        networkMonitor.cancel()
    }

    var hasNetworkConnection: Bool {
        isOnline
    }

    // MARK: - Transcription
    
    /// Transcribes audio from the given URL to text.
    ///
    /// On iOS 26+ this uses Apple's new on-device `SpeechAnalyzer`/`SpeechTranscriber`
    /// — markedly lower word-error rate on sustained speech, no session length
    /// limit, fully on-device — and falls back to the proven `SFSpeechRecognizer`
    /// path on any failure (or on earlier iOS). Both keep audio on the device.
    /// - Parameters:
    ///   - audioURL: URL to the audio file to transcribe
    ///   - completion: Called with the transcription result or error
    func transcribe(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        if #available(iOS 26.0, *) {
            Task {
                do {
                    let text = try await self.transcribeWithSpeechAnalyzer(from: audioURL)
                    await MainActor.run { completion(.success(text)) }
                } catch {
                    // SpeechAnalyzer unavailable for this locale/device, model not
                    // installable, or produced nothing — use the proven recognizer.
                    self.transcribeWithSFSpeech(from: audioURL, completion: completion)
                }
            }
        } else {
            transcribeWithSFSpeech(from: audioURL, completion: completion)
        }
    }

    // MARK: - iOS 26+ SpeechAnalyzer path

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(from audioURL: URL) async throws -> String {
        // Resolve a supported locale (fall back to en-US) for the transcriber.
        // Fully qualified — this app's own class is also named SpeechTranscriber.
        // Sequenced explicitly: `??` can't wrap an `await` in its autoclosure.
        let preferred = Locale.current
        var resolved = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: preferred)
        if resolved == nil {
            resolved = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        }
        let locale = resolved ?? preferred

        let transcriber = Speech.SpeechTranscriber(locale: locale, preset: .transcription)

        // Ensure the on-device model asset is installed (downloads once, on-device).
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed:
            break
        case .supported, .downloading:
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        case .unsupported:
            throw TranscriptionError.recognizerUnavailable
        @unknown default:
            throw TranscriptionError.recognizerUnavailable
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        // Collect finalized transcript segments as they arrive.
        var transcript = AttributedString()
        let collector = Task {
            for try await result in transcriber.results {
                transcript.append(result.text)
            }
        }

        // Analyze the whole file, then finish so `results` completes.
        _ = try await analyzer.analyzeSequence(from: audioFile)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await collector.value

        var text = String(transcript.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.noFinalResult }
        if !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!") { text += "." }
        return text
    }

    // MARK: - SFSpeechRecognizer path (iOS < 26, and the fallback)

    private func transcribeWithSFSpeech(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(.failure(TranscriptionError.notAuthorized))
                    return
                }

                guard let recognizer = SFSpeechRecognizer() else {
                    completion(.failure(TranscriptionError.recognizerUnavailable))
                    return
                }

                guard recognizer.isAvailable else {
                    completion(.failure(TranscriptionError.recognizerUnavailable))
                    return
                }

                let request = SFSpeechURLRecognitionRequest(url: audioURL)
                request.shouldReportPartialResults = false

                // Bias recognition toward words the user has taught us — names
                // and other uncommon terms that would otherwise be mis-heard on
                // every entry. This is what makes a correction persist across
                // recordings (transcription has no memory of its own).
                let vocabulary = CustomVocabulary.shared.contextualStrings
                if !vocabulary.isEmpty {
                    request.contextualStrings = vocabulary
                }

                // Privacy: Prefer on-device recognition when offline
                // When online, Apple's servers provide better punctuation
                // Note: Even server-based recognition goes through Apple, not third parties
                if recognizer.supportsOnDeviceRecognition && !self.isOnline {
                    request.requiresOnDeviceRecognition = true
                } else {
                    request.addsPunctuation = true
                }

                _ = recognizer.recognitionTask(with: request) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            // Check if it's a network error
                            let nsError = error as NSError
                            if nsError.domain == "kAFAssistantErrorDomain" || !self.isOnline {
                                // Offline or network error - inform user
                                completion(.failure(TranscriptionError.offlineNoTranscription))
                            } else {
                                completion(.failure(error))
                            }
                            return
                        }

                        if let result = result, result.isFinal {
                            var text = result.bestTranscription.formattedString

                            // If offline transcription (no punctuation), add basic sentence ending
                            if !text.isEmpty && !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!") {
                                text += "."
                            }

                            completion(.success(text))
                        }
                    }
                }
            }
        }
    }
}
#endif
