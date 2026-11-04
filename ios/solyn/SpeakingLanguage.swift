//
//  SpeakingLanguage.swift
//  solyn
//
//  "Language you speak" — chosen separately from the app's language (plan B-6).
//

#if os(iOS)
import Foundation
import Speech

/// The language DailyVox listens in.
///
/// Separate from the interface language on purpose. The app is translated into
/// a handful of languages; people speak many more, and plenty of people run
/// their phone in English and talk to their diary in Hindi or Spanish. Until
/// 1.14 the only input was the phone's first preferred language (1.13.1's
/// `speakerLocale`), so the only way to journal in another language was to
/// change the whole phone.
///
/// The rule the picker keeps: DailyVox listens in ONE language at a time and
/// offers only languages this iPhone can transcribe on-device, now or after a
/// one-time download from Apple. A language it cannot hear is not offered,
/// rather than offered and then transcribed by an English model.
///
/// Default is Automatic, which is exactly the 1.13.1 behaviour: nobody's
/// recogniser changes until they pick something.
enum SpeakingLanguage {

    static let defaultsKey = "speakingLanguage"

    /// The chosen tag, or nil for Automatic.
    static var chosenIdentifier: String? {
        get {
            let value = UserDefaults.standard.string(forKey: defaultsKey)
            return (value?.isEmpty ?? true) ? nil : value
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    /// The locale to listen in: the chosen one, else Automatic. Pure, for tests.
    static func resolve(chosen: String?, automatic: Locale) -> Locale {
        guard let chosen, !chosen.isEmpty else { return automatic }
        return Locale(identifier: chosen)
    }

    // MARK: - What this iPhone can hear

    /// Which recogniser would hear a language.
    enum Engine: Int, Comparable {
        /// iOS 26 `SpeechTranscriber`: the best model, no length limit.
        case speechAnalyzer = 0
        /// iOS 26 `DictationTranscriber`: the dictation model, which covers
        /// languages `SpeechTranscriber` does not (Hindi among them).
        case dictation = 1
        /// `SFSpeechRecognizer` with on-device support, iOS 17 onward.
        case legacyOnDevice = 2

        static func < (a: Engine, b: Engine) -> Bool { a.rawValue < b.rawValue }
    }

    /// One language the picker can offer.
    struct Option: Identifiable, Hashable {
        /// BCP-47, "hi-IN".
        let identifier: String
        let engine: Engine
        /// True when the model is already on this iPhone. False means a
        /// one-time download from Apple first.
        let installed: Bool

        var id: String { identifier }
        var locale: Locale { Locale(identifier: identifier) }

        /// "Hindi (India)" in the reader's language.
        func displayName(in display: Locale = .current) -> String {
            display.localizedString(forIdentifier: identifier) ?? identifier
        }
    }

    /// Merges what each recogniser reports into one list, one row per
    /// language tag. Where two recognisers can hear the same tag, the better
    /// one is kept (SpeechAnalyzer, then Dictation, then the legacy
    /// recogniser), and the language counts as installed if any of them has
    /// it. Sorted by name in `display`. Pure, for tests.
    static func merge(analyzer: [(Locale, installed: Bool)],
                      dictation: [(Locale, installed: Bool)],
                      legacyOnDevice: [Locale],
                      display: Locale) -> [Option] {
        var best: [String: Option] = [:]
        func add(_ locale: Locale, _ engine: Engine, _ installed: Bool) {
            let tag = locale.identifier(.bcp47)
            guard !tag.isEmpty, tag != "und" else { return }
            if let current = best[tag] {
                let engine = min(current.engine, engine)
                best[tag] = Option(identifier: tag, engine: engine,
                                   installed: current.installed || installed)
            } else {
                best[tag] = Option(identifier: tag, engine: engine, installed: installed)
            }
        }
        for (locale, installed) in analyzer { add(locale, .speechAnalyzer, installed) }
        for (locale, installed) in dictation { add(locale, .dictation, installed) }
        // A legacy recogniser that reports on-device support has its model.
        for locale in legacyOnDevice { add(locale, .legacyOnDevice, true) }

        return best.values.sorted {
            let a = $0.displayName(in: display), b = $1.displayName(in: display)
            if a.localizedStandardCompare(b) == .orderedSame { return $0.identifier < $1.identifier }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
    }

    /// The option the picker should show as selected for `locale`, matching
    /// "en_US" to "en-US" and falling back to the same language.
    static func option(for locale: Locale, in options: [Option]) -> Option? {
        let tag = locale.identifier(.bcp47)
        if let exact = options.first(where: { $0.identifier == tag }) { return exact }
        let lang = locale.language.languageCode?.identifier
        return options.first(where: { $0.locale.language.languageCode?.identifier == lang })
    }

    /// Everything this iPhone can transcribe on-device, now or after a
    /// one-time download. Asks the frameworks; nothing here is a hard-coded
    /// list, so a language appears exactly when Apple ships a model for it.
    static func availableOptions(display: Locale = .current) async -> [Option] {
        var analyzer: [(Locale, installed: Bool)] = []
        var dictation: [(Locale, installed: Bool)] = []

        if #available(iOS 26.0, *) {
            let supported = await Speech.SpeechTranscriber.supportedLocales
            let installed = Set(await Speech.SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
            analyzer = supported.map { ($0, installed.contains($0.identifier(.bcp47))) }

            let dSupported = await DictationTranscriber.supportedLocales
            let dInstalled = Set(await DictationTranscriber.installedLocales.map { $0.identifier(.bcp47) })
            dictation = dSupported.map { ($0, dInstalled.contains($0.identifier(.bcp47))) }
        }

        let legacy = SFSpeechRecognizer.supportedLocales().filter {
            SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true
        }
        return merge(analyzer: analyzer, dictation: dictation,
                     legacyOnDevice: Array(legacy), display: display)
    }

    // MARK: - Installing a model

    enum InstallError: LocalizedError {
        case unsupported
        var errorDescription: String? {
            String(localized: "This iPhone can't download that language's speech model.",
                   comment: "Language you speak: Apple refused to install the model for the chosen language.")
        }
    }

    /// Downloads the on-device model for `option` through `AssetInventory`.
    /// A no-op for a model that is already installed or for the legacy
    /// recogniser (which manages its own assets through Dictation settings).
    /// `progress` is called on the main actor with 0…1.
    static func install(_ option: Option, progress: @escaping @MainActor (Double) -> Void) async throws {
        guard #available(iOS 26.0, *), !option.installed else { return }
        let module: any SpeechModule
        switch option.engine {
        case .speechAnalyzer:
            module = Speech.SpeechTranscriber(locale: option.locale, preset: .transcription)
        case .dictation:
            module = DictationTranscriber(locale: option.locale, preset: .longDictation)
        case .legacyOnDevice:
            return
        }
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            return
        case .unsupported:
            throw InstallError.unsupported
        case .supported, .downloading:
            break
        @unknown default:
            throw InstallError.unsupported
        }
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
        let observation = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { p, _ in
            let fraction = p.fractionCompleted
            Task { @MainActor in progress(fraction) }
        }
        defer { observation.invalidate() }
        try await request.downloadAndInstall()
    }
}
#endif
