//
//  DailyQuestionTests.swift
//  solynTests
//

import CoreData
import XCTest
@testable import solyn

/// The question above the mic has three ways to go wrong that matter:
/// changing during the day, breaking the research pilot's neutral days, and
/// asking after a name the user never said — or said on a bad day, or then
/// deleted. These pin all three on the pure selection, with fixed calendars
/// so the day boundaries are the ones under test, not the runner's.
final class DailyQuestionTests: XCTestCase {

    // MARK: Fixtures

    private func calendar(_ tz: String = "Asia/Kolkata") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0,
                      in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func source(_ date: Date, _ text: String, mood: Mood = .none,
                        suggested: Mood = .none, id: UUID = UUID()) -> QuestionSource {
        QuestionSource(id: id, date: date, text: text, mood: mood, suggestedMood: suggested)
    }

    /// A tagger that proposes fixed names, so the tests decide what the
    /// engine "found" and the selection has to prove it from the words.
    private func tagger(people: [String] = [], places: [String] = [],
                        sentiment: Double = 0.2) -> (String) -> DailyQuestions.Reading {
        { _ in DailyQuestions.Reading(people: people, places: places, sentiment: sentiment) }
    }

    private let none: (String) -> DailyQuestions.Reading = { _ in DailyQuestions.Reading() }

