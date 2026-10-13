//
//  SuggestedMood.swift
//  solyn
//
//  A mood offered from the entry's own words, never decided for the user.
//

import Foundation
import DailyVoxTwinEngine

/// Nothing in the app ever set a mood except the user, by hand, from a picker
/// most people never open. So mood trends stayed empty for almost everyone,
/// and onboarding promised "the transcript, the mood, the star" and saved the
/// first star with no mood at all.
///
/// This reads the on-device sentiment and emotion words the engine already
/// computes and maps them onto the app's own eight moods — but only when the
/// two agree and the signal is clear. A wrong mood is worse than none: it is
/// the app telling you how you felt. So every ambiguous case answers nil, and
/// what it does answer is shown as a suggestion, one tap from changed.
enum SuggestedMood {

    /// Below this many words there is not enough said to read a mood from.
    static let minimumWords = 5
    /// How far from neutral the whole-entry sentiment must be before it
    /// counts as leaning either way. This is a floor, not a verdict: the
    /// scorer puts some plain accounts of a day well below -0.4 ("it was okay
    /// I guess, nothing special"), so a lean alone never picks a mood — a
    /// named feeling or word has to agree with it.
    static let leanThreshold = 0.4
    /// Excited is the loud end of positive, so it needs more than a lean.
    static let excitedThreshold = 0.6
    /// A word this many tokens or fewer after "not", "never", "didn't"… is
    /// what the user said they did not feel.
    static let negationReach = 3

    /// Runs the same on-device analysis the reflection uses — `learn: false`,
    /// because this looks at the whole day's text after every recording and
    /// must not count it into the profile again each time.
    static func suggest(for text: String) -> Mood? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let engine = LocalAIEngine.shared
        let analysis = engine.analyze(text: trimmed, learn: false)
        // The engine counts feeling words with no idea of "not": "I am not
        // sad" scores as sadness. So the feelings are read again from only
        // the words that were not denied. Sentiment stays the whole text's.
        var emotions = analysis.emotions
        let kept = affirmed(in: trimmed).filter { $0 != denied }
        if kept.count < tokens(in: trimmed).count {
            emotions = kept.isEmpty ? [:] : engine.analyze(text: kept.joined(separator: " "), learn: false).emotions
        }
        return suggest(sentiment: analysis.sentiment, emotions: emotions, text: trimmed)
    }

    /// The pure decision. `sentiment` is the engine's whole-entry score in
    /// [-1, 1]; `emotions` is its per-emotion keyword weight, read from the
    /// words that were not negated (see `suggest(for:)`). Lexicon words in
    /// `text` count only where they are not negated.
    static func suggest(sentiment: Double, emotions: [DetectedEmotion: Double], text: String) -> Mood? {
        let words = tokens(in: text)
        guard words.count >= minimumWords else { return nil }

        let positive = sentiment >= leanThreshold
        let negative = sentiment <= -leanThreshold
        let feeling = dominantFeeling(emotions)
        // Feelings present but none ahead — "grateful, but anxious about
        // money" — is mixed, not a mood. Say nothing rather than let a
        // lexicon word below pick one side.
        if feeling == nil, hasFeeling(emotions) { return nil }
        let said = " " + affirmed(in: text).joined(separator: " ") + " "
        func mentions(_ lexicon: [String]) -> Bool {
            lexicon.contains { said.contains(" " + $0 + " ") }
        }

        if positive {
            // A positive score with a negative feeling dominant is two
            // signals disagreeing. Say nothing.
            if let feeling, [.sadness, .anger, .fear].contains(feeling) { return nil }
            if mentions(gratitudeWords) { return .grateful }
            if feeling == .anticipation || feeling == .surprise {
                return sentiment >= excitedThreshold ? .excited : nil
            }
            if feeling == .joy { return .happy }
            if mentions(calmWords) || feeling == .trust { return .calm }
            // Positive, but nothing says which kind. "Happy" would be a guess.
            return nil
        }

        if negative {
            if feeling == .joy { return nil }
            switch feeling {
            case .sadness: return .sad
            case .anger: return .angry
            case .fear: return .anxious
            default: break
            }
            if feeling == nil, mentions(tiredWords) { return .tired }
            return nil
        }

        // Neutral overall. Only tiredness is reliably said in flat words
        // ("long day, completely drained"), and only when nothing upbeat or
        // troubled competes with it.
        if sentiment <= 0, feeling == nil, mentions(tiredWords) { return .tired }
        return nil
    }

    // MARK: - Pieces

    /// The single strongest feeling, or nil when there is none or two tie —
    /// a tie is the tagger not knowing, and a mood picked by tie-break would
    /// be the app guessing.
    static func dominantFeeling(_ emotions: [DetectedEmotion: Double]) -> DetectedEmotion? {
        let ranked = emotions
            .filter { $0.key != .neutral && $0.value > 0 }
            .sorted { $0.value > $1.value }
        guard let top = ranked.first else { return nil }
        if ranked.count > 1, ranked[1].value >= top.value { return nil }
        return top.key
    }

    /// Any feeling at all, so a tie can be told apart from silence.
    static func hasFeeling(_ emotions: [DetectedEmotion: Double]) -> Bool {
        emotions.contains { $0.key != .neutral && $0.value > 0 }
    }

    /// Lowercased words, apostrophes kept so "can't" stays one word.
    static func tokens(in text: String) -> [String] {
        normalized(text)
            .components(separatedBy: wordBreaks)
            .filter { !$0.isEmpty }
    }

    /// Stands in for a word the user negated, so it can match nothing.
    static let denied = "\u{00B7}"

    /// `tokens(in:)`, with every word the user negated replaced by `denied`.
    /// A negation reaches `negationReach` words forward and stops at the end
    /// of its clause: in "not sad, just tired", "tired" is still said.
    static func affirmed(in text: String) -> [String] {
        var out: [String] = []
        for clause in normalized(text).components(separatedBy: clauseBreaks) {
            let words = clause.components(separatedBy: wordBreaks).filter { !$0.isEmpty }
            var reach = 0
            for (i, w) in words.enumerated() {
                if reach > 0 {
                    out.append(denied)
                    reach -= 1
                } else {
                    out.append(w)
                }
                if isNegator(w, next: i + 1 < words.count ? words[i + 1] : nil) {
                    reach = negationReach
                }
            }
        }
        return out
    }

    static func isNegator(_ word: String, next: String?) -> Bool {
        // "Can't wait" is eagerness, not denial.
        if word == "can't" && next == "wait" { return false }
        return negators.contains(word) || word.hasSuffix("n't")
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }

    private static let wordBreaks = CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted
    private static let clauseBreaks = CharacterSet(charactersIn: ".,;:!?\n\u{2014}")

    static let negators: Set<String> = ["not", "no", "never", "without", "cannot", "nor"]
    static let gratitudeWords = ["grateful", "thankful", "appreciate", "appreciated", "blessed"]
    static let calmWords = ["calm", "peaceful", "relaxed", "at peace", "content", "unhurried", "rested"]
    static let tiredWords = ["tired", "exhausted", "drained", "worn out", "sleepy", "fatigued", "knackered", "wiped out"]
}

