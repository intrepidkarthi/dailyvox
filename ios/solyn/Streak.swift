//
//  Streak.swift
//  solyn
//
//  What counts as a run of days. One definition, every call site — the app,
//  the widgets and the Live Activities all compile this same file.
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
/// The widgets kept a fourth copy (`WidgetDataFetcher.calculateStreak`) and
/// the share card a fifth. Both read this one now.
///
/// ## The rule
///
/// A run is consecutive local days with at least one entry, with **one grace
/// day**: a single missed day between two spoken days does not break it.
///
/// - The grace day is not a spoken day. A run of Mon, Tue, (Wed missed), Thu
///   is three days, not four.
/// - Two missed days in a row always break the run.
/// - At most one grace day in any seven: two grace days in one run must be at
///   least seven days apart, so the rule cannot be chained into speaking every
///   other day.
///
/// A run is **current** while it reaches today or yesterday — a day is not
/// over until the user has had a chance to use it — or the day before
/// yesterday when yesterday can still be the run's grace day.
///
/// Days are local calendar days, numbered from each day's local noon (see
/// `dayNumber`), so a 23- or 25-hour day around a DST change is still exactly
/// one day.
enum Streak {

    /// Two grace days in one run must be at least this many days apart.
    static let graceSpacing = 7

    /// Where a journal stands, for every surface that shows a streak.
    struct Status: Equatable {
        enum Kind: Equatable {
            /// No entries at all. The new-user state.
            case new
            /// A current run of `current` spoken days.
            case active
            /// Has entries, but the run has broken. Not a new user, and never
            /// told "no streak yet" as if they were one.
            case returning
        }

        let kind: Kind
        /// Spoken days in the current run; 0 unless `kind == .active`.
        let current: Int
        /// The longest run anywhere in the journal, by the same rule.
        let longest: Int
        /// Distinct days with at least one entry, ever.
        let daysSpoken: Int
        /// Yesterday was missed and the run is being held by its grace day.
        /// Speaking today continues it; missing today too ends it.
        let restingYesterday: Bool
    }

    /// One run, in local day numbers.
    private struct Run {
        var lastDay: Int
        var spoken: Int
        var lastGrace: Int?

        /// Whether `missed` may be this run's grace day.
        func canGrace(_ missed: Int) -> Bool {
            guard let lastGrace else { return true }
            return missed - lastGrace >= Streak.graceSpacing
        }
    }

    // MARK: - Public

    /// Where the journal stands right now.
    static func status(days: Set<Date>, now: Date = Date(),
                       calendar: Calendar = .current) -> Status {
        let numbers = dayNumbers(days, calendar: calendar)
        guard !numbers.isEmpty else {
            return Status(kind: .new, current: 0, longest: 0, daysSpoken: 0, restingYesterday: false)
        }
        let today = dayNumber(now, calendar: calendar)
        let allRuns = runs(numbers)
        let longest = allRuns.map(\.spoken).max() ?? 0

        // Days after today (a clock or time zone change) cannot be part of a
        // run that ends today. Greedy runs are prefix-stable, so the current
        // run here is a prefix of one in `allRuns` and never exceeds `longest`.
        let current = runs(numbers.filter { $0 <= today }).last
        var active = 0
        var resting = false
        if let run = current {
            let gap = today - run.lastDay
            if gap <= 1 {
                active = run.spoken
            } else if gap == 2, run.canGrace(today - 1) {
                active = run.spoken
                resting = true
            }
        }

        return Status(kind: active > 0 ? .active : .returning,
                      current: active,
                      longest: longest,
                      daysSpoken: numbers.count,
                      restingYesterday: resting)
    }

    /// Convenience for callers holding entry dates rather than day starts.
    static func status(dates: [Date], now: Date = Date(),
                       calendar: Calendar = .current) -> Status {
        status(days: Set(dates.map { calendar.startOfDay(for: $0) }), now: now, calendar: calendar)
    }

    /// Spoken days in the current run. Zero if the run has broken.
    ///
    /// Takes days rather than entries so it cannot accidentally count two
    /// entries on one evening as two days.
    static func current(days: Set<Date>, now: Date = Date(),
                        calendar: Calendar = .current) -> Int {
        status(days: days, now: now, calendar: calendar).current
    }

    /// Convenience for callers holding entry dates rather than day starts.
    static func current(dates: [Date], now: Date = Date(),
                        calendar: Calendar = .current) -> Int {
        status(dates: dates, now: now, calendar: calendar).current
    }

    /// The longest run anywhere in the journal, past or present.
    static func longest(days: Set<Date>, calendar: Calendar = .current) -> Int {
        runs(dayNumbers(days, calendar: calendar)).map(\.spoken).max() ?? 0
    }

    // MARK: - Pieces

    /// A local day as an integer, so "consecutive" is plain subtraction.
    ///
    /// Not `ordinality(of: .day, in: .era)`: that counts days on a fixed
    /// offset, so in Kolkata 00:00 and 20:00 on one date came back as two
    /// different days. Local noon, as seconds on the local clock, divided
    /// by a day, cannot straddle a boundary: a DST shift moves noon an hour,
    /// never into another day.
    static func dayNumber(_ date: Date, calendar: Calendar) -> Int {
        let noon = calendar.startOfDay(for: date).addingTimeInterval(12 * 3_600)
        let local = noon.timeIntervalSinceReferenceDate
            + Double(calendar.timeZone.secondsFromGMT(for: noon))
        return Int((local / 86_400).rounded(.down))
    }

    private static func dayNumbers(_ days: Set<Date>, calendar: Calendar) -> [Int] {
        Set(days.map { dayNumber($0, calendar: calendar) }).sorted()
    }

    /// Splits sorted, distinct day numbers into runs, oldest first, spending a
    /// grace day on a single-day gap whenever the run's last one is far enough
    /// back.
    private static func runs(_ sorted: [Int]) -> [Run] {
        var out: [Run] = []
        for day in sorted {
            if var run = out.last {
                let gap = day - run.lastDay
                if gap == 1 {
                    run.lastDay = day
                    run.spoken += 1
                    out[out.count - 1] = run
                    continue
                }
                if gap == 2, run.canGrace(day - 1) {
                    run.lastGrace = day - 1
                    run.lastDay = day
                    run.spoken += 1
                    out[out.count - 1] = run
                    continue
                }
            }
            out.append(Run(lastDay: day, spoken: 1, lastGrace: nil))
        }
        return out
    }
}
