//
//  LiveTranscriberTests.swift
//  solynTests
//
//  The pure parts of live transcription — what the Dynamic Island renders.
//

import XCTest
@testable import solyn

/// The audio path needs a device, but everything that decides what §E states ②
/// and ③ actually SAY is pure and testable, and it is where the mistakes are:
/// a name detector that fires on "I" or a clause trimmer that cuts mid-word both
/// look fine in code and wrong on the Island.
final class LiveTranscriberTests: XCTestCase {

    // MARK: - The transcript tail

    func testShortPhrasePassesThroughWhole() {
        let text = "Had lunch with Sarah"
        XCTAssertEqual(LiveTranscriber.lastClause(of: text), text)
    }

    func testLongPhraseIsTrimmedToTheTail() {
        let text = String(repeating: "word ", count: 60)
        let clause = LiveTranscriber.lastClause(of: text)
        XCTAssertLessThanOrEqual(clause.count, 90)
        // Compared against the TRIMMED source: `lastClause` strips surrounding
        // whitespace first, which is what stops a partial ending on a pause from
        // rendering with a dangling space inside its quotation marks.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmed.hasSuffix(clause),
                      "the tail should be the END of what was said, not the start")
    }

    /// A clause that opens mid-word reads as a rendering bug.
    func testTrimmedPhraseStartsOnAWordBoundary() {
        let text = "supercalifragilistic " + String(repeating: "alpha bravo ", count: 12)
        let clause = LiveTranscriber.lastClause(of: text)
        XCTAssertFalse(clause.hasPrefix(" "))
        // Whatever it starts with must be a whole word from the source.
        let firstWord = clause.split(separator: " ").first.map(String.init) ?? ""
        XCTAssertTrue(text.split(separator: " ").map(String.init).contains(firstWord),
                      "\(firstWord) is a fragment, not a word")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(LiveTranscriber.lastClause(of: "  hello  "), "hello")
    }

    // MARK: - The caught name (§E state ②)

    func testKnownNameIsPreferred() {
        let name = LiveTranscriber.detectName(
            in: "I finally called Sarah back this evening",
            known: ["Sarah", "James"]
        )
        XCTAssertEqual(name, "Sarah")
    }

    func testKnownNameMatchIsCaseInsensitive() {
        let name = LiveTranscriber.detectName(in: "talked to sarah", known: ["Sarah"])
        XCTAssertEqual(name, "Sarah", "should return the graph's capitalisation, not the transcript's")
    }

    /// The most recent name wins — the Island is showing what was JUST caught.
    func testMostRecentKnownNameWins() {
        let name = LiveTranscriber.detectName(
            in: "James called, then Sarah came over",
            known: ["James", "Sarah"]
        )
        XCTAssertEqual(name, "Sarah")
    }

    func testNoNameYieldsNil() {
        XCTAssertNil(LiveTranscriber.detectName(in: "went for a walk and it rained", known: []))
    }

    /// Single letters are almost always a mis-tag on a filler word, and "A ✦
    /// filed to your sky" is the kind of thing that makes a feature look broken.
    func testSingleLetterIsNotAName() {
        let name = LiveTranscriber.detectName(in: "a b c d e", known: [])
        XCTAssertNil(name)
    }

    // MARK: - Live valence (§E state ③)

    func testShortTextHasNoValence() {
        XCTAssertEqual(LiveTranscriber.valence(of: "ok"), 0, accuracy: 0.001,
                       "too little to judge — a bar that swung on two words would be noise")
    }

    func testValenceStaysInRange() {
        for sample in [
            "Today was genuinely wonderful, I felt light and grateful all day",
            "Everything went wrong and I am exhausted and angry about it",
            "I went to the shop and bought some bread and then came home again",
        ] {
            let v = LiveTranscriber.valence(of: sample)
            XCTAssertGreaterThanOrEqual(v, -1)
            XCTAssertLessThanOrEqual(v, 1)
        }
    }

    func testPositiveReadsHigherThanNegative() {
        let happy = LiveTranscriber.valence(of: "Today was wonderful and I felt grateful and light")
        let sad = LiveTranscriber.valence(of: "Today was awful and I felt hopeless and heavy")
        XCTAssertGreaterThan(happy, sad)
    }
}
