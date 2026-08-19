//
//  ReminderSkipTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The Settings card promises "skips once you've spoken". A repeating calendar
/// trigger cannot do that — the system fires it whether or not you journalled —
/// so reminders are armed a week at a time and re-armed on save.
///
/// These assert on `plannedFireDates`, the pure decision, NOT on
/// `UNUserNotificationCenter`'s pending list. The first version of this file
/// did the latter and three tests failed in CI for a reason that had nothing to
/// do with the logic: the runner has no notification authorization, so nothing
/// was ever scheduled. Worse than the failure is the version that passes —
/// "the day was correctly skipped" and "nothing was scheduled at all" produce
/// an identical empty list, and that is exactly the bug this feature is about.
final class ReminderSkipTests: XCTestCase {

    private let manager = ReminderManager.shared
    private let cal = Calendar.current

    /// A fixed morning, so "is the fire time still ahead of now" is decided by
    /// the test rather than by when it happens to run.
    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 9))!
    }

    private func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: now)!)
    }

    func testArmsAWeekWhenNothingHasBeenSpoken() {
        let dates = manager.plannedFireDates(spokenDays: [], now: now)
        XCTAssertEqual(dates.count, 7,
            "a week ahead, so someone who does not open the app is still reminded")
        XCTAssertEqual(Set(dates.map { cal.startOfDay(for: $0) }).count, 7,
                       "one per day, never two on the same evening")
    }

    func testASpokenDayGetsNoReminder() {
        let target = day(3)
        let dates = manager.plannedFireDates(spokenDays: [target], now: now)
        let days = Set(dates.map { cal.startOfDay(for: $0) })

        XCTAssertFalse(days.contains(target), "the day already journalled is skipped")
        XCTAssertEqual(dates.count, 6, "and only that day")
    }

    func testTonightIsDroppedOnceSpoken() {
        // The case that matters most: you spoke this evening, so tonight's
        // reminder must not arrive a few hours later.
        let withoutSpeaking = manager.plannedFireDates(spokenDays: [], now: now)
        let afterSpeaking = manager.plannedFireDates(spokenDays: [day(0)], now: now)

        XCTAssertTrue(withoutSpeaking.map { cal.startOfDay(for: $0) }.contains(day(0)))
        XCTAssertFalse(afterSpeaking.map { cal.startOfDay(for: $0) }.contains(day(0)))
    }

    func testEveryDaySpokenPlansNothing() {
        let all = Set((0..<8).map { day($0) })
        XCTAssertTrue(manager.plannedFireDates(spokenDays: all, now: now).isEmpty)
    }

    func testAFireTimeAlreadyPastTodayIsNotScheduled() {
        // Reminder at 21:00 and it is already 23:00 — today's slot is gone, so
        // the plan starts tomorrow rather than scheduling a date in the past.
        let late = cal.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 23))!
        let dates = manager.plannedFireDates(spokenDays: [], now: late)

        XCTAssertFalse(dates.contains { $0 < late }, "never a fire date in the past")
        XCTAssertEqual(dates.count, 6, "today's slot has passed; six remain")
    }

    func testPlanNeverExceedsTheSystemCeiling() {
        // Re-armed on every foreground and every save. iOS caps pending
        // requests at 64; a plan that grew would silently drop reminders.
        XCTAssertLessThanOrEqual(manager.plannedFireDates(spokenDays: [], now: now).count, 7)
    }
}
