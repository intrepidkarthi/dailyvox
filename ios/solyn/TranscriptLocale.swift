//
//  TranscriptLocale.swift
//  solyn
//
//  Which language an entry's words are in (plan B-1).
//

import Foundation
import CoreData
import NaturalLanguage

/// The language an entry is written in, stored on the entry as
/// `transcriptLocale` (a BCP-47 tag).
///
/// Until 1.14 nothing recorded it, so every reader had to guess from the text
/// each time, and a reader that only knows English had no way to tell it was
/// looking at Spanish. Now:
///
/// - A spoken entry carries the locale of the recogniser that ACTUALLY
///   transcribed it ("hi-IN", "en-US"). Not the app's language and not the
///   phone's: the model that heard the words.
/// - A typed entry, an entry added by Siri and every entry from before 1.14
///   carry a language read from the text with `NLLanguageRecognizer`, which is
///   a bare language code ("es"), or `und` when the text is too short or
///   too mixed for the recogniser to be sure.
/// - A day whose recordings were in two different languages is `mul`.
///
/// `und` and `mul` are the standard BCP-47 codes for "undetermined" and
/// "multiple languages", so nothing downstream needs a private vocabulary.
///
/// The readers use it through `FeatureLanguage` (B-4): the stored language
/// decides what the engine's `LanguageGate` lets each feature read, and which
/// language an entry is searched in (B-10). Detection from the text is only
/// the fallback, for `und` and entries not yet backfilled.
enum TranscriptLocale {

    static let undetermined = "und"
    static let multiple = "mul"

    /// How sure the recogniser must be before a typed entry gets a language.
    static let confidence = 0.6

    /// The tag to store after a segment in `segment` is appended to an entry
    /// that held `existing`.
    ///
    /// - The first words of an entry set it.
    /// - More words in the same language keep it (the latest, more specific
    ///   tag wins: "en" then "en-US" is "en-US").
    /// - An undetermined segment never overrules a known one, and a known one
    ///   replaces an undetermined one.
    /// - Two different languages make the day `mul`.
    static func merged(existing: String?, entryHadText: Bool, segment: String?) -> String? {
        guard let segment, !segment.isEmpty else { return entryHadText ? existing : nil }
        guard entryHadText, let existing, !existing.isEmpty else { return segment }
        if existing == multiple { return multiple }
        if segment == undetermined { return existing }
        if existing == undetermined { return segment }
        if language(of: existing) == language(of: segment) {
            return segment.count >= existing.count ? segment : existing
        }
        return multiple
    }

    /// The language part of a tag: "hi" from "hi-IN" or "hi_IN".
    static func language(of tag: String) -> String {
        Locale(identifier: tag).language.languageCode?.identifier ?? tag
    }

    /// The tag a recogniser locale is stored as: BCP-47, so "en-US", not "en_US".
    static func tag(for recognizerLocale: Locale) -> String {
        recognizerLocale.identifier(.bcp47)
    }

    /// A language read from text alone, for entries no recogniser heard.
    ///
    /// Deliberately agrees with `EntryLanguage`: where that says "not English"
    /// this returns the recogniser's language; where it keeps the English
    /// path, this says "en" only when the recogniser is actually sure, and
    /// `und` otherwise. A short note is recorded as undetermined rather than
    /// confidently English, because this is stored and outlives the guess.
    /// Returns nil for no text at all.
    static func detect(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let top = recognizer.languageHypotheses(withMaximum: 1).first

        if !EntryLanguage.isEnglish(trimmed) {
            guard let top, top.key != .undetermined else { return undetermined }
            return top.key.rawValue
        }
        if let top, top.key == .english, top.value >= confidence { return "en" }
        return undetermined
    }

    // MARK: - Backfill

    /// Gives every entry that has words but no `transcriptLocale` one read
    /// from its text. Runs at launch, in the background, and only touches
    /// entries that are still nil, so each entry is backfilled exactly once:
    /// entries from before 1.14, and anything an older build on another
    /// device synced in without the field.
    ///
    /// Returns how many entries it filled.
    @discardableResult
    static func backfill(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "transcriptLocale == nil AND text != nil AND text != %@", "")
        request.fetchBatchSize = 100
        guard let entries = try? context.fetch(request), !entries.isEmpty else { return 0 }
        var filled = 0
        for entry in entries {
            guard let tag = detect(entry.text ?? "") else { continue }
            entry.transcriptLocale = tag
            filled += 1
        }
        guard filled > 0 else { return 0 }
        do {
            try context.save()
        } catch {
            context.rollback()
            return 0
        }
        return filled
    }

    /// The launch-time backfill, on a private queue so a long journal never
    /// delays the first frame. Only `transcriptLocale` is written, and the
    /// merge policy keeps any edit the user makes meanwhile.
    static func backfillInBackground(_ container: NSPersistentContainer) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            backfill(in: context)
        }
    }
}

extension DiaryEntry {

    /// Records the language of a segment just appended to this entry.
    ///
    /// - Parameters:
    ///   - segment: the words appended.
    ///   - recognizerLocale: the locale of the recogniser that transcribed
    ///     them, or nil for typed words (then they are read with
    ///     `NLLanguageRecognizer`).
    ///   - entryHadText: whether the entry held words before this segment.
    func noteLanguage(ofAppended segment: String, recognizerLocale: Locale?, entryHadText: Bool) {
        let tag = recognizerLocale.map(TranscriptLocale.tag(for:)) ?? TranscriptLocale.detect(segment)
        transcriptLocale = TranscriptLocale.merged(existing: transcriptLocale,
                                                   entryHadText: entryHadText,
                                                   segment: tag)
    }
}
