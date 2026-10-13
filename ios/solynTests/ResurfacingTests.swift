//
//  ResurfacingTests.swift
//  solynTests
//

import CoreData
import XCTest
@testable import solyn

/// Bringing the past back has two ways to go wrong that matter: quoting words
/// the entry never said, and showing an entry from the wrong day (or one that
/// was deleted). These pin both down on the pure selection, with fixed
/// calendars and time zones so the day boundaries are the ones under test,
/// not the runner's.
final class ResurfacingTests: XCTestCase {

    // MARK: Fixtures

    private func calendar(_ tz: String = "Asia/Kolkata", firstWeekday: Int = 2) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0,
                      in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private let said = "Walked to the lake with Adyah after work. The water was cold and very still."

    private func entry(_ date: Date, _ text: String? = nil, id: UUID = UUID()) -> PastEntry {
        PastEntry(id: id, date: date, text: text ?? said)
    }

    // MARK: - Excerpt

    func testEmptyAndShortEntriesHaveNoExcerpt() {
        XCTAssertNil(Resurfacing.excerpt(from: ""))
        XCTAssertNil(Resurfacing.excerpt(from: "  \n\t "))
        XCTAssertNil(Resurfacing.excerpt(from: "Test"))
        XCTAssertNil(Resurfacing.excerpt(from: "ok so yeah"), "three words is not a thought worth bringing back")
        XCTAssertNotNil(Resurfacing.excerpt(from: "ok so yeah fine"))
    }

    func testShortTextComesBackWhole() {
        XCTAssertEqual(Resurfacing.excerpt(from: "  \(said)\n"), said)
    }

    func testTrimsAtASentenceBoundary() {
        let text = "I finally called Mum today. We talked for an hour about nothing. "
            + String(repeating: "Then the evening went on and on and on ", count: 4) + "until late."
        let ex = Resurfacing.excerpt(from: text, limit: 80)
        XCTAssertEqual(ex, "I finally called Mum today. We talked for an hour about nothing.")
    }

    func testALongFirstSentenceIsCutAtAWordWithAnEllipsis() throws {
        let text = "Today I walked all the way along the river path past the old mill and the bridge and kept going until the light was gone"
        let ex = try XCTUnwrap(Resurfacing.excerpt(from: text, limit: 40))
        XCTAssertTrue(ex.hasSuffix("\u{2026}"))
        XCTAssertLessThanOrEqual(ex.count, 40)
        let body = String(ex.dropLast())
        XCTAssertTrue(text.hasPrefix(body), "verbatim from the start")
        XCTAssertFalse(body.hasSuffix(" "))
        // Ends on a whole word.
        let next = text[text.index(text.startIndex, offsetBy: body.count)]
        XCTAssertEqual(next, " ")
    }

    func testExcerptIsAlwaysVerbatim() throws {
        let texts = [
            said,
            "Big day. Got the offer from the studio, and I said yes before they finished the sentence. Mum cried.",
            "no punctuation at all just talking and talking about the week and how the rain never stopped once"
        ]
        for text in texts {
            for limit in [30, 60, 90, 160] {
                guard let ex = Resurfacing.excerpt(from: text, limit: limit) else { continue }
                let body = ex.hasSuffix("\u{2026}") ? String(ex.dropLast()) : ex
                XCTAssertTrue(text.contains(body), "\"\(body)\" is not in the entry")
                XCTAssertLessThanOrEqual(ex.count, limit)
            }
        }
    }

    func testEmojiAreNeverSplit() throws {
        let text = "Best day with the whole family 👨‍👩‍👧‍👦🎉 at the beach and everyone was laughing all afternoon long"
        for limit in 20...60 {
            guard let ex = Resurfacing.excerpt(from: text, limit: limit) else { continue }
            let body = ex.hasSuffix("\u{2026}") ? String(ex.dropLast()) : ex
            XCTAssertTrue(text.hasPrefix(body))
            // A split ZWJ sequence would leave a dangling joiner or a lone
            // member of the family.
            XCTAssertFalse(body.unicodeScalars.last.map { $0.value == 0x200D } ?? false)
            if body.contains("👨") { XCTAssertTrue(body.contains("👨‍👩‍👧‍👦"), "family emoji split at limit \(limit)") }
        }
    }

