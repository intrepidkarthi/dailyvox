//
//  LanguageGateWiringTests.swift
//  solynTests
//
//  iOS 1.14 (plan B-4, B-10, B-11): the app's readers ask the engine's
//  LanguageGate, with the entry's stored transcriptLocale as the language.
//

import XCTest
import DailyVoxTwinEngine
@testable import solyn

/// THE RULE: a feature that cannot read a language goes QUIET for it, never
/// wrong. Every non-English case here is paired with an English one that must
/// behave exactly as it did in 1.13.1.
final class LanguageGateWiringTests: XCTestCase {

    // MARK: - Fixtures

    /// The 1.13.1 English fixtures, plus spoken-style entries.
    private let english = [
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
        "Gracias",
        "pizza night",
        "",
    ]

    private let spanish = "Hoy fue un día muy triste. Mi abuela murió esta mañana y no puedo dejar de llorar."
    private let spanishHappy = "Hoy me siento muy feliz y agradecido, todo salió bien en el trabajo con mis amigos."
    private let french = "Aujourd'hui je me sens très reconnaissant, tout s'est bien passé au travail avec mes amis."
    private let german = "Heute war ein sehr schöner Tag, ich bin dankbar für meine Familie und meine Freunde."
    private let italian = "Oggi è stata una bella giornata, sono molto grato per la mia famiglia e i miei amici."
    private let portuguese = "Hoje foi um dia muito bom, estou muito feliz e grato pela minha família e amigos."
    private let hindi = "आज मेरा दिन बहुत अच्छा था। मैं राम के साथ बाज़ार गया और हमने चाय पी।"
    private let tamil = "இன்று நான் மிகவும் மகிழ்ச்சியாக இருக்கிறேன். என் அம்மாவுடன் கோவிலுக்கு சென்றேன்."
    private let japanese = "今日はとても楽しい一日でした。友達と一緒に公園で散歩しました。"

    private var nonEnglish: [String] {
        [spanish, spanishHappy, french, german, italian, portuguese, hindi, tamil, japanese]
    }

    private let grateful = "I feel so grateful and thankful for my family today, truly blessed"

    // MARK: - The gate agrees with 1.13.1 on every entry

    /// What proves English is unchanged: on text alone, the engine's reading
    /// language is English exactly where `EntryLanguage` said English.
    func testGateAgreesWithEntryLanguageOnText() {
        for text in english + nonEnglish {
            XCTAssertEqual(FeatureLanguage.reading(text, stored: nil) == "en",
                           EntryLanguage.isEnglish(text), text)
        }
    }

    func testEnglishReadsEveryFeature() {
        for text in english {
            for stored in [nil, "en-US", "en", "en-IN", TranscriptLocale.undetermined] {
                for feature in LanguageFeature.allCases {
                    XCTAssertTrue(FeatureLanguage.reads(feature, text: text, stored: stored),
                                  "\(feature) on \(text) stored \(stored ?? "nil")")
                }
            }
        }
    }

    // MARK: - The stored language wins

    func testStoredLanguageWinsOverTheText() {
        // A short Spanish note reads as English from its text; the recogniser
        // that heard it knows better.
        XCTAssertEqual(FeatureLanguage.reading("Ana playa", stored: nil), "en")
        XCTAssertEqual(FeatureLanguage.reading("Ana playa", stored: "es-MX"), "es")
        XCTAssertEqual(FeatureLanguage.reading("Coffee with Priya", stored: "hi-IN"), "hi")
    }

    func testUndeterminedFallsBackToTheText() {
        XCTAssertEqual(FeatureLanguage.reading("Coffee with Priya before work.", stored: "und"), "en")
        XCTAssertEqual(FeatureLanguage.reading(spanish, stored: "und"), "es")
    }

    func testAMixedDayIsQuietForReadersButStillSearched() {
        XCTAssertFalse(FeatureLanguage.readsMood(grateful, stored: TranscriptLocale.multiple))
        XCTAssertFalse(FeatureLanguage.readsReflection(grateful, stored: TranscriptLocale.multiple))
        XCTAssertNil(FeatureLanguage.indexLanguage(stored: TranscriptLocale.multiple),
                     "a mul day is detected from its words for search, never left out")
        XCTAssertEqual(FeatureLanguage.indexLanguage(stored: "es-ES"), "es-ES")
        XCTAssertNil(FeatureLanguage.indexLanguage(stored: nil))
    }

    // MARK: - SuggestedMood

