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
/// On-device only: where no on-device model exists it fails and says so, and
/// never sends audio to a server.
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
    
    /// What a transcription produced, and which recogniser heard it.
    struct Transcription: Equatable {
        let text: String
        /// The locale of the model that ACTUALLY transcribed the audio, which
        /// is what the entry records as `transcriptLocale` (B-1). It can
        /// differ from the language the person picked: an en-IN speaker may
        /// be heard by the en-US model.
        let locale: Locale
    }

    /// Transcribes audio from the given URL to text.
    /// - Parameters:
    ///   - audioURL: URL to the audio file to transcribe
    ///   - completion: Called with the transcription result or error
    func transcribe(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        transcribeDetailed(from: audioURL) { completion($0.map(\.text)) }
    }

    /// Transcribes audio and says which recogniser did it.
    ///
    /// On iOS 26+ this uses Apple's new on-device `SpeechAnalyzer`/`SpeechTranscriber`
    /// — markedly lower word-error rate on sustained speech, no session length
    /// limit, fully on-device — or, for a language that model does not cover
    /// (Hindi), the on-device `DictationTranscriber`. It falls back to the
    /// proven `SFSpeechRecognizer` path on any failure (or on earlier iOS).
    /// Every path keeps audio on the device.
    func transcribeDetailed(from audioURL: URL, completion: @escaping (Result<Transcription, Error>) -> Void) {
        if #available(iOS 26.0, *) {
            Task {
                do {
                    let result = try await self.transcribeWithSpeechAnalyzer(from: audioURL)
                    await MainActor.run { completion(.success(result)) }
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

    /// Which iOS 26 module transcribes the speaker's language.
    enum AnalyzerRoute: Equatable {
        /// `SpeechTranscriber` in this locale.
        case transcriber(Locale)
        /// `DictationTranscriber` in this locale (B-7): for languages the
        /// SpeechTranscriber model does not cover, such as Hindi, instead of
        /// dropping to the legacy recogniser.
        case dictation(Locale)
    }

    /// Chooses the iOS 26 module for `speaker`. The lookups are injected so the
    /// order can be tested without the frameworks.
    ///
    /// 1. SpeechTranscriber in the speaker's language.
    /// 2. English speakers only: SpeechTranscriber en-US. This is the 1.13.1
    ///    order, untouched, so English goes exactly where it went before.
    /// 3. Anyone else: DictationTranscriber in their language.
    /// 4. Nothing: nil, and the legacy recogniser gets its turn, in the same
    ///    language. Never another language.
    static func analyzerRoute(for speaker: Locale,
                              transcriberLocale: (Locale) async -> Locale?,
                              dictationLocale: (Locale) async -> Locale?) async -> AnalyzerRoute? {
        if let locale = await transcriberLocale(speaker) { return .transcriber(locale) }
        if allowsEnglishFallback(for: speaker) {
            if let locale = await transcriberLocale(Locale(identifier: "en-US")) { return .transcriber(locale) }
            return nil
        }
        if let locale = await dictationLocale(speaker) { return .dictation(locale) }
        return nil
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(from audioURL: URL) async throws -> Transcription {
        // Resolve a supported locale for the transcriber. Fully qualified —
        // this app's own class is also named SpeechTranscriber.
        //
        // SAME LANGUAGE ONLY. This used to fall back to en-US whenever the
        // device language had no SpeechTranscriber model, which turned a
        // Hindi or Tamil entry into confident English gibberish. Now the
        // en-US fallback is only for people whose language IS English
        // (en-IN, en-AU... with only the base model). Anyone else is routed
        // to the dictation model in their own language, then to the SFSpeech
        // path in their language, and if that has no on-device model either
        // they see the honest "no on-device model" message instead of a
        // wrong transcript.
        let route = await Self.analyzerRoute(
            for: Self.speakerLocale,
            transcriberLocale: { await Speech.SpeechTranscriber.supportedLocale(equivalentTo: $0) },
            dictationLocale: { await DictationTranscriber.supportedLocale(equivalentTo: $0) })

        switch route {
        case .transcriber(let locale):
            return Transcription(text: try await runTranscriber(locale: locale, audioURL: audioURL),
                                 locale: locale)
        case .dictation(let locale):
            return Transcription(text: try await runDictation(locale: locale, audioURL: audioURL),
                                 locale: locale)
        case nil:
            throw TranscriptionError.onDeviceUnavailable
        }
    }

    /// Makes sure a module's on-device model is installed (one download, from
    /// Apple, the first time), or throws.
    @available(iOS 26.0, *)
    private func ensureInstalled(_ module: any SpeechModule) async throws {
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            break
        case .supported, .downloading:
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
        case .unsupported:
            throw TranscriptionError.recognizerUnavailable
        @unknown default:
            throw TranscriptionError.recognizerUnavailable
        }
    }

    @available(iOS 26.0, *)
    private func runTranscriber(locale: Locale, audioURL: URL) async throws -> String {
        let transcriber = Speech.SpeechTranscriber(locale: locale, preset: .transcription)
        try await ensureInstalled(transcriber)

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

        return try Self.finish(String(transcript.characters))
    }

    /// B-7: the dictation model, for languages SpeechTranscriber lacks.
    @available(iOS 26.0, *)
    private func runDictation(locale: Locale, audioURL: URL) async throws -> String {
        let transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
        try await ensureInstalled(transcriber)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        var segments: [String] = []
        let collector = Task {
            for try await result in transcriber.results where result.isFinal {
                segments.append(String(result.text.characters))
            }
        }

        _ = try await analyzer.analyzeSequence(from: audioFile)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await collector.value

        return try Self.finish(Self.joinSegments(segments))
    }

    /// Joins final dictation segments, adding a space only where neither side
    /// already has one, so a segment boundary never glues two words together.
    static func joinSegments(_ segments: [String]) -> String {
        var out = ""
        for segment in segments where !segment.isEmpty {
            if let last = out.last, let first = segment.first,
               !last.isWhitespace, !first.isWhitespace {
                out.append(" ")
            }
            out.append(segment)
        }
        return out
    }

    /// Trims, refuses an empty transcript, and closes the last sentence.
    /// A danda (U+0964) ends a Hindi sentence, so it counts as an ending too;
    /// for every other text this is the rule the app always had.
    static func finish(_ raw: String) throws -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.noFinalResult }
        if !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!") && !text.hasSuffix("\u{0964}") {
            text += "."
        }
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
    /// So: try the current locale, then plain-language variants, then — only
    /// when the device language is English — en-US. Every candidate must
    /// support on-device recognition to be returned, which keeps the promise
    /// intact — this widens where it can be KEPT, it does not weaken it.
    ///
    /// Never another language. A Spanish or Hindi speaker whose own model is
    /// missing must not be handed an English recogniser: it does not fail,
    /// it produces a fluent, wrong English transcript of their words.
    static func onDeviceRecognizer() -> SFSpeechRecognizer? {
        for locale in candidateLocales(for: speakerLocale) {
            guard let candidate = SFSpeechRecognizer(locale: locale),
                  candidate.supportsOnDeviceRecognition,
                  candidate.isAvailable else { continue }
            return candidate
        }
        return nil
    }

    /// The language the person actually SPEAKS, for choosing a recogniser.
    ///
    /// Not `Locale.current`. That is the app's resolved localisation, and
    /// the app is only localised in en/de/es/fr/it — so on an iPhone set to
    /// Hindi, Tamil, Japanese or Portuguese, `Locale.current` comes back as
    /// English (en_IN for a Hindi phone in India). Choosing from it handed
    /// those speakers an English recogniser, which is exactly what A0-1 is
    /// meant to stop. `Locale.preferredLanguages.first` is the person's real
    /// first language, regardless of what the app is translated into.
    ///
    /// When that preference is the same language as `Locale.current` (every
    /// English user, and de/es/fr/it), `Locale.current` is kept as-is, so
    /// those users see exactly the recogniser order they had before.
    ///
    /// From 1.14 the "Language you speak" picker comes first: when someone has
    /// chosen a language, that is the language. Automatic (the default) is
    /// the rule above, so nothing changes for anyone who has not picked.
    static var speakerLocale: Locale {
        SpeakingLanguage.resolve(chosen: SpeakingLanguage.chosenIdentifier,
                                 automatic: automaticSpeakerLocale)
    }

    /// The 1.13.1 rule, with no picker involved: what Automatic means.
    static var automaticSpeakerLocale: Locale {
        speakerLocale(preferredLanguages: Locale.preferredLanguages, current: .current)
    }

    /// Pure form of `speakerLocale`, for tests.
    static func speakerLocale(preferredLanguages: [String], current: Locale) -> Locale {
        guard let first = preferredLanguages.first, !first.isEmpty else { return current }
        let preferred = Locale(identifier: first)
        let preferredLang = preferred.language.languageCode?.identifier
        if preferredLang == nil || preferredLang == current.language.languageCode?.identifier {
            return current
        }
        return preferred
    }

    /// The locales `onDeviceRecognizer()` tries, in order. Pure, for tests.
    /// Every candidate is in the speaker's own language; en-US is added only
    /// when that language is English.
    static func candidateLocales(for current: Locale) -> [Locale] {
        var seen = Set<String>()
        var candidates: [Locale] = []

        func add(_ locale: Locale?) {
            guard let locale, seen.insert(locale.identifier).inserted else { return }
            candidates.append(locale)
        }

        add(current)
        // "en" from "en_IN" — the base model, which most devices do have.
        if let lang = current.language.languageCode?.identifier {
            add(Locale(identifier: lang))
            add(Locale(identifier: "\(lang)-US"))
        }
        if allowsEnglishFallback(for: current) {
            add(Locale(identifier: "en-US"))
        }
        return candidates
    }

    /// Whether an English model may stand in when the speaker's exact
    /// locale has none: only when the speaker's language is English.
    static func allowsEnglishFallback(for locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "en"
    }

    /// The error to show when no on-device recogniser exists for the
    /// speaker. English keeps its old wording; any other language gets the
    /// honest "no on-device model" message, which says what to install.
    static func noRecognizerError(for locale: Locale) -> TranscriptionError {
        allowsEnglishFallback(for: locale) ? .recognizerUnavailable : .onDeviceUnavailable
    }

    // MARK: - SFSpeechRecognizer path (iOS < 26, and the fallback)

    private func transcribeWithSFSpeech(from audioURL: URL, completion: @escaping (Result<Transcription, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(.failure(TranscriptionError.notAuthorized))
                    return
                }

                guard let recognizer = Self.onDeviceRecognizer() else {
                    completion(.failure(Self.noRecognizerError(for: Self.speakerLocale)))
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
                            if !text.isEmpty && !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!")
                                && !text.hasSuffix("\u{0964}") {
                                text += "."
                            }

                            completion(.success(Transcription(text: text, locale: recognizer.locale)))
                        }
                    }
                }
            }
        }
    }
}
#endif
