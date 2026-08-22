//
//  ShareBodyCardTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The body card is the only shareable that can carry a medical-sounding fact
/// about someone. Its failure mode is not a crash — it is a picture that leaves
/// the phone with a night's sleep on it that the user never agreed to publish.
/// So the rules get pinned rather than trusted to hold.
@MainActor
final class ShareBodyCardTests: XCTestCase {

    private func fact(_ daysAgo: Int, mood: Double, sleep: Double?) -> Shareables.Fact {
        Shareables.Fact(date: Date().addingTimeInterval(Double(-daysAgo) * 86_400),
                        text: "an entry", mood: mood, people: [], sleepHours: sleep)
    }

    private var measured: [Shareables.Fact] {
        (0..<8).map { fact($0, mood: Double($0 % 3) * 0.3 - 0.3, sleep: $0 % 2 == 0 ? 7.5 : 5.5) }
    }

    // MARK: - Opt-in

    /// Off is the default and it has to be a real one: the renderer must draw a
    /// different card, not the same card with the toggle ignored.
    func testWithheldCardDiffersFromTheIncludedOne() {
        let off = Shareables.render(.body, facts: measured, includeNames: false, includeBody: false, airplane: false)
        let on = Shareables.render(.body, facts: measured, includeNames: false, includeBody: true, airplane: false)
        XCTAssertNotEqual(off.pngData(), on.pngData(),
                          "includeBody: false rendered the same pixels as true — the opt-in does nothing")
    }

    func testBothStatesStillRenderACard() {
        for include in [true, false] {
            let img = Shareables.render(.body, facts: measured, includeNames: false, includeBody: include, airplane: false)
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
    }

    /// No kept data at all — the card must still not crash, because the picker
    /// hides it but a preview can be built before the filter runs.
    func testNoBodyDataRendersWithoutCrashing() {
        let none = (0..<5).map { fact($0, mood: 0.2, sleep: nil) }
        _ = Shareables.render(.body, facts: none, includeNames: false, includeBody: true, airplane: false)
    }

    // MARK: - Not enough to compare

    /// A comparison drawn from one rested night and one short one is noise
    /// wearing the clothes of a finding. Both sides need a real sample.
    func testThinSamplesDrawNoComparison() {
        // Two rested, one short: below the floor on both counts.
        let thin = [fact(0, mood: 0.8, sleep: 8), fact(1, mood: 0.7, sleep: 7.5), fact(2, mood: -0.9, sleep: 4)]
        let thinCard = Shareables.render(.body, facts: thin, includeNames: false, includeBody: true, airplane: false)
        // Same three nights plus enough of each to clear the floor.
        let full = thin + [fact(3, mood: 0.6, sleep: 7.2), fact(4, mood: -0.5, sleep: 5),
                           fact(5, mood: -0.4, sleep: 5.5)]
        let fullCard = Shareables.render(.body, facts: full, includeNames: false, includeBody: true, airplane: false)
        XCTAssertNotEqual(thinCard.pngData(), fullCard.pngData(),
                          "the comparison rows appeared on a sample too thin to support them")
    }

    // MARK: - Which signals may appear

    /// HRV and resting heart rate are readable as a clinical claim in a way
    /// sleep hours are not, so they are kept off every shareable surface. This
    /// asserts on the source, because a drawn card cannot be grepped.
    func testShareablesNeverReadHRVOrRestingHeartRate() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("solyn/Shareables.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for banned in ["morningHRVMs", "restingHRBpm"] {
            XCTAssertFalse(source.contains(banned),
                           "\(banned) reached the share renderer — no heart signal goes on a card")
        }
    }
}