    /// The first grounding day on or after `start`.
    private func groundingDay(from start: Date, in cal: Calendar) -> Date {
        var d = start
        while !DailyQuestions.isGroundingDay(d, calendar: cal) {
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return d
    }

    // MARK: - The set

    func testTheOriginalQuestionIsKeptAndIsTheFallback() {
        XCTAssertEqual(DailyQuestions.everyday.first, "How was your day, really?")
        XCTAssertEqual(DailyQuestions.fallback.text, "How was your day, really?")
        XCTAssertEqual(DailyQuestions.question(in: [], turn: 3).text, "How was your day, really?")
    }

    func testTheSetIsLargeAndHasNoRepeats() {
        let all = DailyQuestions.everyday
        XCTAssertGreaterThanOrEqual(all.count, 20)
        XCTAssertLessThanOrEqual(all.count, 30)
        XCTAssertEqual(Set(all).count, all.count)
    }

    // MARK: - Same all day, different tomorrow

    func testSameQuestionAllDayInTheLocalTimeZone() {
        let cal = calendar()
        let morning = DailyQuestions.lineup(on: date(2026, 10, 13, 0, 1, in: cal), entries: [],
                                            pilotEnabled: false, calendar: cal, read: none)
        let night = DailyQuestions.lineup(on: date(2026, 10, 13, 23, 59, in: cal), entries: [],
                                          pilotEnabled: false, calendar: cal, read: none)
        XCTAssertEqual(morning.first, night.first)

        let tomorrow = DailyQuestions.lineup(on: date(2026, 10, 14, 0, 1, in: cal), entries: [],
                                             pilotEnabled: false, calendar: cal, read: none)
        XCTAssertNotEqual(morning.first, tomorrow.first)
    }

    func testTheDayIsTheUsersLocalDay() {
        // 20:00 UTC on the 13th is already the 14th in Kolkata and still the
        // 13th in New York.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 20))!
        let kolkata = calendar("Asia/Kolkata"), newYork = calendar("America/New_York")
        XCTAssertEqual(DailyQuestions.dayNumber(of: instant, calendar: kolkata),
                       DailyQuestions.dayNumber(of: date(2026, 10, 14, in: kolkata), calendar: kolkata))
        XCTAssertEqual(DailyQuestions.dayNumber(of: instant, calendar: newYork),
                       DailyQuestions.dayNumber(of: date(2026, 10, 13, in: newYork), calendar: newYork))
    }

    func testEveryQuestionComesUpOverAFullCycle() {
        let cal = calendar()
        let start = date(2026, 1, 1, in: cal)
        let n = DailyQuestions.everyday.count
        let seen = Set((0..<n).map { i in
            DailyQuestions.lineup(on: cal.date(byAdding: .day, value: i, to: start)!, entries: [],
                                  pilotEnabled: false, calendar: cal, read: none).first!.text
        })
        XCTAssertEqual(seen.count, n)
    }

    func testDifferentQuestionStepsThroughAndWraps() {
        let cal = calendar()
        let lineup = DailyQuestions.lineup(on: date(2026, 10, 13, in: cal), entries: [],
                                           pilotEnabled: false, calendar: cal, read: none)
        XCTAssertEqual(DailyQuestions.question(in: lineup, turn: 0), lineup[0])
        XCTAssertEqual(DailyQuestions.question(in: lineup, turn: 1), lineup[1])
        XCTAssertEqual(DailyQuestions.question(in: lineup, turn: lineup.count), lineup[0])
        XCTAssertEqual(Set(lineup.map(\.text)).count, lineup.count)
    }

    func testAChangedQuestionSurvivesARelaunchButNotMidnight() {
        let cal = calendar()
        let today = date(2026, 10, 13, 9, in: cal)
        let stored = DailyQuestions.stored(turn: 2, on: today, calendar: cal)
        XCTAssertEqual(DailyQuestions.turn(from: stored, on: date(2026, 10, 13, 22, in: cal), calendar: cal), 2)
        XCTAssertEqual(DailyQuestions.turn(from: stored, on: date(2026, 10, 14, 0, 5, in: cal), calendar: cal), 0)
        XCTAssertEqual(DailyQuestions.turn(from: "", on: today, calendar: cal), 0)
        XCTAssertEqual(DailyQuestions.turn(from: "garbage", on: today, calendar: cal), 0)
    }

    // MARK: - Research pilot

    /// The rule `TodayView.orderedPrompts` applied before this change, kept
    /// here verbatim so any drift in the new code shows up as a failure.
    private func legacyPilotLead(on date: Date, pilot: Bool, calendar: Calendar) -> EntryPrompt? {
        guard pilot,
              let day = calendar.ordinality(of: .day, in: .year, for: date),
              day % 3 == 0
        else { return nil }
        return EntryPrompt.neutralPrompts[(day / 3) % EntryPrompt.neutralPrompts.count]
    }

    func testPilotNeutralDaysMatchTheOriginalRuleAllYear() {
        let cal = calendar()
        for year in [2026, 2028] {    // and a leap year
            let start = date(year, 1, 1, in: cal)
            for offset in 0..<366 {
                let day = cal.date(byAdding: .day, value: offset, to: start)!
                for pilot in [true, false] {
                    XCTAssertEqual(DailyQuestions.pilotNeutral(on: day, pilotEnabled: pilot, calendar: cal),
                                   legacyPilotLead(on: day, pilot: pilot, calendar: cal),
                                   "day \(offset) of \(year), pilot \(pilot)")
                }
            }
        }
    }

    func testEveryThirdDayOfYearLeadsWithTheNeutralPromptForPilots() {
        let cal = calendar()
        let jan3 = date(2026, 1, 3, in: cal)      // day 3
        let jan4 = date(2026, 1, 4, in: cal)      // day 4
        let jan6 = date(2026, 1, 6, in: cal)      // day 6

        let lead3 = DailyQuestions.lineup(on: jan3, entries: [], pilotEnabled: true, calendar: cal, read: none)[0]
        XCTAssertEqual(lead3.kind, .neutral)
        XCTAssertEqual(lead3.text, EntryPrompt.neutralPrompts[1].title)     // (3/3) % 2
        XCTAssertEqual(lead3.detail, EntryPrompt.neutralPrompts[1].detail)

        let lead6 = DailyQuestions.lineup(on: jan6, entries: [], pilotEnabled: true, calendar: cal, read: none)[0]
        XCTAssertEqual(lead6.text, EntryPrompt.neutralPrompts[0].title)     // (6/3) % 2

        XCTAssertEqual(DailyQuestions.lineup(on: jan4, entries: [], pilotEnabled: true,
                                             calendar: cal, read: none)[0].kind, .everyday)
        XCTAssertEqual(DailyQuestions.lineup(on: jan3, entries: [], pilotEnabled: false,
                                             calendar: cal, read: none)[0].kind, .everyday)
    }

    func testANeutralDayIsNeverGrounded() {
        let cal = calendar()
        // A day that is both a pilot neutral day and a grounding day.
        var day = date(2026, 1, 3, in: cal)
        while !(DailyQuestions.isGroundingDay(day, calendar: cal)
                && DailyQuestions.pilotNeutral(on: day, pilotEnabled: true, calendar: cal) != nil) {
            day = cal.date(byAdding: .day, value: 3, to: day)!
        }
        let yesterday = cal.date(byAdding: .day, value: -1, to: day)!
        let entries = [source(yesterday, "Had lunch with Priya at the new place near work.")]
        let lineup = DailyQuestions.lineup(on: day, entries: entries, pilotEnabled: true,
                                           calendar: cal, read: tagger(people: ["Priya"]))
        XCTAssertEqual(lineup[0].kind, .neutral)
        XCTAssertFalse(lineup.contains { if case .person = $0.kind { return true } else { return false } })
    }

    // MARK: - How often

    func testAtMostTwoGroundingDaysInAnySevenAndNeverTwoInARow() {
        let cal = calendar()
        let start = date(2026, 1, 1, in: cal)
        let flags = (0..<120).map {
            DailyQuestions.isGroundingDay(cal.date(byAdding: .day, value: $0, to: start)!, calendar: cal)
        }
        for i in 0...(flags.count - 7) {
            XCTAssertLessThanOrEqual(flags[i..<(i + 7)].filter { $0 }.count, 2)
        }
        for i in 1..<flags.count {
            XCTAssertFalse(flags[i] && flags[i - 1])
        }
    }

    func testGroundingLeadsOnlyOnAGroundingDay() {
        let cal = calendar()
        let gday = groundingDay(from: date(2026, 10, 1, in: cal), in: cal)
        let plain = cal.date(byAdding: .day, value: 1, to: gday)!
        func entries(before day: Date) -> [QuestionSource] {
            [source(cal.date(byAdding: .day, value: -2, to: day)!, "Had lunch with Priya near the station.")]
        }
        let grounded = DailyQuestions.lineup(on: gday, entries: entries(before: gday), pilotEnabled: false,
                                             calendar: cal, read: tagger(people: ["Priya"]))
        XCTAssertEqual(grounded[0].kind, .person("Priya"))
        XCTAssertEqual(grounded[0].text, "How are things with Priya?")
        XCTAssertEqual(grounded[0].lead, "You mentioned Priya a few days ago.")
        XCTAssertEqual(grounded.count, DailyQuestions.everyday.count + 1)

        let notToday = DailyQuestions.lineup(on: plain, entries: entries(before: plain), pilotEnabled: false,
                                             calendar: cal, read: tagger(people: ["Priya"]))
        XCTAssertEqual(notToday[0].kind, .everyday)
    }

    // MARK: - The window

    func testOnlyTheLastFourteenDaysAndNeverToday() {
        let cal = calendar()
        let now = date(2026, 10, 20, 10, in: cal)
        let read = tagger(people: ["Priya"])
        let text = "Coffee with Priya before work."

        func found(_ entryDate: Date) -> Bool {
            !DailyQuestions.subjects(in: [source(entryDate, text)], now: now, calendar: cal, read: read).isEmpty
        }
        XCTAssertFalse(found(date(2026, 10, 20, 8, in: cal)), "today's own entry")
        XCTAssertTrue(found(date(2026, 10, 19, 23, 50, in: cal)), "yesterday, late")
        XCTAssertTrue(found(date(2026, 10, 6, 0, 10, in: cal)), "fourteen days back")
        XCTAssertFalse(found(date(2026, 10, 5, 23, 50, in: cal)), "fifteen days back")
    }

    func testTheLeadSaysWhenInLocalDays() {
        let cal = calendar()
        let now = date(2026, 10, 20, 0, 30, in: cal)
        func lead(_ d: Date) -> String? {
            let subject = DailyQuestions.Subject(name: "Priya", kind: .person, entryID: UUID(), date: d)
            return DailyQuestions.question(about: subject, now: now, calendar: cal).lead
        }
        XCTAssertEqual(lead(date(2026, 10, 19, 23, 50, in: cal)), "You mentioned Priya yesterday.")
        XCTAssertEqual(lead(date(2026, 10, 15, in: cal)), "You mentioned Priya a few days ago.")
        XCTAssertEqual(lead(date(2026, 10, 13, in: cal)), "You mentioned Priya a week ago.")
        XCTAssertEqual(lead(date(2026, 10, 8, in: cal)), "You mentioned Priya recently.")
    }

    // MARK: - Names: only as written

    func testTheTaggerCanProposeButNeverInvent() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        let entry = source(date(2026, 10, 18, in: cal), "Long walk by the river after dinner.")
        XCTAssertTrue(DailyQuestions.subjects(in: [entry], now: now, calendar: cal,
                                              read: tagger(people: ["Priya"])).isEmpty)
    }

