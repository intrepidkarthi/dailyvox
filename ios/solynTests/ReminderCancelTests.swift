//
//  ReminderCancelTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// "Turn reminders off" has to reach every reminder that was armed. The bug
/// this guards: `cancelReminder` removed one bare identifier while the week
/// was scheduled under seven numbered ones, so switching reminders off left up
/// to a week of them in place.
///
/// Like `ReminderSkipTests`, these assert on the pure plan rather than the
/// notification center's pending list, which is empty on a runner without
/// notification authorization whether or not the code is right.
final class ReminderCancelTests: XCTestCase {

    private let manager = ReminderManager.shared
    private let cal = Calendar.current

    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 9))!
    }

    func testEveryPlannedReminderIsCancellable() {
        let planned = manager.plannedReminders(spokenDays: [], now: now)
        let cancellable = Set(manager.cancellableIdentifiers)
        XCTAssertFalse(planned.isEmpty)
        for reminder in planned {
            XCTAssertTrue(cancellable.contains(reminder.identifier),
                          "\(reminder.identifier) would survive turning reminders off")
        }
    }

    func testPlannedIdentifiersAreUnique() {
        // Two requests under one identifier silently replace each other.
        let ids = manager.plannedReminders(spokenDays: [], now: now).map(\.identifier)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testExactlyOneWelcomeBackNote() {
        let planned = manager.plannedReminders(spokenDays: [], now: now)
        let daily = manager.plannedFireDates(spokenDays: [], now: now)
        XCTAssertEqual(planned.count, daily.count + 1,
                       "the week, plus one welcome-back note — never a series")
    }

    func testWelcomeBackLandsPastTheWeekAtTheReminderTime() throws {
        let welcome = try XCTUnwrap(manager.welcomeBackDate(now: now))
        let lastDaily = try XCTUnwrap(manager.plannedFireDates(spokenDays: [], now: now).max())

        XCTAssertGreaterThan(welcome, lastDaily, "it is for after the week has run out")
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: welcome)).day
        XCTAssertEqual(days, 10)

        let time = cal.dateComponents([.hour, .minute], from: welcome)
        XCTAssertEqual(time.hour, manager.reminderHour)
        XCTAssertEqual(time.minute, manager.reminderMinute)
    }

    func testWelcomeBackMovesWithEachReArm() throws {
        // Re-armed on every foreground and save, so someone who keeps coming
        // back never reaches it.
        let later = cal.date(byAdding: .day, value: 3, to: now)!
        let first = try XCTUnwrap(manager.welcomeBackDate(now: now))
        let second = try XCTUnwrap(manager.welcomeBackDate(now: later))
        XCTAssertEqual(cal.dateComponents([.day], from: first, to: second).day, 3)
    }

    func testWelcomeBackIsArmedEvenWhenTheWholeWeekIsSpoken() {
        // Spoken every day this week still means the app goes quiet after it.
        let allWeek = Set((0..<8).map { cal.startOfDay(for: cal.date(byAdding: .day, value: $0, to: now)!) })
        let planned = manager.plannedReminders(spokenDays: allWeek, now: now)
        XCTAssertEqual(planned.count, 1)
    }

    func testWelcomeBackCarriesNoStreakGuilt() throws {
        let note = try XCTUnwrap(manager.plannedReminders(spokenDays: [], now: now).last)
        let words = (note.title + " " + note.body).lowercased()
        for guilt in ["streak", "missed", "miss you", "behind", "don't break"] {
            XCTAssertFalse(words.contains(guilt), "welcome-back copy says \"\(guilt)\"")
        }
    }
}

/// The "for tomorrow" line may only name what the entry itself says.
final class EntryReflectionAnchorTests: XCTestCase {

    func testANameTheEntryContainsIsKept() {
        let text = "Had lunch with Sarah and talked about the move."
        XCTAssertEqual(EntryReflection.groundedAnchor(people: ["Sarah"], places: [], in: text), "Sarah")
    }

    func testANameTheEntryDoesNotContainIsDropped() {
        let text = "Quiet day. Mostly reading."
        XCTAssertNil(EntryReflection.groundedAnchor(people: ["Sarah"], places: ["Bengaluru"], in: text))
    }

    func testWholeWordsOnly() {
        let text = "Made samosas for everyone."
        XCTAssertNil(EntryReflection.groundedAnchor(people: ["Sam"], places: [], in: text))
    }

    func testPeopleBeforePlaces() {
        let text = "Back in Bengaluru, finally saw Adyah."
        XCTAssertEqual(EntryReflection.groundedAnchor(people: ["Adyah"], places: ["Bengaluru"], in: text),
                       "Adyah")
    }

    func testFallsBackToAPlace() {
        let text = "The walk around Cubbon Park helped."
        XCTAssertEqual(EntryReflection.groundedAnchor(people: [], places: ["Cubbon Park"], in: text),
                       "Cubbon Park")
    }

    func testFirstMentionedWinsRegardlessOfTaggerOrder() {
        let text = "Called Meera, then Arjun called back."
        XCTAssertEqual(EntryReflection.groundedAnchor(people: ["Arjun", "Meera"], places: [], in: text), "Meera")
        XCTAssertEqual(EntryReflection.groundedAnchor(people: ["Meera", "Arjun"], places: [], in: text), "Meera")
    }

    func testJunkTokensAreIgnored() {
        let text = "I said J. and 42 out loud."
        XCTAssertNil(EntryReflection.groundedAnchor(people: ["J", "42", "  "], places: [], in: text))
    }

    func testNothingToSayIsNoReflection() {
        XCTAssertNil(EntryReflection.make(entryText: "   \n ", entryID: UUID(),
                                          suggestedResponse: "Something.", people: [], places: []))
    }
}
