//
//  FeatureLanguage.swift
//  solyn
//
//  Which of the app's readers may read which entry (plan B-4).
//

import Foundation
import DailyVoxTwinEngine

/// The app's door to the engine's `LanguageGate`.
///
/// 1.13.1 kept the English-only readers quiet with an app-side yes/no,
/// `EntryLanguage.isEnglish`, re-guessed from the text every time. From 1.14
/// the engine owns one capability table for every language and feature, and
/// every entry carries the language it was actually spoken in
/// (`transcriptLocale`, B-1). This is where the two meet: each reader asks
/// "can I read this entry?" here, and the answer comes from the table.
///
/// THE RULE is the engine's: a feature that cannot read a language is QUIET
/// for it. It never shows a neutral reading as if it were a finding.
///
/// Where the language comes from, in order:
/// 1. The entry's stored `transcriptLocale`, when it names a language: the
///    recogniser that heard the words, or the language read once from typed
///    text. `mul` (a day spoken in two languages) is a language the table does
///    not list, so the readers stay quiet on it, as plan D5 asks.
/// 2. Otherwise (`und`, nil: a short note, an entry not yet backfilled) the
///    text is detected with `LanguageGate.readingLanguage`, which reads
///    undetermined Latin-script text as English, exactly as 1.13.1 did.
///
/// English never changes: every English entry reads as "en", and "en" has
/// every feature.
enum FeatureLanguage {

    /// The language `text` is read in. `stored` is the entry's
    /// `transcriptLocale` (or a recogniser's tag), nil when unknown.
    static func reading(_ text: String, stored: String?) -> String {
        LanguageGate.readingLanguage(of: text, declared: stored)
    }

    /// Whether every one of `features` can read this entry.
    static func reads(_ features: LanguageFeature..., text: String, stored: String?) -> Bool {
        let language = reading(text, stored: stored)
        return features.allSatisfy { LanguageGate.supports($0, languageCode: language) }
    }

    // MARK: - The app's readers, each named once

    /// The suggested mood: the engine's English feeling words and lexicons.
    static func readsMood(_ text: String, stored: String?) -> Bool {
        reads(.mood, text: text, stored: stored)
    }

    /// The reflection shown after saving: the engine's English reflection lines.
    static func readsReflection(_ text: String, stored: String?) -> Bool {
        reads(.reflection, text: text, stored: stored)
    }

    /// The grounded daily question. It asks after a NAME, and only from an
    /// entry the English sensitive-word list (`DailyQuestion.sensitiveWords`)
    /// has shown to be gentle. That list is a lexicon read like the mood's, so
    /// the entry needs both: a Spanish entry about a funeral has readable names
    /// and an unreadable grief.
    static func readsGroundedQuestion(_ text: String, stored: String?) -> Bool {
        reads(.mood, .names, text: text, stored: stored)
    }

    /// The share cards' "your week, decoded": style, focus, vocabulary and
    /// sentiment-by-person, all English keyword and lexicon reads of the person.
    static func readsShareableInsights(_ text: String, stored: String?) -> Bool {
        reads(.traits, .mood, text: text, stored: stored)
    }

    // MARK: - Search

    /// The language to index an entry in. A `mul` day is detected from its
    /// text rather than left out: search is the one reader that must never go
    /// quiet on someone's words, only simpler.
    static func indexLanguage(stored: String?) -> String? {
        guard let stored, LanguageGate.baseCode(stored) != TranscriptLocale.multiple else { return nil }
        return stored
    }

    /// The language a search or an Ask question is in.
    ///
    /// The question's own words when the recogniser is sure of them; else, for
    /// Latin-script text, the language the person speaks (a two-word Spanish
    /// query is Spanish to a Spanish speaker); and for unplaced non-Latin text
    /// nil, so the engine reads it as unknown. For an English speaker this is
    /// exactly the engine's own default.
    static func queryLanguage(_ query: String, speaking: Locale) -> String? {
        if let detected = LanguageGate.detectLanguage(of: query) { return detected }
        if LanguageGate.isMostlyNonLatin(query) { return nil }
        return LanguageGate.baseCode(speaking.language.languageCode?.identifier) ?? "en"
    }
}

// MARK: - Ask your Twin

/// Whether Ask your Twin can answer a question in its language (plan B-11, D7).
///
/// The engine lists Ask Twin for en, es, fr, de, it and pt. Anything else gets
/// a calm line saying so, never an answer composed from words the Twin could
/// not read.
enum AskLanguage {

    /// The language the question is read in; "und" when it cannot be placed.
    static func language(of question: String, speaking: Locale) -> String {
        FeatureLanguage.queryLanguage(question, speaking: speaking)
            ?? LanguageGate.readingLanguage(of: question)
    }

    static func canAnswer(_ question: String, speaking: Locale) -> Bool {
        LanguageGate.supports(.askTwin, languageCode: language(of: question, speaking: speaking))
    }

    /// Whether the person's speaking language is one Ask understands at all,
    /// for the note on the empty screen.
    static func understands(speaking: Locale) -> Bool {
        LanguageGate.supports(.askTwin, locale: speaking)
    }

    static var unsupportedMessage: String {
        String(localized: "Ask your Twin understands English, Spanish, French, German, Italian and Portuguese for now.",
               comment: "Shown in Ask your Twin instead of an answer when the question, or the language the person speaks, is one the Twin cannot read yet. Language names are the languages Ask supports.")
    }
}
