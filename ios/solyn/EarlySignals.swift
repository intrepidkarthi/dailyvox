//
//  EarlySignals.swift
//  solyn
//
//  What can honestly be said about a journal in its first week.
//

import Foundation

/// Patterns need eight entries and the Twin's summary needs five. With one
/// entry a day, a new user cannot see either inside their first week — the
/// week they decide whether to keep going — and both screens said "not enough
/// yet" until then.
///
/// These are what can be said from three entries without guessing: counts
/// read straight off the entries. When you speak, how long, which words came
/// back, and the moods the user picked. No personality, no "because", and
/// nothing from the engine's learned profile (that can run ahead of the
/// journal). Every signal carries the numbers it rests on.
///
/// Once `TwinPatterns.minimumEntries` is reached this gives way to the real
/// patterns. Nothing here can contradict them: they say different kinds of
/// thing — this says how much and how often, they say what goes with what.
enum EarlySignals {

    /// The first entry count at which early signals appear.
    static let minimumEntries = 3
    /// Where they stop: the real patterns' own threshold.
    static var firmEntries: Int { TwinPatterns.minimumEntries }

    /// True while the journal is past the first few entries but short of the
    /// real patterns.
    static func isEarly(entryCount: Int) -> Bool {
        entryCount >= minimumEntries && entryCount < firmEntries
    }

    /// One entry, reduced to what the signals read. Kept apart from
    /// `DiaryEntry` so the rules are tested without Core Data.
    struct Entry {
        let date: Date
        let text: String
        /// The mood the user picked, if they did. Never a suggestion.
        let chosenMood: String?
        /// The mood the app suggested from the words and the user left as it
        /// was. Shown only as a suggestion.
        let suggestedMood: String?
    }

    enum PartOfDay: CaseIterable, Equatable {
        case morning, afternoon, evening, night

        /// 5–12, 12–17, 17–22, 22–5, local time.
        static func of(hour: Int) -> PartOfDay {
            switch hour {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<22: return .evening
            default: return .night
            }
        }
    }

    struct TimeOfDay: Equatable {
        let part: PartOfDay
        let count: Int
        let total: Int
    }

    enum Trend: Equatable { case longer, shorter, steady }

    struct Length: Equatable {
        /// Mean words per entry, rounded, over entries with any words.
        let averageWords: Int
        /// Earliest half against latest half, when there are enough entries
        /// to have halves.
        let earlierWords: Int?
        let recentWords: Int?
        let trend: Trend?
    }

    struct Repeat: Equatable {
        /// As the user wrote it — the lowercase form if they ever used one,
        /// otherwise their most frequent spelling.
        let word: String
        /// How many different entries it appears in. Always at least two.
        let entries: Int
    }

    struct MoodCount: Equatable {
        let raw: String
        let count: Int
    }

    struct Report: Equatable {
        let entryCount: Int
        let timeOfDay: TimeOfDay?
        let length: Length?
        let repeats: [Repeat]
        let chosenMoods: [MoodCount]
        let suggestedMoods: [MoodCount]

        var isEmpty: Bool {
            timeOfDay == nil && length == nil && repeats.isEmpty
                && chosenMoods.isEmpty && suggestedMoods.isEmpty
        }
    }

    // MARK: - Rules

    /// How many repeated words to show.
    static let repeatLimit = 3
    /// A trend needs at least this many entries with words, and a change of
    /// both this fraction and this many words, before it is called a change.
    static let trendMinimumEntries = 3
    static let trendRatio = 1.25
    static let trendMinimumWords = 10

    static func report(_ entries: [Entry], calendar: Calendar = .current) -> Report {
        let sorted = entries.sorted { $0.date < $1.date }
        return Report(
            entryCount: sorted.count,
            timeOfDay: timeOfDay(sorted, calendar: calendar),
            length: length(sorted),
            repeats: repeats(sorted),
            chosenMoods: moodCounts(sorted.compactMap(\.chosenMood)),
            suggestedMoods: moodCounts(sorted.compactMap(\.suggestedMood))
        )
    }

    /// The part of the day with the most entries — only when it has at least
    /// two and strictly more than any other part. A tie is not a habit.
    static func timeOfDay(_ entries: [Entry], calendar: Calendar) -> TimeOfDay? {
        guard !entries.isEmpty else { return nil }
        var counts: [PartOfDay: Int] = [:]
        for e in entries {
            counts[PartOfDay.of(hour: calendar.component(.hour, from: e.date)), default: 0] += 1
        }
        let ranked = counts.sorted { $0.value > $1.value }
        guard let top = ranked.first, top.value >= 2 else { return nil }
        if ranked.count > 1, ranked[1].value == top.value { return nil }
        return TimeOfDay(part: top.key, count: top.value, total: entries.count)
    }

