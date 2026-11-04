//
//  StreakTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// A streak that counts wrong does not crash — it flatters, or it scolds. The
/// first bug this pins was a Record tab reading "5-day streak" for a journal
/// last written in March, while Insights read 0 from a different copy of the
/// same rule. The second is the other direction: one missed evening wiping a
/// month, and a returning user greeted exactly like a stranger.
final class StreakTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private let now = Date(timeIntervalSince1970: 1_755_820_800)  // a fixed noon

    private func days(_ agos: [Int]) -> Set<Date> {
        Set(agos.map { cal.startOfDay(for: now.addingTimeInterval(Double(-$0) * 86_400)) })
    }

    private func status(_ agos: [Int]) -> Streak.Status {
        Streak.status(days: days(agos), now: now, calendar: cal)
    }

    // MARK: - The bug

    /// Five days in a row, all of them long finished. That is a past streak.
    func testAbandonedRunIsNotACurrentStreak() {
        XCTAssertEqual(Streak.current(days: days([40, 41, 42, 43, 44]), now: now, calendar: cal), 0)
    }

    // MARK: - The rule

    func testTodayAloneIsOne() {
        XCTAssertEqual(Streak.current(days: days([0]), now: now, calendar: cal), 1)
    }

    /// A day is not over until it has been used, so yesterday keeps a run alive.
    func testYesterdayKeepsTheRunAlive() {
        XCTAssertEqual(Streak.current(days: days([1, 2, 3]), now: now, calendar: cal), 3)
    }

    func testEmptyJournalHasNoStreak() {
        XCTAssertEqual(Streak.current(days: [], now: now, calendar: cal), 0)
    }

    /// Three entries in one evening are one day, not three.
    func testSeveralEntriesInADayCountOnce() {
        let day = now.addingTimeInterval(-3_600)
        let dates = [day, day.addingTimeInterval(600), day.addingTimeInterval(1_200)]
        XCTAssertEqual(Streak.current(dates: dates, now: now, calendar: cal), 1)
    }

    // MARK: - The grace day

    /// One missed day inside a run does not break it, and is not counted.
    func testOneMissedDayIsForgivenAndNotCounted() {
        // today, yesterday, (2 missed), 3, 4, 5
        XCTAssertEqual(Streak.current(days: days([0, 1, 3, 4, 5]), now: now, calendar: cal), 5)
    }

    /// Two missed days in a row always end it.
    func testTwoMissedDaysEndTheRun() {
        XCTAssertEqual(Streak.current(days: days([0, 1, 4, 5, 6]), now: now, calendar: cal), 2)
    }

    /// Yesterday missed, today not spoken yet: the run is held, not lost —
    /// today can still be spoken.
    func testYesterdayMissedHoldsTheRunWhileTodayIsOpen() {
        let s = status([2, 3, 4])
        XCTAssertEqual(s.kind, .active)
        XCTAssertEqual(s.current, 3)
        XCTAssertTrue(s.restingYesterday)
    }

    /// Yesterday and the day before both missed: that run is over.
    func testThreeDaysAgoHasBroken() {
        XCTAssertEqual(status([3, 4, 5]).current, 0)
    }

    /// Speaking every other day is not a run: a second grace day inside a
    /// week is refused, so the run keeps restarting.
    func testGraceCannotBeChainedEveryOtherDay() {
        // 8, (7), 6 | 4, (3), 2 | 0 — each second gap ends the run.
        let s = status([0, 2, 4, 6, 8])
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 2)
    }

    /// Exactly seven days apart is allowed; six is not.
    func testGraceDaysMustBeSevenApart() {
        // Graces on days 8 and 1 ago — seven apart. Spoken: 0, 2…7, 9, 10.
        let sevenApart = [0, 2, 3, 4, 5, 6, 7, 9, 10]
        XCTAssertEqual(Streak.current(days: days(sevenApart), now: now, calendar: cal), 9)

        // Gaps on days 7 and 1 ago — six apart. The older gap takes the
        // grace, so the newer one ends the run: today starts a new one.
        let sixApart = [0, 2, 3, 4, 5, 6, 8, 9]
        XCTAssertEqual(Streak.current(days: days(sixApart), now: now, calendar: cal), 1)
        XCTAssertEqual(Streak.longest(days: days(sixApart), calendar: cal), 7)
    }

    /// The pending grace day obeys the same limit: with a grace already used
    /// this week, a missed yesterday ends the run.
    func testPendingGraceRespectsTheWeeklyLimit() {
        // Spoken 2, 3, (4 missed), 5, 6. Yesterday (1) missed too.
        let s = status([2, 3, 5, 6])
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.kind, .returning)
    }

    // MARK: - New, active, returning

    func testEmptyJournalIsNew() {
        let s = status([])
        XCTAssertEqual(s.kind, .new)
        XCTAssertEqual(s.longest, 0)
        XCTAssertEqual(s.daysSpoken, 0)
    }

    /// A returning user keeps their longest run and days spoken; they are not
    /// shown the empty-journal state.
    func testReturningUserKeepsTheirHistory() {
        let s = status([10, 11, 12, 13, 30])
        XCTAssertEqual(s.kind, .returning)
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.longest, 4)
        XCTAssertEqual(s.daysSpoken, 5)
        XCTAssertFalse(s.restingYesterday)
    }

    func testSpeakingAgainMakesItActive() {
        let s = status([0, 10, 11, 12])
        XCTAssertEqual(s.kind, .active)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 3)
    }

    // MARK: - Longest

    func testLongestFindsAPastRun() {
        XCTAssertEqual(Streak.longest(days: days([0, 5, 6, 7, 8, 20]), calendar: cal), 4)
    }

    func testLongestUsesTheGraceDayToo() {
        XCTAssertEqual(Streak.longest(days: days([20, 21, 23, 24, 40]), calendar: cal), 4)
    }

    func testLongestOfNothingIsZero() {
        XCTAssertEqual(Streak.longest(days: [], calendar: cal), 0)
    }

    /// The two must agree when the run reaches the present — a current streak is
    /// by definition also a run, so it can never exceed the longest.
    func testCurrentNeverExceedsLongest() {
        for pattern in [[0, 1, 2, 9, 10], [0, 2, 3, 5, 6, 7], [1, 3, 4, 6, 8, 9, 10], [2, 4, 5, 6]] {
            let s = status(pattern)
            XCTAssertLessThanOrEqual(s.current, s.longest, "\(pattern)")
        }
    }

    /// A day after today (a time zone change) cannot inflate today's run.
    func testFutureDayIsNotPartOfTheCurrentRun() {
        XCTAssertEqual(status([-1, 0]).current, 1)
    }

    // MARK: - Local days, time zones, DST

    /// The day is the user's local day: 23:30 and 00:30 in Kolkata are two
    /// days, though both fall on one UTC date.
    func testDaysAreLocalNotUTC() {
        var ist = Calendar(identifier: .gregorian)
        ist.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        // 2026-03-10 23:30 and 2026-03-11 00:30 IST.
        let late = ist.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 23, minute: 30))!
        let early = ist.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 0, minute: 30))!
        let s = Streak.status(dates: [late, early], now: early, calendar: ist)
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.daysSpoken, 2)
    }

    /// `ordinality(of: .day, in: .era)` put 00:00 and 20:00 of one Kolkata
    /// date on different days. Every hour of a local date is one day number,
    /// and the next date is the next number, in zones on both sides of UTC.
    func testEveryHourOfALocalDateIsOneDay() {
        for zone in ["Asia/Kolkata", "America/Los_Angeles", "Pacific/Chatham", "UTC"] {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: zone)!
            let first = c.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 0, minute: 0))!
            let n = Streak.dayNumber(first, calendar: c)
            for minutes in stride(from: 0, to: 24 * 60, by: 37) {
                let t = c.date(byAdding: .minute, value: minutes, to: first)!
                XCTAssertEqual(Streak.dayNumber(t, calendar: c), n, "\(zone) +\(minutes)m")
            }
            let next = c.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 0, minute: 1))!
            XCTAssertEqual(Streak.dayNumber(next, calendar: c), n + 1, zone)
        }
    }

    /// Across the spring-forward night the 23-hour day is still one day.
    func testSpringForwardIsOneDay() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        // US DST began 2026-03-08 at 02:00.
        let dates = (6...10).map {
            ny.date(from: DateComponents(year: 2026, month: 3, day: $0, hour: 21))!
        }
        XCTAssertEqual(Streak.status(dates: dates, now: dates.last!, calendar: ny).current, 5)
    }

    /// The grace day across a DST change is still exactly one missed day.
    func testGraceAcrossFallBack() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        // US DST ended 2026-11-01. Spoken 10-31, (11-01 missed), 11-02, 11-03.
        let dates = [31, 2, 3].enumerated().map { i, day in
            ny.date(from: DateComponents(year: 2026, month: i == 0 ? 10 : 11, day: day, hour: 8))!
        }
        XCTAssertEqual(Streak.status(dates: dates, now: dates.last!, calendar: ny).current, 3)
    }

    /// Late on the night two days after the last entry, the held run is
    /// still held; one minute past midnight it is not.
    func testHeldRunEndsAtLocalMidnight() {
        var ist = Calendar(identifier: .gregorian)
        ist.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let spoken = ist.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 20))!
        let lateOnThird = ist.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 23, minute: 59))!
        let pastMidnight = ist.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 0, minute: 1))!
        XCTAssertEqual(Streak.status(dates: [spoken], now: lateOnThird, calendar: ist).current, 1)
        XCTAssertEqual(Streak.status(dates: [spoken], now: pastMidnight, calendar: ist).kind, .returning)
    }

    // MARK: - Every surface agrees

    /// The share card used its own copy of the rule. It reads `Streak` now.
    func testShareCardAgreesWithStreak() {
        let today = Date()
        let cal = Calendar.current
        let dates = [0, 1, 3, 4].map { cal.date(byAdding: .day, value: -$0, to: today)! }
        let facts = dates.map { Shareables.Fact(date: $0, text: "", mood: 0, people: []) }
        XCTAssertEqual(Shareables.streak(facts), Streak.current(dates: dates))
        XCTAssertEqual(Shareables.streak(facts), 4)
    }
}
