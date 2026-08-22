//
//  EntityMatch.swift
//  solyn
//
//  Whether a name is actually IN a sentence. One definition, four call sites.
//

import Foundation

/// Does this entry mention that name?
///
/// This exists because the answer was computed **four times** — `filedEntities`
/// and `filedPlaces` in `EntryDetailView`, the underliner beside them, and
/// `Shareables.facts` — and all four asked plain `contains`, which is not the
/// question. `contains` says a diary entry reading
///
///     "These small moments of peace are what I treasure most."
///
/// mentions **Mom** (inside "**mom**ents") and **Small** (inside "**small**
/// moments"). Both were then underlined in gold in the transcript and filed in
/// the ledger underneath as things the Twin had recognised. It is the marquee
/// feature of the entry screen confidently pointing at two words that are not
/// names, and it was caught in an App Store screenshot.
///
/// A name has to sit on word boundaries. That is the whole rule; it just has to
/// be written once.
enum EntityMatch {

    /// Every range where `label` appears as a whole word (or whole phrase).
    ///
    /// Case-insensitive and diacritic-insensitive, so "jose" finds "José", but
    /// never mid-word: "mom" does not find "moments" and "ann" does not find
    /// "announcement".
    static func ranges(of label: String, in text: String) -> [Range<String.Index>] {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !text.isEmpty else { return [] }

        // Lookarounds rather than `\b`.
        //
        // `\b` asserts a transition between a word character and a non-word
        // one, so it fails at either end of a name that already ENDS in
        // punctuation: "A.J." followed by a space has a non-word character on
        // both sides of that boundary, and `\bA\.J\.\b` never matches. The
        // lookarounds ask the question that is actually meant — "is there a
        // word character glued to this?" — which is false for "A.J. " and true
        // for the "e" in "mom|ents".
        let pattern = "(?<![\\p{L}\\p{N}_])"
            + NSRegularExpression.escapedPattern(for: name)
            + "(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive]) else { return [] }

        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Range($0.range, in: text) }
    }

    /// Whether the name appears at all.
    static func mentions(_ label: String, in text: String) -> Bool {
        !ranges(of: label, in: text).isEmpty
    }

    /// Ranges where the name appears **written as a name** — capitalised.
    ///
    /// Word boundaries alone were not enough. The extractor had filed "Small"
    /// as a place from an entry reading "These small moments of peace", and the
    /// entry screen dutifully listed `PLACES: Small` under a gold-underlined
    /// "small". Boundaries make the match a whole word; they cannot tell a
    /// proper noun from an adjective.
    ///
    /// A name is capitalised where it is used. If every occurrence in this
    /// entry is lowercase, it is not a proper noun in this entry — whatever the
    /// graph believes about it elsewhere. Sentence-initial names are
    /// capitalised anyway, so nothing real is lost; a name the transcriber
    /// lowercased is, and that is the better error of the two to make.
    static func properNounRanges(of label: String, in text: String) -> [Range<String.Index>] {
        ranges(of: label, in: text).filter { range in
            guard let first = text[range].first else { return false }
            return first.isUppercase
        }
    }

    /// Whether the name is used as a name here.
    static func mentionsAsName(_ label: String, in text: String) -> Bool {
        !properNounRanges(of: label, in: text).isEmpty
    }

    /// The subset of `labels` this text mentions by name, order preserved.
    static func present(_ labels: [String], in text: String) -> [String] {
        labels.filter { mentionsAsName($0, in: text) }
    }
}
