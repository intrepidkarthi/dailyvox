//
//  Streak.swift
//  solyn
//
//  What counts as a run of days. One definition, three call sites.
//

import Foundation

/// The streak rule.
///
/// This exists because the rule was written **three times** — in `TodayView`'s
/// header, in `StatsView`'s Insights card, and in the global `currentStreak(in:)`
/// the Live Activity and Settings read — and one of the three was wrong.
///
/// `TodayView.streakCount` seeded `streak = 1` from the most recent entry day
/// and walked backwards, with no check that the run reached the present. So
/// someone who journaled five days straight in March and never returned saw
/// **"5-day streak"** on the Record tab, **"0 days"** on Insights, and nothing
/// on the Lock Screen — three surfaces of one app disagreeing about the same
/// journal, with the most prominent one flattering.
///
/// ## The rule
///
/// A streak is the run of consecutive days ending **today or yesterday**.
/// Yesterday still counts because a day is not over until the user has had a
/// chance to use it; anything older is a past streak, not a current one.
enum Streak {

    /// Consecutive days ending today or yesterday. Zero if the run has broken.
    ///
    /// Takes days rather than entries so it cannot accidentally count two
    /// entries on one evening as two days.
    static func current(days: Set<Date>, now: Date = Date(),
                        calendar: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            // Yesterday, then — but only that far.
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            guard days.contains(cursor) else { return 0 }
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Convenience for callers holding entry dates rather than day starts.
    static func current(dates: [Date], now: Date = Date(),
                        calendar: Calendar = .current) -> Int {
        current(days: Set(dates.map { calendar.startOfDay(for: $0) }),
                now: now, calendar: calendar)
    }

    /// The longest run anywhere in the journal, past or present.
    static func longest(days: Set<Date>, calendar: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1, run = 1
        for i in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            run = gap == 1 ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }
}
