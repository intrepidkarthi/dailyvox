//
//  SpeechLocaleProbe.swift
//  DailyVox
//
//  What this phone can transcribe on-device, per language (plan B-17).
//
//  Hindi and every other new language ship only if a REAL iPhone says it can
//  transcribe them without the network. The framework probe on macOS is
//  suggestive, not proof, so this asks the same questions on the device:
//  SpeechTranscriber.supportedLocales / installedLocales on iOS 26, and
//  SFSpeechRecognizer.supportsOnDeviceRecognition per candidate locale on
//  every iOS. The report is plain text so it can be pasted into the plan.
//
//  DEBUG-only. Nothing here ships.
//

#if DEBUG && os(iOS)

import Foundation
import Speech

struct SpeechLocaleProbeReport: Equatable {

    struct LegacyRow: Equatable {
        let identifier: String
        /// SFSpeechRecognizer(locale:) returned a recogniser at all.
        let exists: Bool
        let supportsOnDevice: Bool
        let isAvailable: Bool
    }

    struct AnalyzerRow: Equatable {
        let identifier: String
        /// What SpeechTranscriber.supportedLocale(equivalentTo:) resolved to,
        /// or nil when it has no model for this language.
        let resolved: String?
        let installed: Bool
    }

    var date = Date()
    var systemVersion = ""
    var currentLocale = ""
    var speakerLocale = ""
    var appCandidates: [String] = []
    var appResolved: String?
    var legacySupportedCount = 0
    var legacy: [LegacyRow] = []
    /// nil below iOS 26.
    var analyzerSupported: [String]?
    var analyzerInstalled: [String]?
    var analyzer: [AnalyzerRow] = []
    var dictationSupported: [String]?
    var dictationInstalled: [String]?

    /// The locales the multilingual plan cares about, plus English controls.
    static let candidates = [
        "en-US", "en-IN", "en-GB",
        "hi-IN", "pt-BR", "es-ES", "es-MX", "es-US",
        "fr-FR", "de-DE", "it-IT",
        "ta-IN", "ja-JP",
    ]

    var text: String {
        var lines: [String] = []
        lines.append("DailyVox speech locale probe")
        lines.append("date: \(ISO8601DateFormatter().string(from: date))")
        lines.append("iOS: \(systemVersion)")
        lines.append("current locale: \(currentLocale)")
        lines.append("speaker locale: \(speakerLocale)")
        lines.append("app tries (SFSpeech): \(appCandidates.joined(separator: ", "))")
        lines.append("app resolves to: \(appResolved ?? "none (shows the no-on-device-model message)")")
        lines.append("")
        lines.append("SFSpeechRecognizer.supportedLocales: \(legacySupportedCount)")
        lines.append("locale | exists | onDevice | available")
        for r in legacy {
            lines.append("\(r.identifier) | \(yn(r.exists)) | \(yn(r.supportsOnDevice)) | \(yn(r.isAvailable))")
        }
        lines.append("")
        if let analyzerSupported {
            lines.append("SpeechTranscriber.supportedLocales (\(analyzerSupported.count)): \(analyzerSupported.joined(separator: ", "))")
            lines.append("SpeechTranscriber.installedLocales (\(analyzerInstalled?.count ?? 0)): \((analyzerInstalled ?? []).joined(separator: ", "))")
            lines.append("locale | resolves to | installed")
            for r in analyzer {
                lines.append("\(r.identifier) | \(r.resolved ?? "-") | \(yn(r.installed))")
            }
            lines.append("")
            lines.append("DictationTranscriber.supportedLocales (\(dictationSupported?.count ?? 0)): \((dictationSupported ?? []).joined(separator: ", "))")
            lines.append("DictationTranscriber.installedLocales (\(dictationInstalled?.count ?? 0)): \((dictationInstalled ?? []).joined(separator: ", "))")
        } else {
            lines.append("SpeechTranscriber: not available (below iOS 26)")
        }
        return lines.joined(separator: "\n")
    }

    private func yn(_ b: Bool) -> String { b ? "yes" : "no" }
}

enum SpeechLocaleProbe {

    static func run() async -> SpeechLocaleProbeReport {
        var report = SpeechLocaleProbeReport()
        report.systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        report.currentLocale = Locale.current.identifier
        report.speakerLocale = SpeechTranscriber.speakerLocale.identifier
        report.appCandidates = SpeechTranscriber.candidateLocales(for: SpeechTranscriber.speakerLocale).map(\.identifier)
        report.appResolved = SpeechTranscriber.onDeviceRecognizer()?.locale.identifier
        report.legacySupportedCount = SFSpeechRecognizer.supportedLocales().count
        report.legacy = SpeechLocaleProbeReport.candidates.map { id in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
            return .init(identifier: id,
                         exists: recognizer != nil,
                         supportsOnDevice: recognizer?.supportsOnDeviceRecognition ?? false,
                         isAvailable: recognizer?.isAvailable ?? false)
        }

        if #available(iOS 26.0, *) {
            let supported = await Speech.SpeechTranscriber.supportedLocales
            let installed = await Speech.SpeechTranscriber.installedLocales
            report.analyzerSupported = supported.map(\.identifier).sorted()
            report.analyzerInstalled = installed.map(\.identifier).sorted()
            let installedIDs = Set(installed.map { $0.identifier(.bcp47) })
            var rows: [SpeechLocaleProbeReport.AnalyzerRow] = []
            for id in SpeechLocaleProbeReport.candidates {
                let resolved = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: id))
                rows.append(.init(identifier: id,
                                  resolved: resolved?.identifier,
                                  installed: resolved.map { installedIDs.contains($0.identifier(.bcp47)) } ?? false))
            }
            report.analyzer = rows
            report.dictationSupported = await DictationTranscriber.supportedLocales.map(\.identifier).sorted()
            report.dictationInstalled = await DictationTranscriber.installedLocales.map(\.identifier).sorted()
        }
        return report
    }
}

#endif
