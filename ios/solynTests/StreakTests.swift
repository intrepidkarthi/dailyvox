//
//  StreakTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// A streak that counts wrong does not crash — it flatters. The bug this pins
/// was a Record tab reading "5-day streak" for a journal last written in March,
/// while Insights read 0 from a different copy of the same rule.
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

    /// Two days ago does not — that run has broken.
    func testTwoDaysAgoHasBroken() {
        XCTAssertEqual(Streak.current(days: days([2, 3, 4]), now: now, calendar: cal), 0)
    }

    func testGapEndsTheCount() {
        // today, yesterday, then a missing day, then more.
        XCTAssertEqual(Streak.current(days: days([0, 1, 3, 4, 5]), now: now, calendar: cal), 2)
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

    // MARK: - Longest

    func testLongestFindsAPastRun() {
        XCTAssertEqual(Streak.longest(days: days([0, 5, 6, 7, 8, 20]), calendar: cal), 4)
    }

    func testLongestOfNothingIsZero() {
        XCTAssertEqual(Streak.longest(days: [], calendar: cal), 0)
    }

    /// The two must agree when the run reaches the present — a current streak is
    /// by definition also a run, so it can never exceed the longest.
    func testCurrentNeverExceedsLongest() {
        let d = days([0, 1, 2, 9, 10])
        XCTAssertLessThanOrEqual(Streak.current(days: d, now: now, calendar: cal),
                                 Streak.longest(days: d, calendar: cal))
    }
}