    /// Entries with no words (a recording that never transcribed) are left
    /// out: counting them as zero would report a length nobody spoke.
    static func length(_ chronological: [Entry]) -> Length? {
        let counts = chronological.map { wordCount($0.text) }.filter { $0 > 0 }
        guard counts.count >= 2 else { return nil }
        let average = mean(counts)

        guard counts.count >= trendMinimumEntries else {
            return Length(averageWords: average, earlierWords: nil, recentWords: nil, trend: nil)
        }
        let half = counts.count / 2
        let earlier = mean(Array(counts.prefix(half)))
        let recent = mean(Array(counts.suffix(half)))
        let trend: Trend
        if Double(recent) >= Double(earlier) * trendRatio, recent - earlier >= trendMinimumWords {
            trend = .longer
        } else if Double(earlier) >= Double(recent) * trendRatio, earlier - recent >= trendMinimumWords {
            trend = .shorter
        } else {
            trend = .steady
        }
        return Length(averageWords: average, earlierWords: earlier, recentWords: recent, trend: trend)
    }

    /// Whole words that appear in at least two different entries, most
    /// entries first. Matching ignores case; the word shown is the user's.
    static func repeats(_ entries: [Entry]) -> [Repeat] {
        var entriesWith: [String: Int] = [:]
        var uses: [String: Int] = [:]
        var forms: [String: [String: Int]] = [:]

        for entry in entries {
            var seen = Set<String>()
            for token in words(in: entry.text) {
                let key = token.lowercased()
                guard isCandidate(token, key: key) else { continue }
                uses[key, default: 0] += 1
                forms[key, default: [:]][token, default: 0] += 1
                if seen.insert(key).inserted { entriesWith[key, default: 0] += 1 }
            }
        }

        return entriesWith
            .filter { $0.value >= 2 }
            // Three-letter words survive only as names ("Sam", "Mom"):
            // capitalised every time they were said.
            .filter { $0.key.count >= 4 || (forms[$0.key] ?? [:]).keys.allSatisfy { $0.first?.isUppercase == true } }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                let a = uses[$0.key] ?? 0, b = uses[$1.key] ?? 0
                if a != b { return a > b }
                return $0.key < $1.key
            }
            .prefix(repeatLimit)
            .map { Repeat(word: shownForm(key: $0.key, forms: forms[$0.key] ?? [:]), entries: $0.value) }
    }

    static func moodCounts(_ raws: [String]) -> [MoodCount] {
        var counts: [String: Int] = [:]
        for raw in raws where Mood(rawValue: raw).map({ $0 != .none }) ?? false {
            counts[raw, default: 0] += 1
        }
        return counts
            .map { MoodCount(raw: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.raw < $1.raw }
    }

    // MARK: - Pieces

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// Letters only, so "Sarah's" is "Sarah" and "work," is "work".
    static func words(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
    }

    private static func isCandidate(_ token: String, key: String) -> Bool {
        key.count >= 3 && !stopWords.contains(key)
    }

    private static func shownForm(key: String, forms: [String: Int]) -> String {
        if forms[key] != nil { return key }
        return forms.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first?.key ?? key
    }

    private static func mean(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    /// Words that repeat in every journal and say nothing about this one.
    static let stopWords: Set<String> = [
        "the", "and", "for", "was", "were", "have", "has", "had", "with", "that", "this",
        "there", "then", "than", "from", "they", "them", "their", "what", "when", "which",
        "would", "could", "should", "about", "been", "being", "just", "like", "some",
        "more", "most", "much", "very", "into", "over", "again", "still", "even", "also",
        "back", "down", "but", "not", "now", "out", "our", "you", "your", "she", "him",
        "his", "her", "its", "one", "all", "any", "are", "can", "did", "get", "got", "how",
        "too", "who", "why", "way", "day", "days", "today", "myself", "really", "think",
        "know", "went", "said", "made", "time", "good", "bad",
        "nothing", "something", "anything", "everything", "thing", "things", "little",
        "kind", "sort", "stuff", "lot", "bit", "many",
        "didn", "doesn", "don", "wasn", "isn", "aren", "couldn", "wouldn",
        "shouldn", "haven", "hasn", "won", "ive", "going", "gonna", "want",
        "wanted", "feel", "felt", "feeling", "maybe", "yeah", "okay", "actually",
        "because", "after", "before", "while", "where", "here", "only", "other", "well",
        "make", "take", "took", "come", "came", "right", "need", "needed", "tonight",
        "yesterday", "tomorrow", "will", "onto", "upon", "each", "every", "both",
        "few", "own", "same", "such", "off", "yet", "may", "might", "must", "shall",
        "does", "doing", "done", "say", "says", "see", "saw", "seen", "let", "put",
        "use", "used", "new", "old", "two", "first", "last", "next", "long", "great",
        "able", "though", "through", "around", "always", "never", "sometimes", "pretty",
        "quite", "enough", "these", "those", "whole", "since", "until",
        "ago", "far", "yes", "lots", "guess", "mean", "probably", "already",
        "keep", "kept", "give", "gave", "tell", "told", "look", "looked", "talk",
        "talked", "start", "started", "trying", "tried", "seems", "seemed",
    ]
}