    func testRightToLeftTextIsQuotedVerbatim() throws {
        let hebrew = "היום הלכתי לים עם כל המשפחה. המים היו קרים מאוד אבל היה נפלא."
        XCTAssertEqual(Resurfacing.excerpt(from: hebrew), hebrew)
        let cut = try XCTUnwrap(Resurfacing.excerpt(from: hebrew, limit: 35))
        XCTAssertEqual(cut, "היום הלכתי לים עם כל המשפחה.")

        let arabic = "ذهبت اليوم إلى البحر مع عائلتي وكان الجو جميلا جدا والماء باردا قليلا"
        let ex = try XCTUnwrap(Resurfacing.excerpt(from: arabic, limit: 30))
        XCTAssertTrue(ex.hasSuffix("\u{2026}"))
        XCTAssertTrue(arabic.hasPrefix(String(ex.dropLast())))
    }

    // MARK: - A week ago

    func testExactlyAWeekAgo() throws {
        let cal = calendar()
        let now = date(2026, 10, 13, 9, in: cal)
        let target = entry(date(2026, 10, 6, 21, in: cal))
        let pick = try XCTUnwrap(Resurfacing.weekAgo(in: [target], now: now, calendar: cal))
        XCTAssertEqual(pick.entryID, target.id)
        XCTAssertEqual(pick.kind, .daysAgo(7))
        XCTAssertEqual(pick.excerpt, said)
    }

    func testFallsBackToSixThenEightDays() throws {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let six = entry(date(2026, 10, 7, in: cal))
        let eight = entry(date(2026, 10, 5, in: cal))
        XCTAssertEqual(Resurfacing.weekAgo(in: [eight, six], now: now, calendar: cal)?.kind, .daysAgo(6))
        XCTAssertEqual(Resurfacing.weekAgo(in: [eight], now: now, calendar: cal)?.kind, .daysAgo(8))
    }

    func testNothingOutsideTheWindow() {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let entries = [5, 9, 0, 14].map { entry(cal.date(byAdding: .day, value: -$0, to: now)!) }
        XCTAssertNil(Resurfacing.weekAgo(in: entries, now: now, calendar: cal))
        XCTAssertNil(Resurfacing.weekAgo(in: [], now: now, calendar: cal))
    }

    func testShortEntryOnTheDayIsSkipped() {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let short = entry(date(2026, 10, 6, in: cal), "Test test")
        let six = entry(date(2026, 10, 7, in: cal))
        let pick = Resurfacing.weekAgo(in: [short, six], now: now, calendar: cal)
        XCTAssertEqual(pick?.entryID, six.id, "a two-word entry is skipped, not quoted")
    }

    func testLocalDayBoundaries() {
        // 23:50 IST on the 6th is the 6th; 00:10 IST on the 7th is the 7th —
        // even though both are the same UTC day.
        let cal = calendar("Asia/Kolkata")
        let now = date(2026, 10, 13, 8, in: cal)
        let lateOnThe6th = entry(date(2026, 10, 6, 23, 50, in: cal))
        let earlyOnThe7th = entry(date(2026, 10, 7, 0, 10, in: cal))
        XCTAssertEqual(Resurfacing.weekAgo(in: [earlyOnThe7th], now: now, calendar: cal)?.kind, .daysAgo(6))
        XCTAssertEqual(Resurfacing.weekAgo(in: [lateOnThe6th, earlyOnThe7th], now: now, calendar: cal)?.entryID,
                       lateOnThe6th.id)
        // Seen from a calendar in another zone, the same instants fall on
        // other local days.
        let ny = calendar("America/New_York")
        let nyNow = ny.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!
        XCTAssertEqual(Resurfacing.weekAgo(in: [lateOnThe6th], now: nyNow, calendar: ny)?.kind, .daysAgo(7),
                       "23:50 IST on the 6th is 14:20 on the 6th in New York")
    }

