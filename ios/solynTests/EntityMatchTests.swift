//
//  EntityMatchTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The bug this pins was found in an App Store screenshot: an entry reading
/// "These small moments of peace" had **Mom** and **Small** underlined in gold
/// and filed in the ledger as recognised names.
final class EntityMatchTests: XCTestCase {

    private let sentence = "These small moments of peace are what I treasure most."

    // MARK: - The bug

    func testMomDoesNotMatchInsideMoments() {
        XCTAssertFalse(EntityMatch.mentions("Mom", in: sentence))
    }

    func testSmallDoesNotMatchInsideSmallMomentsAsAName() {
        // "small" IS present as a word here — the real defect for this one was
        // that it became an entity at all — so the word-boundary rule correctly
        // still finds it. What must not happen is a match inside another word.
        XCTAssertFalse(EntityMatch.mentions("mall", in: sentence))
    }

    func testAnnDoesNotMatchAnnouncement() {
        XCTAssertFalse(EntityMatch.mentions("Ann", in: "There was an announcement at work."))
    }

    // MARK: - It still has to find real mentions

    func testFindsARealName() {
        XCTAssertTrue(EntityMatch.mentions("Sarah", in: "Sarah gave great feedback today."))
    }

    func testIsCaseInsensitive() {
        XCTAssertTrue(EntityMatch.mentions("sarah", in: "Sarah gave great feedback."))
        XCTAssertTrue(EntityMatch.mentions("SARAH", in: "Sarah gave great feedback."))
    }

    func testMatchesNextToPunctuation() {
        for text in ["I called Mom.", "Mom, finally.", "(Mom)", "Mom's car", "—Mom—"] {
            XCTAssertTrue(EntityMatch.mentions("Mom", in: text), "failed on: \(text)")
        }
    }

    func testMatchesAMultiWordName() {
        XCTAssertTrue(EntityMatch.mentions("New York", in: "Flew to New York on Tuesday."))
        XCTAssertFalse(EntityMatch.mentions("New York", in: "Flew to Newark on Tuesday."))
    }

    // MARK: - Ranges, which drive the underlining

    func testEveryOccurrenceIsFound() {
        let text = "Mike called. Later Mike called again, and Mike sounded better."
        XCTAssertEqual(EntityMatch.ranges(of: "Mike", in: text).count, 3)
    }

    /// The underliner used to advance past the end of the string on a match at
    /// the very end. Ranges must simply come back correct.
    func testAMatchAtTheVeryEnd() {
        let text = "The one who called was Mike"
        let ranges = EntityMatch.ranges(of: "Mike", in: text)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(text[ranges[0]], "Mike")
    }

    func testEmptyInputsAreSafe() {
        XCTAssertTrue(EntityMatch.ranges(of: "", in: "anything").isEmpty)
        XCTAssertTrue(EntityMatch.ranges(of: "Mike", in: "").isEmpty)
        XCTAssertTrue(EntityMatch.ranges(of: "   ", in: "anything").isEmpty)
    }

    /// A name with regex punctuation in it must be matched literally, not
    /// compiled as a pattern.
    func testNameWithRegexCharactersIsLiteral() {
        XCTAssertTrue(EntityMatch.mentions("A.J.", in: "Saw A.J. at lunch."))
        XCTAssertFalse(EntityMatch.mentions("A.J.", in: "Saw AXJX at lunch."))
    }

    func testPresentFiltersAndKeepsOrder() {
        let text = "Sarah and Mike were there; moments passed."
        XCTAssertEqual(EntityMatch.present(["Sarah", "Mom", "Mike"], in: text), ["Sarah", "Mike"])
    }
}

/// The second half of the same screenshot bug: word boundaries made the match a
/// whole word, but "Small" was still filed as a PLACE from "These small moments
/// of peace". Boundaries cannot tell a proper noun from an adjective.
extension EntityMatchTests {

    func testALowercaseCommonWordIsNotAName() {
        let text = "These small moments of peace are what I treasure most."
        XCTAssertTrue(EntityMatch.mentions("Small", in: text), "the word is there")
        XCTAssertFalse(EntityMatch.mentionsAsName("Small", in: text), "but not as a name")
    }

    func testACapitalisedNameStillCounts() {
        XCTAssertTrue(EntityMatch.mentionsAsName("Sarah", in: "Sarah gave great feedback."))
    }

    func testOnlyTheCapitalisedOccurrenceIsMarked() {
        // "Rose" the person, and "rose" the verb, in one entry.
        let text = "Rose called. The sun rose before I woke, and Rose had already gone."
        XCTAssertEqual(EntityMatch.ranges(of: "rose", in: text).count, 3)
        XCTAssertEqual(EntityMatch.properNounRanges(of: "Rose", in: text).count, 2)
    }

    func testPresentUsesTheNameRule() {
        let text = "Sarah and I had small talk."
        XCTAssertEqual(EntityMatch.present(["Sarah", "Small"], in: text), ["Sarah"])
    }
}
