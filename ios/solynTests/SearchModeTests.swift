//
//  SearchModeTests.swift
//  solynTests
//
//  iOS 1.14: the search screen says "by meaning" and shows "% match" only
//  when the query was actually searched by meaning (English). Every other
//  language the engine lists is a word search, and the screen says so.
//

import XCTest
import DailyVoxTwinEngine
@testable import solyn

final class SearchModeTests: XCTestCase {

    private let en = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")
    private let es = Locale(identifier: "es_MX")
    private let ptBR = Locale(identifier: "pt_BR")

    // MARK: English is unchanged

    func testEnglishQueriesSearchByMeaning() {
        for query in ["beach", "job", "a quiet moment that made me feel grounded",
                      "when did I go to the beach", "Priya"] {
            XCTAssertEqual(SemanticSearchManager.mode(for: query, speaking: en), .meaning, query)
        }
        XCTAssertEqual(SemanticSearchManager.defaultMode(speaking: en), .meaning)
    }

    /// The screenshot query is an English sentence: a German-speaking person
    /// typing it still gets meaning search, because that is how it runs.
    func testEnglishSentenceFromAGermanSpeakerIsStillMeaning() {
        XCTAssertEqual(SemanticSearchManager.mode(for: "a quiet moment that made me feel grounded",
                                                  speaking: de), .meaning)
    }

    // MARK: Every other language is a word search

    func testNonEnglishQueriesSearchByWords() {
        XCTAssertEqual(SemanticSearchManager.mode(for: "Oma", speaking: de), .words,
                       "a short query from a German speaker is German")
        XCTAssertEqual(SemanticSearchManager.mode(for: "playa", speaking: es), .words)
        XCTAssertEqual(SemanticSearchManager.mode(for: "praia", speaking: ptBR), .words)
        XCTAssertEqual(SemanticSearchManager.mode(for: "¿Cuándo fui a la playa con mis amigos?", speaking: en),
                       .words, "a clear Spanish sentence is Spanish even for an English speaker")
        XCTAssertEqual(SemanticSearchManager.mode(for: "Heute war ein sehr schöner Tag mit meiner Familie", speaking: en),
                       .words)
        XCTAssertEqual(SemanticSearchManager.mode(for: "मैं बाज़ार कब गया था", speaking: en), .words)
    }

    func testDefaultModeFollowsTheSpeakingLanguage() {
        for locale in [de, es, ptBR, Locale(identifier: "fr_FR"), Locale(identifier: "it_IT")] {
            XCTAssertEqual(SemanticSearchManager.defaultMode(speaking: locale), .words, locale.identifier)
        }
    }

    /// The mode is the engine's own gate over the language the engine reads
    /// the query in: never "meaning" for a language without `.searchSemantic`.
    func testModeIsTheEnginesSemanticGate() {
        for (query, locale) in [("Oma", de), ("playa", es), ("beach", en), ("the day I left my job", en)] {
            let language = SemanticSearchManager.searchLanguage(of: query, speaking: locale)
            XCTAssertEqual(SemanticSearchManager.mode(for: query, speaking: locale) == .meaning,
                           LanguageGate.supports(.searchSemantic, languageCode: language), query)
        }
    }
}
