//
//  TwinPatterns.swift
//  solyn
//
//  "Your Twin noticed ✦" — the pattern list from B6, ported from Android's
//  `Patterns.find`.
//

import Foundation
import CoreData

/// One thing the Twin has noticed, with the arithmetic that justifies it.
struct TwinPattern: Identifiable {
    let id = UUID()
    /// The claim, in one short sentence.
    let lead: String
    /// The numbers behind it. Always shown — a pattern the user cannot check is
    /// a horoscope.
    let detail: String
    /// Effect size, used only for ranking.
    let effect: Double
}

/// Finds patterns worth saying out loud.
///
/// Every rule here has a minimum sample and a minimum effect, and both gates are
/// deliberately conservative. The failure mode this is guarding against is not
/// missing a pattern — it is telling someone that Tuesdays are hard when what
/// happened is that they had two bad Tuesdays. A journal that manufactures
/// significance is worse than one that says nothing.
///
/// This mirrors Android's `Patterns.find` rule for rule, minus the sleep and
/// steps effects: those read `sleepHours`/`stepsToday` columns that the iOS
/// entry does not have. Body correlations on this platform come from
/// `BodyTwinManager`, which the Insights screen already shows separately.
enum TwinPatterns {

    /// Below this there is not enough of anything to be sure. Until then,
    /// Insights shows `EarlySignals` instead — counts, not claims.
    static let minimumEntries = 8
    /// At most this many day-of-week findings, so one weekday quirk cannot fill
    /// the whole list.
    private static let dayOfWeekCap = 2

