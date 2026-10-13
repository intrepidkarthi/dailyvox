//
//  EntryReflectionTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// `EntryReflection` shapes an analysis it is given and nothing more. The bug
/// this guards: building it used to call `LocalAIEngine.analyze(text:)`, which
/// also rewrites the saved user profile, so every save recounted the day.
final class EntryReflectionTests: XCTestCase {

    func testShapesTheGivenResponse() {
        let r = EntryReflection.make(entryText: "Coffee with Sarah in Indiranagar.",
                                     entryID: nil,
                                     suggestedResponse: "  That sounds like a good morning.  ",
                                     people: ["Sarah"], places: ["Indiranagar"])
        XCTAssertEqual(r?.reflection, "That sounds like a good morning.")
        XCTAssertEqual(r?.anchor, "Sarah")
    }

    func testNothingForEmptyTextOrResponse() {
        XCTAssertNil(EntryReflection.make(entryText: "  ", entryID: nil,
                                          suggestedResponse: "Hi", people: [], places: []))
        XCTAssertNil(EntryReflection.make(entryText: "A day.", entryID: nil,
                                          suggestedResponse: " ", people: [], places: []))
    }
}