    func testSuggestedMoodUsesTheStoredLanguage() {
        XCTAssertEqual(SuggestedMood.suggest(for: grateful), .grateful)
        XCTAssertEqual(SuggestedMood.suggest(for: grateful, language: "en-US"), .grateful, "English unchanged")
        XCTAssertEqual(SuggestedMood.suggest(for: grateful, language: "und"), .grateful)
        XCTAssertNil(SuggestedMood.suggest(for: grateful, language: "es-ES"),
                     "words the Spanish recogniser heard are not read with the English lexicon")
        XCTAssertNil(SuggestedMood.suggest(for: grateful, language: TranscriptLocale.multiple))
        for text in nonEnglish {
            XCTAssertNil(SuggestedMood.suggest(for: text, language: nil), text)
        }
        XCTAssertNil(SuggestedMood.suggest(for: "I am not sad, I am actually doing fine today", language: "en-US"),
                     "the negation re-read is unchanged")
    }

    // MARK: - EntryReflection

    func testReflectionUsesTheStoredLanguage() {
        let text = "I feel so grateful today, everything went well at work and I'm happy."
        let before = EntryReflection.make(entryText: text, entryID: nil)
        XCTAssertNotNil(before)
        XCTAssertEqual(EntryReflection.make(entryText: text, entryID: nil, language: "en-US"), before,
                       "English reflection identical with the stored locale")
        XCTAssertNil(EntryReflection.make(entryText: text, entryID: nil, language: "hi-IN"))
        for text in nonEnglish {
            XCTAssertNil(EntryReflection.make(entryText: text, entryID: nil, language: nil), text)
        }
    }

    // MARK: - DailyQuestion grounded

    private let read: (String) -> DailyQuestions.Reading = { _ in
        DailyQuestions.Reading(people: ["Priya"], places: [], sentiment: 0.2)
    }

