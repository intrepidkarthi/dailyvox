//
//  NonEnglishQuietTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// iOS 1.13.1 (plan Phase A0). Where a feature only reads English, it stays
/// QUIET on other languages: no wrong mood, no wrong reflection, no question
/// about an entry it could not check, no name matched inside another name, no
/// English transcript of someone else's language. Every test here pairs the
/// non-English case with an English one that must behave exactly as before.
final class NonEnglishQuietTests: XCTestCase {

    // MARK: - Fixtures

    private let englishEntries = [
        "Had chai with Priya and Arjun at Koramangala, then a long walk home.",
        "I feel so grateful today, everything went well at work and I'm happy.",
        "Long day, completely drained. Need sleep.",
        "Coffee with Priya before work.",
        "Spent the afternoon in Lisbon.",
        "I am not sad, I am actually doing fine today",
        "ok",
        "Mom called.",
        "Lunch with José today.",
        "Went to the market with Rose.",
        "These small moments of peace are what I treasure most.",
    ]

    private let spanish = "Hoy fue un día muy triste. Mi abuela murió esta mañana y no puedo dejar de llorar."
    private let spanishHappy = "Hoy me siento muy feliz y agradecido, todo salió bien en el trabajo con mis amigos."
    private let french = "Aujourd'hui je me sens très reconnaissant, tout s'est bien passé au travail avec mes amis."
    private let german = "Heute war ein sehr schöner Tag, ich bin dankbar für meine Familie und meine Freunde."
    private let portuguese = "Hoje foi um dia muito bom, estou muito feliz e grato pela minha família e amigos."
    private let hindi = "आज मेरा दिन बहुत अच्छा था। मैं राम के साथ बाज़ार गया और हमने चाय पी।"
    private let tamil = "இன்று நான் மிகவும் மகிழ்ச்சியாக இருக்கிறேன். என் அம்மாவுடன் கோவிலுக்கு சென்றேன்."
    private let japanese = "今日はとても楽しい一日でした。友達と一緒に公園で散歩しました。"

    private var nonEnglish: [String] { [spanish, spanishHappy, french, german, portuguese, hindi, tamil, japanese] }

    // MARK: - EntryLanguage

    func testEnglishEntriesAreEnglish() {
        for text in englishEntries {
            XCTAssertTrue(EntryLanguage.isEnglish(text), text)
        }
    }

    func testOtherLanguagesAreNotEnglish() {
        for text in nonEnglish {
            XCTAssertFalse(EntryLanguage.isEnglish(text), text)
        }
    }

    func testShortOrEmptyTextKeepsTheEnglishPath() {
        XCTAssertTrue(EntryLanguage.isEnglish(""))
        XCTAssertTrue(EntryLanguage.isEnglish("Gracias"), "too short to judge a Latin-script word")
        XCTAssertFalse(EntryLanguage.isEnglish("धन्यवाद"), "a non-Latin script is never English")
    }

    // MARK: - A0-1 Same-language-only transcription

    func testEnglishLocalesStillFallBackToEnUS() {
        let ids = SpeechTranscriber.candidateLocales(for: Locale(identifier: "en_IN")).map(\.identifier)
        XCTAssertEqual(ids, ["en_IN", "en", "en-US"])
        XCTAssertTrue(SpeechTranscriber.allowsEnglishFallback(for: Locale(identifier: "en_GB")))
        XCTAssertEqual(SpeechTranscriber.noRecognizerError(for: Locale(identifier: "en_US")),
                       .recognizerUnavailable, "English keeps its old error")
    }

    func testOtherLanguagesNeverFallBackToEnglish() {
        for id in ["hi_IN", "es_ES", "pt_BR", "fr_FR", "de_DE", "it_IT", "ta_IN", "ja_JP"] {
            let locale = Locale(identifier: id)
            let candidates = SpeechTranscriber.candidateLocales(for: locale)
            XCTAssertFalse(candidates.contains { $0.language.languageCode?.identifier == "en" },
                           "\(id) must never be handed an English recogniser")
            XCTAssertEqual(candidates.first?.identifier, id)
            XCTAssertFalse(SpeechTranscriber.allowsEnglishFallback(for: locale))
            XCTAssertEqual(SpeechTranscriber.noRecognizerError(for: locale), .onDeviceUnavailable,
                           "\(id) gets the honest no-on-device-model message")
        }
    }

    func testSameLanguageVariantsAreStillTried() {
        let ids = SpeechTranscriber.candidateLocales(for: Locale(identifier: "es_MX")).map(\.identifier)
        XCTAssertEqual(ids, ["es_MX", "es", "es-US"])
    }

    // MARK: - A0-6 EntryReflection

    func testNonEnglishEntriesGetNoReflection() {
        for text in nonEnglish {
            XCTAssertNil(EntryReflection.make(entryText: text, entryID: UUID()), text)
        }
    }