    func testAcrossADaylightSavingChange() {
        // US clocks go back on 1 Nov 2026: the week is 7 local days, not
        // 168 hours.
        let cal = calendar("America/New_York")
        let now = date(2026, 11, 3, 0, 30, in: cal)
        let e = entry(date(2026, 10, 27, 0, 15, in: cal))
        XCTAssertEqual(Resurfacing.weekAgo(in: [e], now: now, calendar: cal)?.kind, .daysAgo(7))
    }

    func testSameDayTieIsDeterministic() {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let morning = entry(date(2026, 10, 6, 8, in: cal))
        let evening = entry(date(2026, 10, 6, 21, in: cal))
        XCTAssertEqual(Resurfacing.weekAgo(in: [morning, evening], now: now, calendar: cal)?.entryID, evening.id)
        XCTAssertEqual(Resurfacing.weekAgo(in: [evening, morning], now: now, calendar: cal)?.entryID, evening.id)
    }

    // MARK: - On this day

    func testAYearAndAMonthAgo() {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let lastMonth = entry(date(2026, 9, 13, in: cal))
        let lastYear = entry(date(2025, 10, 13, in: cal))
        let twoYears = entry(date(2024, 10, 13, in: cal))
        let twoMonths = entry(date(2026, 8, 13, in: cal))
        let today = entry(date(2026, 10, 13, 7, in: cal))
        let other = entry(date(2025, 10, 12, in: cal))

        let picks = Resurfacing.onThisDay(in: [twoYears, today, lastYear, twoMonths, lastMonth, other],
                                          now: now, calendar: cal)
        XCTAssertEqual(picks.map(\.kind), [.monthsAgo(1), .yearsAgo(1), .yearsAgo(2)], "nearest first")
        XCTAssertEqual(picks.map(\.entryID), [lastMonth.id, lastYear.id, twoYears.id])
    }

    func testMonthAgoAcrossTheYearEnd() {
        let cal = calendar()
        let now = date(2027, 1, 15, in: cal)
        let e = entry(date(2026, 12, 15, in: cal))
        XCTAssertEqual(Resurfacing.onThisDay(in: [e], now: now, calendar: cal).map(\.kind), [.monthsAgo(1)])
    }

    func testMonthEndIsNotClamped() {
        // 31 March has no "a month ago": February has no 31st, and clamping
        // to the 28th would bring the same entry back four days running.
        let cal = calendar()
        let feb28 = entry(date(2027, 2, 28, in: cal))
        for day in [29, 30, 31] {
            XCTAssertTrue(Resurfacing.onThisDay(in: [feb28], now: date(2027, 3, day, in: cal), calendar: cal).isEmpty,
                          "28 Feb shown on \(day) March")
        }
        XCTAssertEqual(Resurfacing.onThisDay(in: [feb28], now: date(2027, 3, 28, in: cal), calendar: cal).map(\.kind),
                       [.monthsAgo(1)])
        // And a 31st only comes back where there is one.
        let jan31 = entry(date(2027, 1, 31, in: cal))
        XCTAssertTrue(Resurfacing.onThisDay(in: [jan31], now: date(2027, 2, 28, in: cal), calendar: cal).isEmpty)
    }