    func testGroundedQuestionUsesTheStoredLanguage() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 10))!
        let then = cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!
        let text = "Coffee with Priya before work."

        for stored in [nil, "en-US", "und"] {
            let entry = QuestionSource(id: UUID(), date: then, text: text, mood: .none, language: stored)
            XCTAssertEqual(DailyQuestions.subjects(in: [entry], now: now, calendar: cal, read: read).map(\.name),
                           ["Priya"], "English grounding unchanged (\(stored ?? "nil"))")
        }
        // Names are readable in Spanish, the sensitive-word list is not.
        for stored in ["es-ES", "pt-BR", "hi-IN", TranscriptLocale.multiple] {
            let entry = QuestionSource(id: UUID(), date: then, text: text, mood: .none, language: stored)
            XCTAssertTrue(DailyQuestions.subjects(in: [entry], now: now, calendar: cal, read: read).isEmpty, stored)
        }
    }

    // MARK: - EarlySignals repeats

    private func entries(_ texts: [String], language: String? = nil) -> [EarlySignals.Entry] {
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        return texts.enumerated().map {
            EarlySignals.Entry(date: base.addingTimeInterval(Double($0.offset) * 86_400),
                               text: $0.element, chosenMood: nil, suggestedMood: nil, language: language)
        }
    }

    func testEnglishRepeatsUnchanged() {
        let texts = ["Long walk with Priya after work, the garden was quiet.",
                     "Priya called about the garden again, and work was heavy.",
                     "Garden in the morning, then work."]
        let plain = EarlySignals.repeats(entries(texts))
        XCTAssertEqual(plain.map(\.word), ["garden", "work", "Priya"])
        XCTAssertEqual(EarlySignals.repeats(entries(texts, language: "en-US")), plain)
        XCTAssertEqual(EarlySignals.stopWords(forEntryIn: entries(texts).first!), EarlySignals.stopWords,
                       "English keeps the app's own list")
    }

    func testSpanishRepeatsDropSpanishFunctionWords() {
        let texts = ["Fui a la playa con mis amigos para ver el mar porque hacía calor.",
                     "Otra vez la playa, para descansar con mis amigos porque estaba cansado.",
                     "La playa estaba tranquila hoy para caminar."]
        let words = EarlySignals.repeats(entries(texts, language: "es-ES")).map(\.word)
        XCTAssertTrue(words.contains("playa"), "\(words)")
        for function in ["para", "con", "porque", "mis", "estaba"] {
            XCTAssertFalse(words.contains(function), "\(function) is a Spanish function word: \(words)")
        }
    }

    func testLanguagesWithNoListGiveNoRepeats() {
        let tamilTexts = Array(repeating: tamil, count: 3)
        XCTAssertTrue(EarlySignals.repeats(entries(tamilTexts)).isEmpty)
        let english = ["Garden and work.", "Garden and work again.", "Garden."]
        XCTAssertTrue(EarlySignals.repeats(entries(english, language: "ta-IN")).isEmpty,
                      "the Tamil recogniser's words are not read with an English list")
        XCTAssertTrue(EarlySignals.repeats(entries(english, language: TranscriptLocale.multiple)).isEmpty)
    }

    // MARK: - ShareableInsightGenerator

    func testShareableInsightsReadOnlyAWholeEnglishWeek() {
        let week: [(text: String, language: String?)] = english.prefix(4).map { ($0, nil) }
        XCTAssertTrue(ShareableInsightGenerator.canRead(week))
        XCTAssertTrue(ShareableInsightGenerator.canRead(week.map { ($0.text, "en-US") }))
        XCTAssertFalse(ShareableInsightGenerator.canRead(week + [(spanish, nil)]),
                       "one entry it cannot read makes every count on the cards wrong")
        XCTAssertFalse(ShareableInsightGenerator.canRead(week + [("Coffee with Priya.", "es-MX")]))
        XCTAssertFalse(ShareableInsightGenerator.canRead([(hindi, "hi-IN"), (hindi, nil), (hindi, nil)]))
    }

    // MARK: - Resurfacing recap

    private func past(_ text: String, _ language: String?, day: Int) -> PastEntry {
        PastEntry(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400),
                  text: text, language: language)
    }

    func testRecapMentionsUnchangedInEnglish() {
        let week = [past("Lunch with Meera, then work.", nil, day: 0),
                    past("Meera called after work.", "en-US", day: 1)]
        let mention = Resurfacing.topMention(in: week) { _ in
            Resurfacing.Candidates(people: ["Meera"], topics: ["Work"])
        }
        XCTAssertEqual(mention?.name, "Meera")
        XCTAssertEqual(mention?.count, 2)
    }

    /// German capitalises every noun, so a tagger reading it as English files
    /// "Arbeit" as a person. LanguageGate lists names for German (the OS
    /// tagger reads it, measured) but not the engine's English topics.
    func testRecapProposesOnlyWhatTheLanguageCanBeReadFor() {
        let spanishWeek = [past("Comí con Lucía y luego fui al trabajo.", "es-ES", day: 0),
                           past("Lucía me llamó después del trabajo.", "es-ES", day: 1)]
        let names = Resurfacing.topMention(in: spanishWeek) { _ in
            Resurfacing.Candidates(people: ["Lucía"], topics: ["trabajo"])
        }
        XCTAssertEqual(names?.name, "Lucía", "Spanish names are read")
        let topicsOnly = Resurfacing.topMention(in: spanishWeek) { _ in
            Resurfacing.Candidates(topics: ["trabajo"])
        }
        XCTAssertNil(topicsOnly, "English keyword topics are not proposed from a Spanish week")

        let hindiWeek = [past(hindi, "hi-IN", day: 0), past(hindi, "hi-IN", day: 1)]
        XCTAssertNil(Resurfacing.topMention(in: hindiWeek) { _ in
            Resurfacing.Candidates(people: ["राम"], topics: ["बाज़ार"])
        }, "nothing is proposed from a language with neither")
    }

    // MARK: - LiveTranscriber

    func testKnownNamesMatchWholeWordsOnly() {
        XCTAssertNil(LiveTranscriber.detectName(in: "had samosa and banana for lunch", known: ["Sam", "Ana"]),
                     "Sam is not in samosa, Ana is not in banana")
        XCTAssertEqual(LiveTranscriber.detectName(in: "had samosa with Sam", known: ["Sam"]), "Sam")
    }

    func testTheNameSaidLastWinsWhateverTheGraphOrder() {
        XCTAssertEqual(LiveTranscriber.detectName(in: "James called, then Sarah came over",
                                                  known: ["Sarah", "James"]), "Sarah")
        XCTAssertEqual(LiveTranscriber.detectName(in: "Sarah called, then James came over",
                                                  known: ["Sarah", "James"]), "James")
    }

    func testNoNameBlinksWhereTheTaggerCannotRead() {
        let text = "I finally called Sarah back this evening"
        XCTAssertEqual(LiveTranscriber.detectName(in: text, known: ["Sarah"], language: "en-US"), "Sarah")
        XCTAssertEqual(LiveTranscriber.detectName(in: "Hoy hablé con Sarah", known: ["Sarah"], language: "es-ES"),
                       "Sarah", "Spanish names are read")
        XCTAssertNil(LiveTranscriber.detectName(in: text, known: ["Sarah"], language: "hi-IN"))
        XCTAssertNil(LiveTranscriber.detectName(in: "आज राम से मिला", known: ["राम"], language: "hi-IN"))
    }

    func testValenceIsQuietWhereSentimentCannotRead() {
        let text = "I feel wonderful and grateful today, a really lovely evening"
        let english = LiveTranscriber.valence(of: text, language: "en-US")
        XCTAssertNotNil(english)
        XCTAssertEqual(english, LiveTranscriber.valence(of: text), "English unchanged")
        XCTAssertEqual(LiveTranscriber.valence(of: "short", language: "en-US"), 0, "short English is still 0")
        XCTAssertNotNil(LiveTranscriber.valence(of: spanishHappy, language: "es-ES"))
        XCTAssertNil(LiveTranscriber.valence(of: hindi, language: "hi-IN"))
        XCTAssertNil(LiveTranscriber.valence(of: "", language: "hi-IN"), "no bar from the first moment")
        XCTAssertNil(LiveTranscriber.valence(of: portuguese, language: "pt-BR"))
    }

    // MARK: - Search (B-10)

    func testQueryLanguage() {
        let en = Locale(identifier: "en_US")
        let es = Locale(identifier: "es_MX")
        XCTAssertEqual(FeatureLanguage.queryLanguage("beach", speaking: en), "en")
        XCTAssertEqual(FeatureLanguage.queryLanguage("when did I go to the beach", speaking: en), "en")
        XCTAssertEqual(FeatureLanguage.queryLanguage("playa", speaking: es), "es",
                       "a one-word query is in the language the person speaks")
        XCTAssertEqual(FeatureLanguage.queryLanguage("¿Cuándo fui a la playa con mis amigos?", speaking: en), "es")
        XCTAssertEqual(FeatureLanguage.queryLanguage("मैं बाज़ार कब गया था", speaking: en), "hi")
    }

    // MARK: - Ask your Twin (B-11)

    func testAskAnswersInItsLanguages() {
        let en = Locale(identifier: "en_US")
        XCTAssertTrue(AskLanguage.canAnswer("What do I keep avoiding saying out loud?", speaking: en))
        XCTAssertTrue(AskLanguage.canAnswer("Sarah", speaking: en))
        XCTAssertTrue(AskLanguage.canAnswer("¿Qué hice el fin de semana con mis amigos?", speaking: en))
        XCTAssertTrue(AskLanguage.canAnswer("Qu'est-ce que j'ai fait ce week-end avec mes amis ?", speaking: en))
        XCTAssertTrue(AskLanguage.canAnswer("Was habe ich am Wochenende mit meinen Freunden gemacht?", speaking: en))
        XCTAssertTrue(AskLanguage.canAnswer("Cosa ho fatto nel fine settimana con i miei amici?", speaking: en))
    }

    func testAskIsCalmWhereItCannotRead() {
        let en = Locale(identifier: "en_US")
        let hi = Locale(identifier: "hi_IN")
        XCTAssertFalse(AskLanguage.canAnswer("मैं पिछले हफ्ते बाज़ार कब गया था?", speaking: en))
        XCTAssertFalse(AskLanguage.canAnswer(japanese, speaking: en))
        XCTAssertFalse(AskLanguage.canAnswer(tamil, speaking: en))
        XCTAssertFalse(AskLanguage.canAnswer("Ram", speaking: hi),
                       "a fragment from a Hindi speaker is read as Hindi")
        XCTAssertTrue(AskLanguage.canAnswer("What did I do last weekend with my friends?", speaking: hi),
                      "a sentence the recogniser is sure is English is English")
    }

    func testAskNoteForTheSpeakingLanguage() {
        for id in ["en_US", "en_IN", "es_MX", "fr_FR", "de_DE", "it_IT"] {
            XCTAssertTrue(AskLanguage.understands(speaking: Locale(identifier: id)), id)
        }
        for id in ["hi_IN", "ta_IN", "ja_JP"] {
            XCTAssertFalse(AskLanguage.understands(speaking: Locale(identifier: id)), id)
        }
        XCTAssertFalse(AskLanguage.unsupportedMessage.isEmpty)
    }
}
