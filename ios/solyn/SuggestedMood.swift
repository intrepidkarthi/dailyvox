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
    /// counts as leaning either way. NLTagger scores a plain account of the
    /// day at or near 0; ±0.4 is "clearly said with feeling".
    static let leanThreshold = 0.4
    /// Excited is the loud end of positive, so it needs more than a lean.
    static let excitedThreshold = 0.6

    /// Runs the same on-device analysis the reflection uses — `learn: false`,
    /// because this looks at the whole day's text after every recording and
    /// must not count it into the profile again each time.
    static func suggest(for text: String) -> Mood? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let analysis = LocalAIEngine.shared.analyze(text: trimmed, learn: false)
        return suggest(sentiment: analysis.sentiment, emotions: analysis.emotions, text: trimmed)
    }

    /// The pure decision. `sentiment` is the engine's whole-entry score in
    /// [-1, 1]; `emotions` is its per-emotion keyword weight.
    static func suggest(sentiment: Double, emotions: [DetectedEmotion: Double], text: String) -> Mood? {
        let words = tokens(in: text)
        guard words.count >= minimumWords else { return nil }

        let positive = sentiment >= leanThreshold
        let negative = sentiment <= -leanThreshold
        let feeling = dominantFeeling(emotions)
        let said = " " + words.joined(separator: " ") + " "
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
            if mentions(tiredWords) { return .tired }
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

    /// Lowercased words, apostrophes kept so "can't" stays one word.
    static func tokens(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }

    static let gratitudeWords = ["grateful", "thankful", "appreciate", "appreciated", "blessed"]
    static let calmWords = ["calm", "peaceful", "relaxed", "at peace", "content", "unhurried", "rested"]
    static let tiredWords = ["tired", "exhausted", "drained", "worn out", "sleepy", "fatigued", "knackered", "wiped out"]
}

// MARK: - Suggested vs chosen

/// Which entries carry a suggested mood rather than one the user chose.
///
/// Kept in UserDefaults, not Core Data, so this needs no schema change: the
/// `mood` attribute already holds the value either way, and this set only says
/// whose it is. The cost is that the marker does not travel with CloudKit — on
/// a second device a synced suggestion reads as an ordinary mood. That device
/// never re-suggests over it either, since only a nil mood is ever filled.
final class SuggestedMoodStore {
    static let shared = SuggestedMoodStore()

    private let defaults: UserDefaults
    private let suggestedKey = "suggestedMoodEntryIDs"
    private let chosenKey = "userChosenMoodEntryIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isSuggested(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return set(suggestedKey).contains(id.uuidString)
    }

    /// True once the user has picked anything for this entry — a mood, or
    /// "No mood". Either way it is theirs and is never suggested over again.
    func userChose(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return set(chosenKey).contains(id.uuidString)
    }

    func markSuggested(_ id: UUID?) {
        guard let id else { return }
        update(suggestedKey) { $0.insert(id.uuidString) }
    }

    func clearSuggested(_ id: UUID?) {
        guard let id else { return }
        update(suggestedKey) { $0.remove(id.uuidString) }
    }

    /// The user set the mood themselves; it stops being a suggestion.
    func markChosenByUser(_ id: UUID?) {
        guard let id else { return }
        update(suggestedKey) { $0.remove(id.uuidString) }
        update(chosenKey) { $0.insert(id.uuidString) }
    }

    /// Read once per key and kept: `userMood` is asked for every entry when
    /// the engines walk the whole journal. This store is the only writer.
    private var cache: [String: Set<String>] = [:]
    private let lock = NSLock()

    private func set(_ key: String) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return loaded(key)
    }

    private func update(_ key: String, _ change: (inout Set<String>) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var s = loaded(key)
        change(&s)
        cache[key] = s
        defaults.set(Array(s).sorted(), forKey: key)
    }

    /// Caller holds `lock`.
    private func loaded(_ key: String) -> Set<String> {
        if let cached = cache[key] { return cached }
        let fresh = Set(defaults.stringArray(forKey: key) ?? [])
        cache[key] = fresh
        return fresh
    }
}

/// What to do with an entry's mood after new words arrive.
enum SuggestedMoodUpdate: Equatable {
    case leave
    case suggest(Mood)
    case clear

    /// The one rule that matters: a mood the user set is never touched.
    /// Only an empty mood (nil — not "": before this, the detail screen wrote
    /// "" both for a deliberate "No mood" and on any text edit, and the two
    /// cannot be told apart, so "" is treated as the user's) or one we
    /// suggested ourselves may change. A suggestion that the new, longer text no longer supports
    /// is withdrawn rather than left standing as if it still held.
    static func decide(currentMood: String?, isSuggested: Bool, userChose: Bool,
                       suggestion: Mood?) -> SuggestedMoodUpdate {
        guard !userChose else { return .leave }
        if isSuggested {
            if let suggestion { return currentMood == suggestion.rawValue ? .leave : .suggest(suggestion) }
            return .clear
        }
        guard currentMood == nil, let suggestion else { return .leave }
        return .suggest(suggestion)
    }
}

extension DiaryEntry {
    /// The mood only if the user chose it — what the Twin should learn from
    /// and what correlations should be computed against. A suggestion is the
    /// app's reading of the words; feeding it back as the user's own report
    /// would have the Twin quoting its guess back as a pattern.
    var userMood: String? {
        SuggestedMoodStore.shared.isSuggested(id) ? nil : mood
    }

    var isMoodSuggested: Bool {
        guard let mood, !mood.isEmpty else { return false }
        return SuggestedMoodStore.shared.isSuggested(id)
    }

    /// Re-reads the entry's whole text and applies `SuggestedMoodUpdate`.
    /// Returns true when the mood changed and the context needs saving.
    @discardableResult
    func refreshSuggestedMood(store: SuggestedMoodStore = .shared) -> Bool {
        let update = SuggestedMoodUpdate.decide(
            currentMood: mood,
            isSuggested: store.isSuggested(id),
            userChose: store.userChose(id),
            suggestion: SuggestedMood.suggest(for: text ?? ""))
        switch update {
        case .leave:
            return false
        case .suggest(let m):
            mood = m.rawValue
            store.markSuggested(id)
            return true
        case .clear:
            mood = nil
            store.clearSuggested(id)
            return true
        }
    }
}