    func testLeapDay() {
        let cal = calendar()
        let leap = entry(date(2024, 2, 29, in: cal))
        // A year without a 29th: it comes back on the 28th.
        XCTAssertEqual(Resurfacing.onThisDay(in: [leap], now: date(2027, 2, 28, in: cal), calendar: cal).map(\.kind),
                       [.yearsAgo(3)])
        XCTAssertTrue(Resurfacing.onThisDay(in: [leap], now: date(2027, 3, 1, in: cal), calendar: cal).isEmpty)
        // A leap year: on the day itself, and not the day before.
        XCTAssertTrue(Resurfacing.onThisDay(in: [leap], now: date(2028, 2, 28, in: cal), calendar: cal).isEmpty)
        XCTAssertEqual(Resurfacing.onThisDay(in: [leap], now: date(2028, 2, 29, in: cal), calendar: cal).map(\.kind),
                       [.yearsAgo(4)])
        // An ordinary 28th still comes back on the 28th, alongside.
        let feb28 = entry(date(2026, 2, 28, in: cal))
        XCTAssertEqual(Resurfacing.onThisDay(in: [leap, feb28], now: date(2027, 2, 28, in: cal), calendar: cal).map(\.kind),
                       [.yearsAgo(1), .yearsAgo(3)])
    }

    func testOnThisDaySkipsShortEntries() {
        let cal = calendar()
        let now = date(2026, 10, 13, in: cal)
        let short = entry(date(2025, 10, 13, in: cal), "hi")
        XCTAssertTrue(Resurfacing.onThisDay(in: [short], now: now, calendar: cal).isEmpty)
    }

    // MARK: - Deleted entries

    func testDeletedEntriesAreNeverSnapshotted() throws {
        let container = PersistenceController(inMemory: true).container
        let ctx = container.viewContext
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())!

        func make(_ text: String) -> DiaryEntry {
            let e = DiaryEntry(context: ctx)
            e.id = UUID(); e.date = weekAgo; e.createdAt = weekAgo; e.updatedAt = weekAgo
            e.text = text
            return e
        }
        let kept = make("I kept this one and it says enough.")
        let gone = make("Please never show this one to me again.")
        let goneLater = make("This one goes after it has been saved.")
        try ctx.save()

        ctx.delete(gone)                        // pending delete, still in arrays
        var snaps = PastEntry.snapshots(of: [kept, gone, goneLater])
        XCTAssertEqual(Set(snaps.map(\.id)), [kept.id!, goneLater.id!])