    func testNoWillFromWill() {
        XCTAssertNil(DailyQuestions.writtenName("Will", in: "I will call the plumber tomorrow."))
        XCTAssertNil(DailyQuestions.writtenName("Will", in: "Will it rain? I will take an umbrella."))
        XCTAssertNil(DailyQuestions.writtenName("Will", in: "Will you come over? Probably not."))
        XCTAssertEqual(DailyQuestions.writtenName("Will", in: "Had dinner with Will and the kids."), "Will")
    }

    func testNoSamFromSamsung() {
        XCTAssertNil(DailyQuestions.writtenName("Sam", in: "My new Samsung phone arrived."))
        XCTAssertEqual(DailyQuestions.writtenName("Sam", in: "Sam fixed my Samsung phone."), "Sam")
    }

    func testLowercaseIsNotAName() {
        XCTAssertNil(DailyQuestions.writtenName("Priya", in: "talked to priya for a bit"))
        XCTAssertNil(DailyQuestions.writtenName("Mark", in: "I made a mark on the wall. Mark that down."))
    }

    func testANameAlsoUsedAsAWordHereNeedsAMidSentenceUse() {
        // "Hunter" is on the word list; "Rose" too.
        XCTAssertNil(DailyQuestions.writtenName("Rose", in: "Rose early today. The sun rose at six."))
        XCTAssertEqual(DailyQuestions.writtenName("Rose", in: "Went to the market with Rose."), "Rose")
    }