    static func find(_ entries: [DiaryEntry], people: [String] = []) -> [TwinPattern] {
        guard entries.count >= minimumEntries else { return [] }

        let calendar = Calendar.current
        let scored = entries.compactMap { entry -> (date: Date, valence: Double, text: String)? in
            guard let date = entry.date else { return nil }
            return (date, valence(of: entry), (entry.text ?? "").lowercased())
        }
        guard scored.count >= minimumEntries else { return [] }

        let overall = scored.map(\.valence).reduce(0, +) / Double(scored.count)
        var out: [TwinPattern] = []

        // ── Day of week ─────────────────────────────────────────────────────
        var byWeekday: [Int: [Double]] = [:]
        for s in scored {
            byWeekday[calendar.component(.weekday, from: s.date), default: []].append(s.valence)
        }
        var weekdayFindings: [TwinPattern] = []
        for (weekday, values) in byWeekday where values.count >= 3 {
            let mean = values.reduce(0, +) / Double(values.count)
            let delta = mean - overall
            guard abs(delta) > 0.22 else { continue }
            let name = calendar.weekdaySymbols[weekday - 1]
            weekdayFindings.append(TwinPattern(
                lead: delta < 0
                    ? String(localized: "\(name)s run low.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries on this weekday read lower than usual. The placeholder is a weekday name from the calendar ('Monday'); the English adds 's' to make it plural, so rephrase freely ('On Mondays…').")
                    : String(localized: "\(name)s run high.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries on this weekday read higher than usual. The placeholder is a weekday name from the calendar ('Monday'); the English adds 's' to make it plural, so rephrase freely ('On Mondays…')."),
                detail: String(localized: "\(LocaleFormat.decimal(mean, fractionDigits: 2, signed: true)) against your \(LocaleFormat.decimal(overall, fractionDigits: 2, signed: true)) average, across \(values.count) entries.", comment: "Twin tab, Patterns: smaller line under the finding, giving the numbers behind it. Mood scores run from -1 to +1 and arrive already formatted for the locale with a sign ('+0.21'). About 90 characters. First placeholder: the weekday's average. Second: the user's overall average. Third: how many entries fell on that weekday (3 or more)."),
                effect: abs(delta)
            ))
        }
        out += weekdayFindings.sorted { $0.effect > $1.effect }.prefix(dayOfWeekCap)

        // ── People ──────────────────────────────────────────────────────────
        // Names come from the knowledge graph rather than from a regex over the
        // text: the graph has already decided what is a person.
        for name in people {
            let needle = name.lowercased()
            guard !needle.isEmpty else { continue }
            let mentions = scored.filter { $0.text.contains(needle) }
            guard mentions.count >= 3 else { continue }
            let mean = mentions.map(\.valence).reduce(0, +) / Double(mentions.count)
            let delta = mean - overall
            guard abs(delta) > 0.2 else { continue }
            out.append(TwinPattern(
                lead: delta > 0
                    ? String(localized: "\(name) lifts you.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries that mention this person read brighter. The placeholder is a person's name from the user's journal.")
                    : String(localized: "\(name) weighs on you.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries that mention this person read heavier. The placeholder is a person's name from the user's journal. Gentle, not a judgement of the person."),
                detail: String(localized: "Entries mentioning them average \(LocaleFormat.decimal(mean, fractionDigits: 2, signed: true)) against your \(LocaleFormat.decimal(overall, fractionDigits: 2, signed: true)) overall, across \(String(mentions.count)) of them.", comment: "Twin tab, Patterns: smaller line under the finding, giving the numbers behind it. Mood scores run from -1 to +1 and arrive already formatted for the locale with a sign ('+0.21'). About 90 characters. 'them' is the person named above; keep it gender-neutral. First placeholder: the average in entries that mention them. Second: the user's overall average. Third (a string placeholder): how many entries mention them. Counts marked as string placeholders arrive as digits, exactly as the English has always printed them (never grouped), so the catalog cannot vary them by count: phrase it so one form reads right for every count."),
                effect: abs(delta)
            ))
        }

        // ── Time of day ─────────────────────────────────────────────────────
        // Free, needs no sensor and no permission — the same reasoning that put
        // `hourOfDay` on the Android entry.
        let morning = scored.filter { calendar.component(.hour, from: $0.date) < 12 }
        let evening = scored.filter { calendar.component(.hour, from: $0.date) >= 18 }
        if morning.count >= 4, evening.count >= 4 {
            let m = morning.map(\.valence).reduce(0, +) / Double(morning.count)
            let e = evening.map(\.valence).reduce(0, +) / Double(evening.count)
            if abs(m - e) > 0.2 {
                out.append(TwinPattern(
                    lead: m > e
                        ? String(localized: "Mornings read brighter.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries spoken before noon read brighter than those after 18:00.")
                        : String(localized: "Evenings read brighter.", comment: "Twin tab, Patterns: bold first line of a finding about the user's mood. Short, about 30 characters. Entries spoken after 18:00 read brighter than those before noon."),
                    detail: String(localized: "Before noon you write \(LocaleFormat.decimal(m, fractionDigits: 2, signed: true)); after six, \(LocaleFormat.decimal(e, fractionDigits: 2, signed: true)). \(String(morning.count)) entries and \(String(evening.count)).", comment: "Twin tab, Patterns: smaller line under the finding, giving the numbers behind it. Mood scores run from -1 to +1 and arrive already formatted for the locale with a sign ('+0.21'). About 90 characters. 'after six' means after 18:00. First placeholder: the morning average. Second: the evening average. Third and fourth (string placeholders): how many morning and evening entries. Counts marked as string placeholders arrive as digits, exactly as the English has always printed them (never grouped), so the catalog cannot vary them by count: phrase it so one form reads right for every count."),
                    effect: abs(m - e)
                ))
            }
        }

        return out.sorted { $0.effect > $1.effect }
    }

    /// Same mapping the share cards use, so a number on a card and a number in
    /// this list can never disagree. Chosen moods only, as the cards read: a
    /// pattern is a claim about the user, not about the app's suggestions.
    private static func valence(of entry: DiaryEntry) -> Double {
        let mood = Mood(rawValue: entry.userMood ?? "") ?? Mood.none
        return (Double(mood.moodValue) - 3.0) / 2.0
    }
}