        ctx.delete(goneLater)
        try ctx.save()                          // deleted and detached
        snaps = PastEntry.snapshots(of: [kept, gone, goneLater])
        XCTAssertEqual(snaps.map(\.id), [kept.id!])
        XCTAssertEqual(Resurfacing.weekAgo(in: snaps, now: Date())?.entryID, kept.id)
    }

    // MARK: - Recap timing

    func testRecapIsDueSundayEveningAndMondayWhereWeeksStartMonday() throws {
        let cal = calendar(firstWeekday: 2)
        // 18 Oct 2026 is a Sunday.
        XCTAssertNil(Resurfacing.recapWeekIfDue(now: date(2026, 10, 18, 17, 59, in: cal), calendar: cal))
        let sunday = try XCTUnwrap(Resurfacing.recapWeekIfDue(now: date(2026, 10, 18, 18, in: cal), calendar: cal))
        XCTAssertEqual(sunday.start, date(2026, 10, 12, 0, in: cal))
        XCTAssertEqual(sunday.end, date(2026, 10, 19, 0, in: cal))
        let monday = try XCTUnwrap(Resurfacing.recapWeekIfDue(now: date(2026, 10, 19, 9, in: cal), calendar: cal))
        XCTAssertEqual(monday, sunday, "Monday still shows the week that just ended")
        XCTAssertNil(Resurfacing.recapWeekIfDue(now: date(2026, 10, 20, 9, in: cal), calendar: cal))
    }

    func testRecapFollowsTheLocaleWeekWhereWeeksStartSunday() throws {
        let cal = calendar("America/New_York", firstWeekday: 1)
        // Saturday 17 Oct evening closes a Sunday-first week.
        let sat = try XCTUnwrap(Resurfacing.recapWeekIfDue(now: date(2026, 10, 17, 19, in: cal), calendar: cal))
        XCTAssertEqual(sat.start, date(2026, 10, 11, 0, in: cal))
        XCTAssertEqual(Resurfacing.recapWeekIfDue(now: date(2026, 10, 18, 10, in: cal), calendar: cal), sat)
        XCTAssertNil(Resurfacing.recapWeekIfDue(now: date(2026, 10, 16, 19, in: cal), calendar: cal))
    }

    func testInsightsShowsTheLastFullWeekMidweek() throws {
        let cal = calendar(firstWeekday: 2)
        let wed = try XCTUnwrap(Resurfacing.latestRecapWeek(now: date(2026, 10, 14, in: cal), calendar: cal))
        XCTAssertEqual(wed.start, date(2026, 10, 5, 0, in: cal))
        let sunEve = try XCTUnwrap(Resurfacing.latestRecapWeek(now: date(2026, 10, 18, 20, in: cal), calendar: cal))
        XCTAssertEqual(sunEve.start, date(2026, 10, 12, 0, in: cal))
    }

    // MARK: - Recap content

    private func week(_ cal: Calendar) -> DateInterval {
        DateInterval(start: date(2026, 10, 12, 0, in: cal), end: date(2026, 10, 19, 0, in: cal))
    }

    private func tagger(people: [String] = [], places: [String] = [], topics: [String] = [])
        -> (String) -> Resurfacing.Candidates {
        { _ in Resurfacing.Candidates(people: people, places: places, topics: topics) }
    }

    func testCountsComeFromTheEntries() throws {
        let cal = calendar()
        let entries = [
            entry(date(2026, 10, 12, 8, in: cal), "Monday morning, slow start to the week."),
            entry(date(2026, 10, 12, 21, in: cal), "Monday night, a second thought about the day."),
            entry(date(2026, 10, 15, 21, in: cal), "Thursday was long but it ended well enough."),
            entry(date(2026, 10, 18, 23, 59, in: cal), "Sunday, last minute of the week, still awake."),
            entry(date(2026, 10, 19, 0, 0, in: cal), "Monday again, this one belongs to next week."),
            entry(date(2026, 10, 11, 23, 59, in: cal), "Sunday before, this one belongs to last week.")
        ]
        let recap = try XCTUnwrap(Resurfacing.recap(of: entries, week: week(cal), calendar: cal, candidates: tagger()))
        XCTAssertEqual(recap.entryCount, 4)
        XCTAssertEqual(recap.daysSpoken, 3)
        XCTAssertNil(recap.topMention)
        XCTAssertEqual(recap.line?.entryID, entries[3].id, "the latest line of the week")
    }

    func testAnEmptyWeekHasNoRecap() {
        let cal = calendar()
        let outside = entry(date(2026, 10, 1, in: cal))
        XCTAssertNil(Resurfacing.recap(of: [outside], week: week(cal), calendar: cal, candidates: tagger()))
    }

    func testAMentionMustReallyAppearTwice() throws {
        let cal = calendar()
        let once = [
            entry(date(2026, 10, 13, in: cal), "Lunch with Sarah near the office today."),
            entry(date(2026, 10, 14, in: cal), "Quiet day, mostly reading on the sofa.")
        ]
        // The tagger proposing her for every entry does not make it twice.
        let r1 = try XCTUnwrap(Resurfacing.recap(of: once, week: week(cal), calendar: cal,
                                                 candidates: tagger(people: ["Sarah", "Sarah"])))
        XCTAssertNil(r1.topMention)

        let twice = once + [entry(date(2026, 10, 15, in: cal), "Sarah called back about the trip.")]
        let r2 = try XCTUnwrap(Resurfacing.recap(of: twice, week: week(cal), calendar: cal,
                                                 candidates: tagger(people: ["Sarah"])))
        XCTAssertEqual(r2.topMention, WeeklyRecap.Mention(name: "Sarah", count: 2, kind: .person))
    }

    func testTheTaggerCanSuggestButNeverInvent() throws {
        let cal = calendar()
        let entries = [
            entry(date(2026, 10, 13, in: cal), "Made samosas for everyone at home."),
            entry(date(2026, 10, 14, in: cal), "More samosas, the sam kind as before."),
            entry(date(2026, 10, 15, in: cal), "Nobody named here at all today.")
        ]
        let r = try XCTUnwrap(Resurfacing.recap(of: entries, week: week(cal), calendar: cal,
                                                candidates: tagger(people: ["Sam", "Priya"], places: ["Goa"])))
        XCTAssertNil(r.topMention, "not in 'samosas', not lowercase 'sam', not a name never said")
    }

    func testTopicsCountInAnyCaseAndThePersonWinsATie() throws {
        let cal = calendar()
        let entries = [
            entry(date(2026, 10, 13, in: cal), "Work was heavy. Meera helped with the deck."),
            entry(date(2026, 10, 14, in: cal), "Another day of work, then dinner with Meera.")
        ]
        let r = try XCTUnwrap(Resurfacing.recap(of: entries, week: week(cal), calendar: cal,
                                                candidates: tagger(people: ["Meera"], topics: ["Work"])))
        XCTAssertEqual(r.topMention?.kind, .person)
        XCTAssertEqual(r.topMention?.name, "Meera")

        let more = entries + [entry(date(2026, 10, 15, in: cal), "Work, work and then more work again.")]
        let r2 = try XCTUnwrap(Resurfacing.recap(of: more, week: week(cal), calendar: cal,
                                                 candidates: tagger(people: ["Meera"], topics: ["Work"])))
        XCTAssertEqual(r2.topMention, WeeklyRecap.Mention(name: "Work", count: 5, kind: .topic),
                       "spelled as first written, counted in every case")
    }

    func testTheRecapLineSaysTheName() throws {
        let cal = calendar()
        let entries = [
            entry(date(2026, 10, 13, in: cal), "Long call with Arjun about the move to Pune."),
            entry(date(2026, 10, 16, in: cal), "Slept badly. Arjun texted that the flat is ours. Celebrated with tea.")
        ]
        let r = try XCTUnwrap(Resurfacing.recap(of: entries, week: week(cal), calendar: cal,
                                                candidates: tagger(people: ["Arjun"])))
        XCTAssertEqual(r.line?.excerpt, "Arjun texted that the flat is ours.")
        XCTAssertEqual(r.line?.entryID, entries[1].id)
        XCTAssertEqual(r.line?.kind, .fromWeek)
    }
}