    func testWeekdaysMonthsAndIAreNeverNames() {
        XCTAssertNil(DailyQuestions.writtenName("Monday", in: "Back to work on Monday."))
        XCTAssertNil(DailyQuestions.writtenName("May", in: "We go in May."))
        XCTAssertNil(DailyQuestions.writtenName("I", in: "I went out."))
    }

    func testTheNameIsQuotedAsWritten() {
        XCTAssertEqual(DailyQuestions.writtenName("josé", in: "Lunch with José today."), "José")
        XCTAssertEqual(DailyQuestions.writtenName("New York", in: "Flew back from New York."), "New York")
    }

    // MARK: - Gentle only

    func testANegativeMoodRulesTheEntryOut() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        let text = "Had lunch with Priya near the station."
        let read = tagger(people: ["Priya"])
        for mood in [Mood.sad, .anxious, .angry] {
            XCTAssertTrue(DailyQuestions.subjects(in: [source(date(2026, 10, 18, in: cal), text, mood: mood)],
                                                  now: now, calendar: cal, read: read).isEmpty, "\(mood)")
            XCTAssertTrue(DailyQuestions.subjects(in: [source(date(2026, 10, 18, in: cal), text, suggested: mood)],
                                                  now: now, calendar: cal, read: read).isEmpty, "suggested \(mood)")
        }
        XCTAssertFalse(DailyQuestions.subjects(in: [source(date(2026, 10, 18, in: cal), text, mood: .happy)],
                                               now: now, calendar: cal, read: read).isEmpty)
    }

    func testANegativeLeanRulesTheEntryOut() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        let entry = source(date(2026, 10, 18, in: cal), "Had lunch with Priya near the station.")
        XCTAssertTrue(DailyQuestions.subjects(in: [entry], now: now, calendar: cal,
                                              read: tagger(people: ["Priya"], sentiment: -0.5)).isEmpty)
    }

    func testSensitiveWordsRuleTheEntryOut() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        for text in ["Visited Priya in the hospital.",
                     "Priya and I had an argument.",
                     "Went to the funeral with Priya.",
                     "I miss Priya so much."] {
            XCTAssertTrue(DailyQuestions.subjects(in: [source(date(2026, 10, 18, in: cal), text)], now: now,
                                                  calendar: cal, read: tagger(people: ["Priya"])).isEmpty, text)
        }
    }

    // MARK: - No pronouns

    func testGroundedQuestionsHaveNoPronouns() {
        let pronouns: Set<String> = ["he", "she", "him", "her", "his", "hers", "they", "them", "their", "theirs"]
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        for kind in [DailyQuestions.Subject.Kind.person, .place] {
            for daysBack in 1...14 {
                let subject = DailyQuestions.Subject(name: "Priya", kind: kind, entryID: UUID(),
                                                     date: cal.date(byAdding: .day, value: -daysBack, to: now)!)
                let q = DailyQuestions.question(about: subject, now: now, calendar: cal)
                let words = q.spoken.lowercased()
                    .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                XCTAssertTrue(pronouns.isDisjoint(with: words), q.spoken)
                XCTAssertTrue(q.spoken.contains("Priya"))
            }
        }
    }

    func testAPlaceIsAskedAfterAsThere() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        let found = DailyQuestions.subjects(in: [source(date(2026, 10, 12, in: cal), "Spent the afternoon in Lisbon.")],
                                            now: now, calendar: cal, read: tagger(places: ["Lisbon"]))
        XCTAssertEqual(found.map(\.kind), [.place])
        let q = DailyQuestions.question(about: found[0], now: now, calendar: cal)
        XCTAssertEqual(q.text, "How are things there?")
        XCTAssertEqual(q.lead, "You mentioned Lisbon recently.")
    }

    func testNewestEntryFirstAndEachNameOnce() {
        let cal = calendar()
        let now = date(2026, 10, 20, in: cal)
        let entries = [
            source(date(2026, 10, 10, in: cal), "Dinner with Priya and Arjun."),
            source(date(2026, 10, 18, in: cal), "Ran into Arjun at the station."),
        ]
        let found = DailyQuestions.subjects(in: entries, now: now, calendar: cal,
                                            read: tagger(people: ["Priya", "Arjun"]))
        XCTAssertEqual(found.map(\.name), ["Arjun", "Priya"])
    }

    func testTheTaggersOrderDoesNotPickTheName() {
        // The engine hands names over from a Set, so their order changes
        // between launches; the question must not.
        let cal = calendar()
        let gday = groundingDay(from: date(2026, 10, 1, in: cal), in: cal)
        let entries = [source(cal.date(byAdding: .day, value: -1, to: gday)!,
                              "Dinner with Ravi and Priya and Anand tonight.")]
        func lineup(_ people: [String], _ places: [String]) -> [DailyQuestion] {
            DailyQuestions.lineup(on: gday, entries: entries, pilotEnabled: false, calendar: cal,
                                  read: tagger(people: people, places: places))
        }
        let one = lineup(["Ravi", "Priya"], ["Anand"])
        XCTAssertEqual(one, lineup(["Priya", "Ravi"], ["Anand"]))
        XCTAssertEqual(DailyQuestions.subjects(in: entries, now: gday, calendar: cal,
                                               read: tagger(people: ["Priya", "Ravi"], places: ["Anand"]))
                        .map(\.name), ["Ravi", "Priya", "Anand"])
        for weeks in 0..<3 {
            let day = cal.date(byAdding: .day, value: 7 * weeks, to: gday)!
            let moved = [source(cal.date(byAdding: .day, value: -1, to: day)!,
                                "Dinner with Ravi and Priya and Anand tonight.")]
            let a = DailyQuestions.lineup(on: day, entries: moved, pilotEnabled: false, calendar: cal,
                                          read: tagger(people: ["Ravi", "Priya", "Anand"]))
            let b = DailyQuestions.lineup(on: day, entries: moved, pilotEnabled: false, calendar: cal,
                                          read: tagger(people: ["Anand", "Priya", "Ravi"]))
            XCTAssertEqual(a[0], b[0])
        }
    }

    // MARK: - Deleted entries

    func testDeletedEntriesAreNeverSnapshotted() throws {
        let container = PersistenceController(inMemory: true).container
        let ctx = container.viewContext

        func make(_ text: String) -> DiaryEntry {
            let e = DiaryEntry(context: ctx)
            e.id = UUID()
            e.date = Date().addingTimeInterval(-86_400 * 2)
            e.text = text
            return e
        }
        let kept = make("Had lunch with Arjun near the station.")
        let gone = make("Had lunch with Priya near the station.")
        let goneLater = make("Coffee with Meera before work.")
        try ctx.save()
        let all = [kept, gone, goneLater]

        ctx.delete(gone)                        // pending delete, still in arrays
        XCTAssertEqual(Set(QuestionSource.snapshots(of: all).map(\.id)), [kept.id!, goneLater.id!])
        ctx.delete(goneLater)
        try ctx.save()                          // deleted and detached
        let snaps = QuestionSource.snapshots(of: all)
        XCTAssertEqual(snaps.map(\.id), [kept.id])

        let found = DailyQuestions.subjects(in: snaps, now: Date(), read: tagger(people: ["Arjun", "Priya", "Meera"]))
        XCTAssertEqual(found.map(\.name), ["Arjun"])
    }

    func testSnapshotsCarryTheSuggestedMood() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = DiaryEntry(context: ctx)
        e.id = UUID(); e.date = Date(); e.text = "Something happened."
        e.mood = "sad"; e.suggestedMood = "sad"
        let snap = try XCTUnwrap(QuestionSource.snapshots(of: [e]).first)
        XCTAssertEqual(snap.mood, .sad)
        XCTAssertEqual(snap.suggestedMood, .sad)
    }
}