    func testEnglishEntriesStillGetAReflection() {
        let text = "I feel so grateful today, everything went well at work and I'm happy."
        XCTAssertNotNil(EntryReflection.make(entryText: text, entryID: UUID()))
    }

    // MARK: - SuggestedMood

    func testNonEnglishEntriesGetNoSuggestedMood() {
        for text in nonEnglish {
            XCTAssertNil(SuggestedMood.suggest(for: text), text)
        }
    }

    func testEnglishSuggestedMoodUnchanged() {
        XCTAssertEqual(SuggestedMood.suggest(for: "I feel so grateful and thankful for my family today, truly blessed"),
                       .grateful)
        XCTAssertNil(SuggestedMood.suggest(for: "I am not sad, I am actually doing fine today"))
    }

    // MARK: - A0-7 EntityMatch with combining marks

    func testADevanagariNameIsNotFoundInsideALongerName() {
        XCTAssertFalse(EntityMatch.mentions("राम", in: "आज रामू से मिला।"),
                       "the vowel sign after राम makes it a different name")
        XCTAssertTrue(EntityMatch.mentions("राम", in: "आज राम से मिला।"))
        XCTAssertTrue(EntityMatch.mentions("रामू", in: "आज रामू से मिला।"))
    }

    func testATamilNameIsNotFoundInsideALongerName() {
        // "கமல்" (Kamal) must not be found at the start of "கமலா" (Kamala),
        // where the next character is a vowel sign.
        XCTAssertFalse(EntityMatch.mentions("கமல", in: "கமலா வந்தாள்"))
    }

    func testEnglishNameMatchingUnchanged() {
        XCTAssertFalse(EntityMatch.mentions("Mom", in: "These small moments of peace."))
        XCTAssertTrue(EntityMatch.mentions("A.J.", in: "Dinner with A.J. tonight."))
        XCTAssertTrue(EntityMatch.mentions("José", in: "Lunch with José today."))
        XCTAssertTrue(EntityMatch.mentions("Sarah", in: "Sarah's birthday."))
    }

    // MARK: - A0-8 EarlySignals

    func testUnspacedScriptsAreNotRepeats() {
        let day: TimeInterval = 86_400
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        let entries = (0..<3).map {
            EarlySignals.Entry(date: base.addingTimeInterval(Double($0) * day),
                               text: "今日はとても楽しい一日でした", chosenMood: nil, suggestedMood: nil)
        }
        XCTAssertTrue(EarlySignals.repeats(entries).isEmpty,
                      "a run of Japanese between spaces is a phrase, not a word")
    }

    func testHindiWordsAreNotCutAtVowelSigns() {
        XCTAssertEqual(EarlySignals.words(in: "मैं बाज़ार गया"), ["मैं", "बाज़ार", "गया"])
    }

    func testUnspacedScriptsAreCountedInWords() {
        XCTAssertGreaterThan(EarlySignals.wordCount("今日はとても楽しい一日でした。友達と一緒に公園で散歩しました。"), 5,
                             "NLTokenizer counts words, not space-separated chunks")
    }

    func testEnglishWordCountAndRepeatsUnchanged() {
        XCTAssertEqual(EarlySignals.wordCount("Walked with Priya after work — long day."), 8)
        XCTAssertEqual(EarlySignals.words(in: "Sarah's work, done."), ["Sarah", "s", "work", "done"])
        XCTAssertFalse(EarlySignals.containsUnspacedScript("Walked with Priya after work."))
        XCTAssertFalse(EarlySignals.containsUnspacedScript("मैं बाज़ार गया"), "Hindi is written with spaces")
        XCTAssertTrue(EarlySignals.containsUnspacedScript("สวัสดี"))
    }

    // MARK: - A0-10 Grounded daily question

    private let read: (String) -> DailyQuestions.Reading = { _ in
        DailyQuestions.Reading(people: ["Priya"], places: [], sentiment: 0.2)
    }

    func testNonEnglishEntriesAreNeverAskedAbout() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 10))!
        let then = cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!
        // A Spanish bereavement entry the English sensitive list cannot read.
        let spanishGrief = QuestionSource(
            id: UUID(), date: then,
            text: "Hoy fue el funeral de mi abuela. Priya vino conmigo y lloramos juntas toda la tarde.",
            mood: .none)
        XCTAssertTrue(DailyQuestions.subjects(in: [spanishGrief], now: now, calendar: cal, read: read).isEmpty)

        let english = QuestionSource(id: UUID(), date: then, text: "Coffee with Priya before work.", mood: .none)
        XCTAssertEqual(DailyQuestions.subjects(in: [english], now: now, calendar: cal, read: read).map(\.name),
                       ["Priya"], "English grounding unchanged")
    }
}
