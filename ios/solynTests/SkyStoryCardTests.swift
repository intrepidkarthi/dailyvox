//
//  SkyStoryCardTests.swift
//  solynTests
//

import XCTest
import UIKit
@testable import solyn

/// "Share your sky, never your words." The Story card is the one surface built
/// to leave the phone, so the rule is tested where it would break: an entry
/// carrying a unique token, a name and a mood goes in, and none of it may
/// appear in anything the card prints, says to VoiceOver, or sends as text.
final class SkyStoryCardTests: XCTestCase {

    private let token = "QUOKKA-7731-XYZZY"

    /// A journal of `n` nights, spread over a couple of months at believable
    /// hours, with words, a name and moods on every entry.
    private func journal(nights n: Int, text: (Int) -> String) -> [Shareables.Fact] {
        // Local midnight, so every entry lands on its own local day whatever
        // zone the simulator runs in.
        let start = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        var out: [Shareables.Fact] = []
        var day = 0
        for i in 0..<n {
            day += (i % 5 == 3) ? 2 : 1
            // Mostly evenings, a few mornings, one 3am.
            let hour: Double = i == 17 ? 3 : (i % 6 == 0 ? 7.5 : 20 + Double(i % 4) * 0.7)
            let date = start.addingTimeInterval(Double(day) * 86_400 + hour * 3_600)
            out.append(Shareables.Fact(date: date, text: text(i),
                                       mood: i % 2 == 0 ? 0.5 : -0.5,
                                       people: ["Sarah"]))
        }
        return out
    }

    private func secretJournal(nights n: Int = 42) -> [Shareables.Fact] {
        journal(nights: n) { "Told Sarah about \(self.token) and felt anxious, night \($0)." }
    }

    func testCardTextNeverContainsEntryWords() {
        let facts = secretJournal()
        let printed = Shareables.storyLines(facts).joined(separator: "\n")
        let spoken = Shareables.storyAccessibilityLabel(facts)
        let sent = Shareables.storyShareText(nights: Shareables.nights(facts))

        for surface in [printed, spoken, sent] {
            XCTAssertFalse(surface.contains(token), surface)
            XCTAssertFalse(surface.localizedCaseInsensitiveContains("Sarah"), surface)
            XCTAssertFalse(surface.localizedCaseInsensitiveContains("anxious"), surface)
        }
    }

    func testCardSaysTheCountAndTheAddress() {
        let facts = secretJournal()
        XCTAssertEqual(Shareables.nights(facts), 42)
        XCTAssertEqual(Shareables.storyLines(facts),
                       ["MY SKY", "42 nights kept", "DailyVox \u{00B7} getdailyvox.com/sky"])
        XCTAssertEqual(Shareables.storyShareText(nights: 42),
                       "My sky after 42 nights of DailyVox \u{2014} getdailyvox.com/sky")
        XCTAssertEqual(Shareables.storyLines(Array(facts.prefix(1)))[1], "1 night kept")
    }

    /// Stronger than reading the strings: the pixels. Two journals with the
    /// same moments and different words must render byte-identical cards, so
    /// nothing about what was said — text, mood or name — reaches the image.
    func testPixelsDependOnlyOnWhenNotWhat() {
        let secret = secretJournal()
        let plain = journal(nights: 42) { _ in "" }.map {
            Shareables.Fact(date: $0.date, text: "", mood: 0, people: [])
        }
        let a = Shareables.render(.story, facts: secret, includeNames: true, airplane: false)
        let b = Shareables.render(.story, facts: plain, includeNames: true, airplane: false)
        XCTAssertEqual(a.pngData(), b.pngData())
    }

    func testStoryIsNineBySixteen() {
        XCTAssertEqual(Shareables.Card.story.size, CGSize(width: 1080, height: 1920))
        let image = Shareables.render(.story, facts: secretJournal(), includeNames: false,
                                      airplane: false)
        XCTAssertEqual(image.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(image.cgImage?.width, 1080)
        XCTAssertEqual(image.cgImage?.height, 1920)
    }

    func testEmptyJournalStillRenders() {
        let image = Shareables.render(.story, facts: [], includeNames: false, airplane: false)
        XCTAssertEqual(image.size.height, 1920)
    }

    /// Writes an example card for a human to look at. Set
    /// `TEST_RUNNER_SKY_CARD_OUT=/some/path.png` on the xcodebuild command line.
    func testWritesExampleCardWhenAsked() throws {
        let path = ProcessInfo.processInfo.environment["SKY_CARD_OUT"]
        let image = Shareables.render(.story, facts: secretJournal(), includeNames: false,
                                      airplane: false)
        let data = try XCTUnwrap(image.pngData())
        let attachment = XCTAttachment(image: image)
        attachment.name = "sky-story-42"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
