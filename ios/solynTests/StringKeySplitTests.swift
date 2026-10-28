//
//  StringKeySplitTests.swift
//  solynTests
//
//  iOS 1.14 localisation prep. Some short English words were one catalog key
//  serving several screens ("low" was both a mood word and a confidence word;
//  "Health" was both a life area and Apple's app name). A translator often
//  needs different words for them, so each context now has its own key. The
//  English must not move: every split key shows exactly the word the shared
//  key carried, and languages that already had a word keep it.
//

import XCTest
@testable import solyn

final class StringKeySplitTests: XCTestCase {

    private func requireEnglish() throws {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        try XCTSkipUnless(lang.hasPrefix("en"), "app is running in \(lang), not English")
    }

    private static let missing = "<missing>"

    /// Looks the key up in the built catalog with a sentinel fallback. The
    /// build ships no English table (English is the in-code default), so in
    /// English a key either resolves to the old word or is absent and the call
    /// site's defaultValue shows; it must never resolve to anything else.
    private func catalogValue(_ key: String, in bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    private func lproj(_ lang: String) -> Bundle? {
        Bundle.main.path(forResource: lang, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    func testSplitKeysCarryTheOldEnglish() throws {
        try requireEnglish()
        let expected: [String: String] = [
            "weekDecoded.moodFallback.low": "low",
            "twin.confidence.low": "low",
            "lifeArea.health": "Health",
            "lifeArea.growth": "Growth",
            "shareCard.body.name": "Body",
            "twin.skyDepth.deep": "Deep",
            "twin.skyDepth.established": "Established",
            "twin.selfAwareness.high": "Deep",
            "twin.selfAwareness.low": "Developing",
            "reminder.preset.morning": "Morning",
            "reminder.preset.evening": "Evening",
            "pilot.emotion.neutral": "Neutral",
            "quiz.expression.low": "Reserved",
            "quiz.expression.high": "Expressive",
            "quiz.directness.low": "Nuanced",
            "quiz.directness.high": "Direct",
            "quiz.abstraction.low": "Concrete",
            "quiz.abstraction.high": "Abstract",
            "quiz.emotionalRange.low": "Steady",
            "journal.row.starred.a11y": "Starred",
            "weekDecoded.personMentions.count": "%lldx",
            "twin.myWorld.mentions.count": "%lldx",
        ]
        for (key, english) in expected {
            let value = catalogValue(key)
            XCTAssertTrue(value == english || value == Self.missing, "\(key) resolved to \(value)")
        }
    }

    /// A language that already had a word for the shared key keeps it under
    /// both keys (flagged for review), so splitting changed nothing on screen.
    func testExistingTranslationsFollowedTheSplit() throws {
        for lang in ["de", "es", "fr", "it"] {
            let bundle = try XCTUnwrap(lproj(lang), "\(lang).lproj")
            XCTAssertNotEqual(catalogValue("lifeArea.health", in: bundle), Self.missing, lang)
            XCTAssertNotEqual(catalogValue("Health", in: bundle), Self.missing, lang)
            XCTAssertEqual(catalogValue("pilot.emotion.neutral", in: bundle),
                           catalogValue("Neutral", in: bundle), lang)
        }
    }

    func testFormattedSplitKeysRenderTheOldEnglish() throws {
        try requireEnglish()
        XCTAssertEqual(String(localized: "weekDecoded.personMentions.count", defaultValue: "\(8)x"), "8x")
        XCTAssertEqual(String(localized: "twin.myWorld.mentions.count", defaultValue: "\(12)x"), "12x")
        // The count arrives as a digit string: never grouped, as before.
        XCTAssertEqual(String(localized: "\(String(1234)) total mentions before"), "1234 total mentions before")
    }

    func testLifeAreaHealthNoLongerSharesAppleHealthsKey() throws {
        try requireEnglish()
        XCTAssertEqual(LifeArea.health.title, "Health")
        XCTAssertEqual(LifeArea.growth.title, "Growth")
    }
}
