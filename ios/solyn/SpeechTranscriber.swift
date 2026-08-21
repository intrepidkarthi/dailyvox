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
import AVFoundation

/// Transcribes audio recordings to text using Apple's Speech framework.
/// Prioritizes on-device recognition for privacy; falls back to Apple's servers when needed.
final class SpeechTranscriber {
    
    // MARK: - Shared Instance
    
    static let shared = SpeechTranscriber()

    // MARK: - Private Properties
    
    
    // MARK: - Error Types

    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case noFinalResult
        case onDeviceUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition is not authorized."
            case .recognizerUnavailable:
                return "Speech recognizer is not available."
            case .noFinalResult:
                return "No final transcription result."
            case .onDeviceUnavailable:
                return "No on-device speech model is installed yet, so this one is saved as audio. Turn on Settings > General > Keyboard > Dictation and iOS will fetch the model once; every entry after that transcribes here. Tap Edit to write this one yourself. DailyVox will not transcribe over a network."
            }
        }
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

    /// A recogniser that can work WITHOUT the network, trying more than one
    /// locale before giving up.
    ///
    /// The rule is unchanged — nothing is ever sent to a server — but the first
    /// version of it asked only `SFSpeechRecognizer()`, i.e. the device's exact
    /// current locale. Plenty of people run a regional English (en-IN, en-GB,
    /// en-AU) with only the base en-US speech model installed, and for them
    /// transcription simply stopped working: the recording saved, the entry
    /// stayed blank, and the alert told them to go and install something.
    ///
    /// So: try the current locale, then plain-language variants, then en-US.
    /// Every candidate must support on-device recognition to be returned, which
    /// keeps the promise intact — this widens where it can be KEPT, it does not
    /// weaken it.
    static func onDeviceRecognizer() -> SFSpeechRecognizer? {
        var seen = Set<String>()
        var candidates: [Locale] = []

        func add(_ locale: Locale?) {
            guard let locale, seen.insert(locale.identifier).inserted else { return }
            candidates.append(locale)
        }

        add(Locale.current)
        // "en" from "en_IN" — the base model, which most devices do have.
        if let lang = Locale.current.language.languageCode?.identifier {
            add(Locale(identifier: lang))
            add(Locale(identifier: "\(lang)-US"))
        }
        add(Locale(identifier: "en-US"))

        for locale in candidates {
            guard let candidate = SFSpeechRecognizer(locale: locale),
                  candidate.supportsOnDeviceRecognition,
                  candidate.isAvailable else { continue }
            return candidate
        }
        return nil
    }

    // MARK: - SFSpeechRecognizer path (iOS < 26, and the fallback)

    private func transcribeWithSFSpeech(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(.failure(TranscriptionError.notAuthorized))
                    return
                }

                guard let recognizer = Self.onDeviceRecognizer() else {
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

                // ON-DEVICE, ALWAYS.
                //
                // This used to read "prefer on-device recognition when offline",
                // which meant that on a normal connected iPhone the recording
                // was UPLOADED to Apple's speech servers for better punctuation.
                // Every claim the product makes rested on that not happening:
                // "nothing you say leaves this phone", the 0-calls ledger, the
                // 0 BYTES OUT on the Dynamic Island, the shareable receipt.
                //
                // Punctuation is not worth the only promise this app has. Where
                // on-device recognition is unavailable it FAILS and says why,
                // exactly as the Android build does, instead of quietly
                // reaching for the network.
                request.requiresOnDeviceRecognition = true
                // Supported alongside on-device recognition since iOS 16, and
                // ignored where it is not.
                request.addsPunctuation = true

                _ = recognizer.recognitionTask(with: request) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            // The speech framework's own domain, which now means
                            // the on-device model could not do the job. It never
                            // means "you are offline": offline is the expected
                            // way to run this app, not a failure mode.
                            let nsError = error as NSError
                            if nsError.domain == "kAFAssistantErrorDomain" {
                                completion(.failure(TranscriptionError.onDeviceUnavailable))
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