/// The opt-in quote in the evening reminder. Off, the reminders say nothing
/// from the journal; on, only the week-ago words, verbatim, on the evenings
/// that have them.
final class ReminderPastLineTests: XCTestCase {

    private let manager = ReminderManager.shared
    private let cal = Calendar.current
    private let said = "Finally finished the painting for Amma. It took three weekends."

    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 9))!
    }

    /// An entry exactly a week before the evening `offset` days from now.
    private func weekBefore(evening offset: Int, text: String? = nil) -> PastEntry {
        let day = cal.date(byAdding: .day, value: offset - 7, to: cal.startOfDay(for: now))!
        return PastEntry(id: UUID(), date: cal.date(byAdding: .hour, value: 20, to: day)!, text: text ?? said)
    }

    private let generic = "Whenever you're ready. Forty-two seconds."

    func testOffMeansNothingFromTheJournal() {
        let planned = manager.plannedReminders(spokenDays: [], now: now,
                                               pastEntries: [weekBefore(evening: 0), weekBefore(evening: 1)],
                                               quotePast: false)
        XCTAssertFalse(planned.isEmpty)
        for r in planned {
            XCTAssertFalse(r.body.contains("Amma"), "\(r.identifier) quotes the journal with the toggle off")
            XCTAssertFalse(r.title.contains("Amma"))
        }
    }

    func testTheSettingIsOffByDefault() throws {
        // Nothing in the test host turns it on, so this is the install default.
        try XCTSkipIf(UserDefaults.standard.object(forKey: "solyn_reminder_quote_past") != nil,
                      "the setting has been written on this simulator")
        XCTAssertFalse(manager.includesPastLine)
        let planned = manager.plannedReminders(spokenDays: [], now: now,
                                               pastEntries: (0..<7).map { weekBefore(evening: $0) })
        XCTAssertTrue(planned.allSatisfy { !$0.body.contains("Amma") })
    }

    func testOnQuotesOnlyTheEveningExactlyAWeekOn() throws {
        // Not the Today card's 6-to-8-day fallback: that would put the same
        // words on the lock screen three evenings running.
        let planned = manager.plannedReminders(spokenDays: [], now: now,
                                               pastEntries: [weekBefore(evening: 2)], quotePast: true)
        let quoted = planned.filter { $0.body.contains("Amma") }
        XCTAssertEqual(quoted.count, 1)
        let fires = manager.plannedFireDates(spokenDays: [], now: now)
        XCTAssertEqual(quoted.first?.fireDate, fires[2])
        XCTAssertTrue(planned.filter { !$0.body.contains("Amma") && $0.identifier.hasSuffix(".welcome_back") == false }
            .allSatisfy { $0.body == generic })
    }

    func testTheQuoteIsVerbatimAndLabelledByItsDay() throws {
        let fire = try XCTUnwrap(manager.plannedFireDates(spokenDays: [], now: now).first)
        let past = PastEntry(id: UUID(), date: cal.date(byAdding: .day, value: -7, to: fire)!, text: said)
        let pick = try XCTUnwrap(Resurfacing.weekAgo(in: [past], now: fire,
                                                     limit: Resurfacing.notificationExcerptLimit))
        XCTAssertEqual(pick.excerpt, said)
        let first = try XCTUnwrap(manager.plannedReminders(spokenDays: [], now: now,
                                                           pastEntries: [past], quotePast: true).first)
        XCTAssertEqual(first.body, ReminderManager.pastLineBody(pick))
        XCTAssertTrue(first.body.contains("\u{201C}\(said)\u{201D}"))
        XCTAssertTrue(first.body.hasPrefix("A week ago"))
    }

    func testTheLockScreenQuoteStaysShort() throws {
        let long = String(repeating: "We drove for hours along the coast and talked about everything ", count: 4) + "."
        let fire = try XCTUnwrap(manager.plannedFireDates(spokenDays: [], now: now).first)
        let past = PastEntry(id: UUID(), date: cal.date(byAdding: .day, value: -7, to: fire)!, text: long)
        let first = try XCTUnwrap(manager.plannedReminders(spokenDays: [], now: now,
                                                           pastEntries: [past], quotePast: true).first)
        let quote = try XCTUnwrap(first.body.split(separator: "\u{201C}").last).dropLast()
        XCTAssertLessThanOrEqual(quote.count, Resurfacing.notificationExcerptLimit)
        XCTAssertTrue(long.hasPrefix(String(quote.dropLast())), "verbatim up to the ellipsis")
    }

    func testQuotingNeverChangesWhichIdentifiersAreArmed() {
        let off = manager.plannedReminders(spokenDays: [], now: now, quotePast: false).map(\.identifier)
        let on = manager.plannedReminders(spokenDays: [], now: now,
                                          pastEntries: (0..<7).map { weekBefore(evening: $0) },
                                          quotePast: true).map(\.identifier)
        XCTAssertEqual(off, on)
        XCTAssertTrue(Set(on).isSubset(of: Set(manager.cancellableIdentifiers)))
    }

    func testTheWelcomeBackNoteNeverQuotes() throws {
        let entries = (-3..<12).map { weekBefore(evening: $0) }
        let note = try XCTUnwrap(manager.plannedReminders(spokenDays: [], now: now,
                                                          pastEntries: entries, quotePast: true).last)
        XCTAssertFalse(note.body.contains("Amma"))
    }
}
