//
//  EarlySignalsTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The first-week card may only say what can be counted. These pin the
/// window it appears in and the gates on each line, so it cannot drift into
/// claims the real patterns would not make.
final class EarlySignalsTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ day: Int, _ hour: Int, _ text: String = "",
                       chosen: String? = nil, suggested: String? = nil) -> EarlySignals.Entry {
        EarlySignals.Entry(date: at(day: day, hour: hour), text: text,
                           chosenMood: chosen, suggestedMood: suggested)
    }

    private func words(_ n: Int) -> String {
        Array(repeating: "word", count: n).joined(separator: " ")
    }

    // MARK: - The window

    func testWindowOpensAtThreeAndClosesAtThePatternsThreshold() {
        XCTAssertFalse(EarlySignals.isEarly(entryCount: 0))
        XCTAssertFalse(EarlySignals.isEarly(entryCount: 2))
        XCTAssertTrue(EarlySignals.isEarly(entryCount: 3))
        XCTAssertTrue(EarlySignals.isEarly(entryCount: 7))
        XCTAssertFalse(EarlySignals.isEarly(entryCount: 8))
    }

    /// It gives way exactly where the real patterns begin, not near it.
    func testClosesWhereTwinPatternsOpen() {
        XCTAssertEqual(EarlySignals.firmEntries, TwinPatterns.minimumEntries)
    }

    // MARK: - Time of day

    func testMostEntriesInTheEvening() {
        let r = EarlySignals.report([entry(1, 21), entry(2, 20), entry(3, 9)], calendar: cal)
        XCTAssertEqual(r.timeOfDay, EarlySignals.TimeOfDay(part: .evening, count: 2, total: 3))
    }

    /// A tie is not a habit.
    func testTieSaysNothing() {
        let r = EarlySignals.report([entry(1, 21), entry(2, 20), entry(3, 9), entry(4, 8)], calendar: cal)
        XCTAssertNil(r.timeOfDay)
    }

    /// The most, but not most of them: two of four is not "mostly".
    func testPluralityWithoutMajoritySaysNothing() {
        let r = EarlySignals.report([entry(1, 8), entry(2, 9), entry(3, 14), entry(4, 20)], calendar: cal)
        XCTAssertNil(r.timeOfDay)
        let five = EarlySignals.report([entry(1, 8), entry(2, 9), entry(3, 14), entry(4, 20), entry(5, 23)], calendar: cal)
        XCTAssertNil(five.timeOfDay)
    }

    /// Three of five is a majority.
    func testMajorityIsSaid() {
        let r = EarlySignals.report([entry(1, 8), entry(2, 9), entry(3, 10), entry(4, 14), entry(5, 20)], calendar: cal)
        XCTAssertEqual(r.timeOfDay, EarlySignals.TimeOfDay(part: .morning, count: 3, total: 5))
    }

    /// One in each part of the day: nothing to say.
    func testNoPartWithTwoSaysNothing() {
        let r = EarlySignals.report([entry(1, 8), entry(2, 14), entry(3, 23)], calendar: cal)
        XCTAssertNil(r.timeOfDay)
    }

    /// The hour is local: 23:30 in Kolkata is late at night, though it is
    /// evening in UTC.
    func testTimeOfDayIsLocal() {
        let r = EarlySignals.report([entry(1, 23), entry(2, 23), entry(3, 1)], calendar: cal)
        XCTAssertEqual(r.timeOfDay?.part, .night)
        XCTAssertEqual(r.timeOfDay?.count, 3)
    }

    func testPartBoundaries() {
        XCTAssertEqual(EarlySignals.PartOfDay.of(hour: 4), .night)
        XCTAssertEqual(EarlySignals.PartOfDay.of(hour: 5), .morning)
        XCTAssertEqual(EarlySignals.PartOfDay.of(hour: 12), .afternoon)
        XCTAssertEqual(EarlySignals.PartOfDay.of(hour: 17), .evening)
        XCTAssertEqual(EarlySignals.PartOfDay.of(hour: 22), .night)
    }

    // MARK: - Length

    func testLengthGettingLonger() {
        let r = EarlySignals.report([entry(1, 20, words(20)), entry(2, 20, words(30)), entry(3, 20, words(60))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.averageWords, 37)
        XCTAssertEqual(r.length?.earlierWords, 20)
        XCTAssertEqual(r.length?.recentWords, 60)
        XCTAssertEqual(r.length?.trend, .longer)
    }

    /// The halves are by date, whatever order the entries arrive in.
    func testLengthUsesChronologicalOrder() {
        let r = EarlySignals.report([entry(3, 20, words(60)), entry(1, 20, words(20)), entry(2, 20, words(30))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.trend, .longer)
    }

    func testSmallChangeIsSteady() {
        let r = EarlySignals.report([entry(1, 20, words(40)), entry(2, 20, words(44)), entry(3, 20, words(46))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.trend, .steady)
    }

    /// A 25% change of a handful of words is not a change.
    func testShortEntriesNeedTenWordsOfChange() {
        let r = EarlySignals.report([entry(1, 20, words(4)), entry(2, 20, words(5)), entry(3, 20, words(8))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.trend, .steady)
    }

    func testGettingShorter() {
        let r = EarlySignals.report([entry(1, 20, words(80)), entry(2, 20, words(50)), entry(3, 20, words(30))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.trend, .shorter)
    }

    /// An untranscribed recording is not a zero-word entry.
    func testEmptyTextIsLeftOutOfLength() {
        let r = EarlySignals.report([entry(1, 20, ""), entry(2, 20, words(30)), entry(3, 20, words(30))],
                                    calendar: cal)
        XCTAssertEqual(r.length?.averageWords, 30)
        XCTAssertNil(r.length?.trend)
    }

    // MARK: - Repeated words

    func testWordInTwoEntriesIsShownVerbatim() {
        let r = EarlySignals.report([
            entry(1, 20, "Walked with Priya after work."),
            entry(2, 20, "Priya called. Long day at work."),
            entry(3, 20, "Quiet evening."),
        ], calendar: cal)
        XCTAssertEqual(r.repeats.map(\.word), ["Priya", "work"])
        XCTAssertEqual(r.repeats.map(\.entries), [2, 2])
    }

    /// Whole words only: "working" is not "work", and "Priya's" is Priya.
    func testWholeWordsOnly() {
        let r = EarlySignals.report([
            entry(1, 20, "Working late again."),
            entry(2, 20, "More work."),
            entry(3, 20, "Priya's birthday. Saw Priya."),
            entry(4, 20, "Thinking of Priya."),
        ], calendar: cal)
        XCTAssertFalse(r.repeats.contains { $0.word.lowercased() == "work" })
        XCTAssertEqual(r.repeats.first, EarlySignals.Repeat(word: "Priya", entries: 2))
    }

    /// Said three times in one entry is still one entry.
    func testOneEntryIsNotARepeat() {
        let r = EarlySignals.report([
            entry(1, 20, "Garden, garden, garden."),
            entry(2, 20, "Nothing."),
            entry(3, 20, "Rain."),
        ], calendar: cal)
        XCTAssertTrue(r.repeats.isEmpty)
    }

    func testFillerWordsAreNotRepeats() {
        let r = EarlySignals.report([
            entry(1, 20, "I think it was really good today."),
            entry(2, 20, "I think it was really good today."),
            entry(3, 20, "Something."),
        ], calendar: cal)
        XCTAssertTrue(r.repeats.isEmpty)
    }

    /// Three-letter words count only as names, capitalised each time.
    func testThreeLetterNamesCountButShortWordsDoNot() {
        let r = EarlySignals.report([
            entry(1, 20, "Called Mom. The cat slept."),
            entry(2, 20, "Mom laughed. A cat outside."),
            entry(3, 20, "Rain."),
        ], calendar: cal)
        XCTAssertEqual(r.repeats.map(\.word), ["Mom"])
    }

    /// The lowercase spelling is shown when the user used one: "Work" at the
    /// start of a sentence is the same word as "work".
    func testLowercaseFormPreferred() {
        let r = EarlySignals.report([
            entry(1, 20, "Work was fine."),
            entry(2, 20, "Long day at work."),
            entry(3, 20, "Rain."),
        ], calendar: cal)
        XCTAssertEqual(r.repeats.map(\.word), ["work"])
    }

    func testAtMostThreeRepeats() {
        let text = "apple banana cherry damson elder"
        let r = EarlySignals.report([entry(1, 20, text), entry(2, 20, text), entry(3, 20, "Rain.")], calendar: cal)
        XCTAssertEqual(r.repeats.count, EarlySignals.repeatLimit)
    }

    // MARK: - Moods

    /// Only moods the user picked count as theirs; suggestions are kept apart.
    func testChosenAndSuggestedAreSeparate() {
        let r = EarlySignals.report([
            entry(1, 20, chosen: "calm"),
            entry(2, 20, chosen: "calm"),
            entry(3, 20, chosen: "tired"),
            entry(4, 20, suggested: "happy"),
        ], calendar: cal)
        XCTAssertEqual(r.chosenMoods, [.init(raw: "calm", count: 2), .init(raw: "tired", count: 1)])
        XCTAssertEqual(r.suggestedMoods, [.init(raw: "happy", count: 1)])
    }

    /// "No mood" and unknown values are not a mood.
    func testNoMoodIsNotCounted() {
        XCTAssertTrue(EarlySignals.moodCounts(["", "not-a-mood"]).isEmpty)
    }

    func testNothingToSayIsEmpty() {
        let r = EarlySignals.report([entry(1, 8), entry(2, 14), entry(3, 23)], calendar: cal)
        XCTAssertTrue(r.isEmpty)
    }

    // MARK: - Copy

    /// The suggested line must say "suggested" in words, so it survives
    /// VoiceOver and cannot be read as the user's own report.
    func testSuggestedLineIsLabelled() {
        let line = String(localized: "Suggested from your words, not picked: \(EarlySignalsCard.moodList([.init(raw: "happy", count: 1)]))")
        XCTAssertTrue(line.contains("Suggested"))
        XCTAssertTrue(line.contains("Happy \u{00D7}1"))
    }
}