// MARK: - Suggested vs chosen

/// What to do with an entry's mood after new words arrive.
///
/// Whose mood it is lives on the entry itself: `suggestedMood` holds exactly
/// the value the app last suggested, and the mood is a suggestion only while
/// `mood` still equals it. It is a Core Data attribute, so it syncs with the
/// mood through CloudKit, rides backups, and the widget can read it. Comparing
/// values rather than keeping a flag means any other writer — the user on
/// another device, an older build that knows nothing of suggestions — that
/// sets a different mood makes it the user's, and it is never written over.
enum SuggestedMoodUpdate: Equatable {
    case leave
    case suggest(Mood)
    case clear

    /// The one rule that matters: a mood the user set is never touched.
    /// Only an empty mood (nil — not "": before this, the detail screen wrote
    /// "" both for a deliberate "No mood" and on any text edit, and the two
    /// cannot be told apart, so "" is treated as the user's) or the very one
    /// we suggested may change. A suggestion that the new, longer text no
    /// longer supports is withdrawn rather than left standing as if it held.
    static func decide(currentMood: String?, lastSuggested: String?,
                       suggestion: Mood?) -> SuggestedMoodUpdate {
        if let lastSuggested, currentMood == lastSuggested {
            if let suggestion { return currentMood == suggestion.rawValue ? .leave : .suggest(suggestion) }
            return .clear
        }
        guard currentMood == nil, let suggestion else { return .leave }
        return .suggest(suggestion)
    }
}

extension DiaryEntry {
    /// True while the mood is the one the app read from the words and the
    /// user has not replaced it.
    var isMoodSuggested: Bool {
        guard let mood, !mood.isEmpty, let suggestedMood else { return false }
        return mood == suggestedMood
    }

    /// The mood only if the user chose it — what the Twin should learn from
    /// and what correlations should be computed against. A suggestion is the
    /// app's reading of the words; feeding it back as the user's own report
    /// would have the Twin quoting its guess back as a pattern.
    var userMood: String? {
        isMoodSuggested ? nil : mood
    }

    /// The user picked this — a mood, or "No mood" (""). Either way it is
    /// theirs, and since it no longer equals any suggestion it is never
    /// suggested over again.
    func setMoodChosenByUser(_ raw: String) {
        mood = raw
        suggestedMood = nil
    }

    /// Re-reads the entry's whole text and applies `SuggestedMoodUpdate`.
    /// Returns true when the mood changed and the context needs saving.
    @discardableResult
    func refreshSuggestedMood() -> Bool {
        let update = SuggestedMoodUpdate.decide(
            currentMood: mood,
            lastSuggested: suggestedMood,
            suggestion: SuggestedMood.suggest(for: text ?? ""))
        switch update {
        case .leave:
            return false
        case .suggest(let m):
            mood = m.rawValue
            suggestedMood = m.rawValue
            return true
        case .clear:
            mood = nil
            suggestedMood = nil
            return true
        }
    }
}
