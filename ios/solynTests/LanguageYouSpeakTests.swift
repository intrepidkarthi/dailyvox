//
//  LanguageYouSpeakTests.swift
//  solynTests
//
//  iOS 1.14 core (plan Phase B): B-1 transcriptLocale, B-6 the "Language you
//  speak" picker, B-7 the dictation route. Every non-English case is paired
//  with an English one that must behave exactly as it did in 1.13.1.
//

import XCTest
import CoreData
@testable import solyn

final class LanguageYouSpeakTests: XCTestCase {

    private var savedChoice: Any?

    override func setUp() {
        super.setUp()
        savedChoice = UserDefaults.standard.object(forKey: SpeakingLanguage.defaultsKey)
        UserDefaults.standard.removeObject(forKey: SpeakingLanguage.defaultsKey)
    }

    override func tearDown() {
        if let savedChoice {
            UserDefaults.standard.set(savedChoice, forKey: SpeakingLanguage.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: SpeakingLanguage.defaultsKey)
        }
        super.tearDown()
    }

    // MARK: - B-1: the model

    func testDiaryEntryHasAnOptionalTranscriptLocale() throws {
        let model = PersistenceController(inMemory: true).container.managedObjectModel
        let attribute = try XCTUnwrap(model.entitiesByName["DiaryEntry"]?.attributesByName["transcriptLocale"])
        XCTAssertEqual(attribute.attributeType, .stringAttributeType)
        // Additive and optional: what lightweight migration and CloudKit
        // both require of a new field.
        XCTAssertTrue(attribute.isOptional)
        XCTAssertNil(attribute.defaultValue)
    }

    // MARK: - B-1: merging segments

    func testFirstWordsSetTheLanguage() {
        XCTAssertEqual(TranscriptLocale.merged(existing: nil, entryHadText: false, segment: "hi-IN"), "hi-IN")
        // A stale tag on an entry with no text is replaced, not merged.
        XCTAssertEqual(TranscriptLocale.merged(existing: "es", entryHadText: false, segment: "en-US"), "en-US")
    }

    func testSameLanguageKeepsTheMoreSpecificTag() {
        XCTAssertEqual(TranscriptLocale.merged(existing: "en", entryHadText: true, segment: "en-US"), "en-US")
        XCTAssertEqual(TranscriptLocale.merged(existing: "en-US", entryHadText: true, segment: "en"), "en-US")
        XCTAssertEqual(TranscriptLocale.merged(existing: "en-US", entryHadText: true, segment: "en-US"), "en-US")
    }

    func testTwoLanguagesInOneDayAreMul() {
        XCTAssertEqual(TranscriptLocale.merged(existing: "en-US", entryHadText: true, segment: "hi-IN"), "mul")
        XCTAssertEqual(TranscriptLocale.merged(existing: "mul", entryHadText: true, segment: "en-US"), "mul")
    }

    func testUndeterminedNeverOverrulesAKnownLanguage() {
        XCTAssertEqual(TranscriptLocale.merged(existing: "es-ES", entryHadText: true, segment: "und"), "es-ES")
        XCTAssertEqual(TranscriptLocale.merged(existing: "und", entryHadText: true, segment: "es-ES"), "es-ES")
    }

    func testNoSegmentLanguageLeavesTheEntryAlone() {
        XCTAssertEqual(TranscriptLocale.merged(existing: "fr", entryHadText: true, segment: nil), "fr")
        XCTAssertNil(TranscriptLocale.merged(existing: nil, entryHadText: false, segment: nil))
    }

    func testRecognizerLocaleIsStoredAsBCP47() {
        XCTAssertEqual(TranscriptLocale.tag(for: Locale(identifier: "en_US")), "en-US")
        XCTAssertEqual(TranscriptLocale.tag(for: Locale(identifier: "hi_IN")), "hi-IN")
        XCTAssertEqual(TranscriptLocale.language(of: "pt-BR"), "pt")
        XCTAssertEqual(TranscriptLocale.language(of: "en_IN"), "en")
    }

    // MARK: - B-1: reading a language from text

    func testDetectReadsTheLanguageOfLongEntries() {
        XCTAssertEqual(TranscriptLocale.detect("I feel so grateful today, everything went well at work and I'm happy."), "en")
        XCTAssertEqual(TranscriptLocale.detect("Hoy fue un día muy triste. Mi abuela murió esta mañana y no puedo dejar de llorar."), "es")
        XCTAssertEqual(TranscriptLocale.detect("Heute war ein sehr schöner Tag, ich bin dankbar für meine Familie und meine Freunde."), "de")
        XCTAssertEqual(TranscriptLocale.detect("आज मेरा दिन बहुत अच्छा था। मैं राम के साथ बाज़ार गया और हमने चाय पी।"), "hi")
    }

    func testDetectIsHonestAboutShortOrEmptyText() {
        XCTAssertNil(TranscriptLocale.detect(""))
        XCTAssertNil(TranscriptLocale.detect("   \n"))
        // Two words is too little to store a language as fact.
        XCTAssertEqual(TranscriptLocale.detect("Gracias amigo"), "und")
    }

    func testDetectAgreesWithEntryLanguage() {
        // Wherever the English-only readers stay quiet, the stored language
        // is not English either.
        let samples = [
            "Hoy me siento muy feliz y agradecido, todo salió bien en el trabajo con mis amigos.",
            "Aujourd'hui je me sens très reconnaissant, tout s'est bien passé au travail avec mes amis.",
            "இன்று நான் மிகவும் மகிழ்ச்சியாக இருக்கிறேன். என் அம்மாவுடன் கோவிலுக்கு சென்றேன்.",
        ]
        for text in samples {
            XCTAssertFalse(EntryLanguage.isEnglish(text))
            XCTAssertNotEqual(TranscriptLocale.detect(text), "en", text)
        }
    }

    func testNoteLanguageUsesTheRecognizerOverTheText() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let entry = DiaryEntry(context: context)
        // The recogniser that heard it is the fact, whatever the text looks like.
        entry.noteLanguage(ofAppended: "ok", recognizerLocale: Locale(identifier: "hi_IN"), entryHadText: false)
        XCTAssertEqual(entry.transcriptLocale, "hi-IN")
        // A typed English segment the same day makes it a two-language day.
        entry.noteLanguage(ofAppended: "Long day at work, but a lovely dinner with my family afterwards.",
                           recognizerLocale: nil, entryHadText: true)
        XCTAssertEqual(entry.transcriptLocale, "mul")
    }

    // MARK: - B-1: backfill

    func testBackfillFillsOnlyEntriesWithWordsAndNoLanguage() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        func make(_ text: String?, locale: String? = nil) -> DiaryEntry {
            let e = DiaryEntry(context: context)
            e.id = UUID(); e.date = Date(); e.text = text; e.transcriptLocale = locale
            return e
        }
        let english = make("Coffee with Priya before work, then a long walk by the lake in the evening.")
        let spanish = make("Hoy fue un día muy triste. Mi abuela murió esta mañana y no puedo dejar de llorar.")
        let recorded = make("Hoy fue un buen día.", locale: "es-MX")
        let empty = make("")
        let audioOnly = make(nil)
        try context.save()

        XCTAssertEqual(TranscriptLocale.backfill(in: context), 2)
        XCTAssertEqual(english.transcriptLocale, "en")
        XCTAssertEqual(spanish.transcriptLocale, "es")
        XCTAssertEqual(recorded.transcriptLocale, "es-MX", "a recogniser's tag is never overwritten")
        XCTAssertNil(empty.transcriptLocale, "no words, nothing to read")
        XCTAssertNil(audioOnly.transcriptLocale)

        // Once per entry: a second launch has nothing to do.
        XCTAssertEqual(TranscriptLocale.backfill(in: context), 0)
    }

    // MARK: - B-1: backups

    func testBackupCarriesTheLanguageAndOldBackupsStillDecode() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let entry = DiaryEntry(context: context)
        entry.id = UUID(); entry.date = Date(); entry.createdAt = Date(); entry.updatedAt = Date()
        entry.text = "Hola"; entry.transcriptLocale = "es-ES"

        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(ExportableEntry(from: entry))
        XCTAssertEqual(try decoder.decode(ExportableEntry.self, from: data).transcriptLocale, "es-ES")

        // A 1.13 backup has no such key.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "transcriptLocale")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(ExportableEntry.self, from: old)
        XCTAssertNil(decoded.transcriptLocale)
        XCTAssertEqual(decoded.text, "Hola")
    }

    // MARK: - B-6: Language you speak

    func testAutomaticIsExactlyTheOneThreeOneRule() {
        XCTAssertNil(SpeakingLanguage.chosenIdentifier)
        // No choice made: the resolver every recogniser uses is unchanged.
        XCTAssertEqual(SpeechTranscriber.speakerLocale.identifier,
                       SpeechTranscriber.automaticSpeakerLocale.identifier)
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(SpeakingLanguage.resolve(chosen: nil, automatic: english), english)
        XCTAssertEqual(SpeakingLanguage.resolve(chosen: "", automatic: english), english)
    }

    func testAChoiceWinsOverThePhoneLanguage() {
        SpeakingLanguage.chosenIdentifier = "hi-IN"
        XCTAssertEqual(SpeakingLanguage.chosenIdentifier, "hi-IN")
        XCTAssertEqual(SpeechTranscriber.speakerLocale.identifier, "hi-IN")
        // And the recogniser candidates follow it: Hindi only, never en-US.
        let candidates = SpeechTranscriber.candidateLocales(for: SpeechTranscriber.speakerLocale).map(\.identifier)
        XCTAssertFalse(candidates.contains("en-US"))
        XCTAssertEqual(SpeechTranscriber.noRecognizerError(for: SpeechTranscriber.speakerLocale),
                       .onDeviceUnavailable)

        SpeakingLanguage.chosenIdentifier = nil
        XCTAssertNil(UserDefaults.standard.object(forKey: SpeakingLanguage.defaultsKey))
        XCTAssertEqual(SpeechTranscriber.speakerLocale.identifier,
                       SpeechTranscriber.automaticSpeakerLocale.identifier)
    }

    func testMergeKeepsOneRowPerLanguageAndTheBestEngine() {
        let options = SpeakingLanguage.merge(
            analyzer: [(Locale(identifier: "en_US"), installed: true),
                       (Locale(identifier: "es_ES"), installed: false)],
            dictation: [(Locale(identifier: "en_US"), installed: false),
                        (Locale(identifier: "hi_IN"), installed: false),
                        (Locale(identifier: "es_ES"), installed: true)],
            legacyOnDevice: [Locale(identifier: "hi_IN"), Locale(identifier: "ja_JP")],
            display: Locale(identifier: "en_US"))

        XCTAssertEqual(options.map(\.identifier), ["en-US", "hi-IN", "ja-JP", "es-ES"],
                       "one row per tag, sorted by English name")
        let byID = Dictionary(uniqueKeysWithValues: options.map { ($0.identifier, $0) })
        XCTAssertEqual(byID["en-US"]?.engine, .speechAnalyzer)
        XCTAssertEqual(byID["en-US"]?.installed, true)
        // Spanish: SpeechAnalyzer is preferred; installed if any engine has it.
        XCTAssertEqual(byID["es-ES"]?.engine, .speechAnalyzer)
        XCTAssertEqual(byID["es-ES"]?.installed, true)
        // Hindi: dictation beats the legacy recogniser, and the legacy
        // recogniser's on-device support means it is already usable.
        XCTAssertEqual(byID["hi-IN"]?.engine, .dictation)
        XCTAssertEqual(byID["hi-IN"]?.installed, true)
        XCTAssertEqual(byID["ja-JP"]?.engine, .legacyOnDevice)
    }

    func testMergeOffersNothingTheFrameworksDidNotReport() {
        // Tamil has no Apple on-device recogniser. Nothing reports it, so
        // nothing offers it: the picker cannot promise what the phone can't hear.
        let options = SpeakingLanguage.merge(analyzer: [], dictation: [],
                                             legacyOnDevice: [Locale(identifier: "en_US")],
                                             display: Locale(identifier: "en_US"))
        XCTAssertEqual(options.map(\.identifier), ["en-US"])
        XCTAssertNil(SpeakingLanguage.option(for: Locale(identifier: "ta_IN"), in: options))
    }

    func testOptionMatchingForTheCurrentLocale() {
        let options = SpeakingLanguage.merge(
            analyzer: [(Locale(identifier: "en_US"), installed: true), (Locale(identifier: "de_DE"), installed: true)],
            dictation: [], legacyOnDevice: [], display: Locale(identifier: "en_US"))
        XCTAssertEqual(SpeakingLanguage.option(for: Locale(identifier: "en_US"), in: options)?.identifier, "en-US")
        XCTAssertEqual(SpeakingLanguage.option(for: Locale(identifier: "de_AT"), in: options)?.identifier, "de-DE",
                       "same language when the region has no model of its own")
    }

    func testPickerCopyNamesTheLanguage() {
        let hindi = Locale(identifier: "hi_IN")
        XCTAssertTrue(SpeakingLanguage.downloadCopy(for: hindi).contains(SpeakingLanguage.displayName(of: hindi)))
        XCTAssertTrue(SpeakingLanguage.cannotTranscribeCopy(for: hindi).contains("Your recording is saved"))
        XCTAssertFalse(SpeakingLanguage.explainerCopy.isEmpty)
    }

    // MARK: - B-7: which iOS 26 module transcribes

    /// Records which lookups the router made.
    private final class Lookups: @unchecked Sendable {
        var transcriber: [String] = []
        var dictation: [String] = []
    }

    private func route(_ speaker: String, transcriber: Set<String>, dictation: Set<String>,
                       lookups: Lookups = Lookups()) async -> SpeechTranscriber.AnalyzerRoute? {
        await SpeechTranscriber.analyzerRoute(
            for: Locale(identifier: speaker),
            transcriberLocale: { locale in
                let id = locale.identifier(.bcp47)
                lookups.transcriber.append(id)
                return transcriber.contains(id) ? Locale(identifier: id) : nil
            },
            dictationLocale: { locale in
                let id = locale.identifier(.bcp47)
                lookups.dictation.append(id)
                return dictation.contains(id) ? Locale(identifier: id) : nil
            })
    }

    func testEnglishRoutesExactlyAsBefore() async {
        let lookups = Lookups()
        let r = await route("en_US", transcriber: ["en-US"], dictation: ["en-US"], lookups: lookups)
        XCTAssertEqual(r, .transcriber(Locale(identifier: "en-US")))
        XCTAssertEqual(lookups.dictation, [], "English never reaches the dictation route")

        // en-IN with only the base model: the 1.13.1 en-US fallback, still.
        let lookups2 = Lookups()
        let r2 = await route("en_IN", transcriber: ["en-US"], dictation: ["en-IN"], lookups: lookups2)
        XCTAssertEqual(r2, .transcriber(Locale(identifier: "en-US")))
        XCTAssertEqual(lookups2.transcriber, ["en-IN", "en-US"])
        XCTAssertEqual(lookups2.dictation, [])

        // No English model at all: nil, so the legacy recogniser tries, as before.
        let r3 = await route("en_GB", transcriber: [], dictation: ["en-GB"])
        XCTAssertNil(r3)
    }

    func testHindiGoesToDictationNotLegacy() async {
        let lookups = Lookups()
        let r = await route("hi_IN", transcriber: ["en-US", "es-ES"], dictation: ["hi-IN"], lookups: lookups)
        XCTAssertEqual(r, .dictation(Locale(identifier: "hi-IN")))
        XCTAssertFalse(lookups.transcriber.contains("en-US"), "never asks for an English model on a Hindi speaker's behalf")
    }

    func testSpanishPrefersSpeechTranscriber() async {
        let r = await route("es_ES", transcriber: ["es-ES"], dictation: ["es-ES"])
        XCTAssertEqual(r, .transcriber(Locale(identifier: "es-ES")))
    }

    func testAnUnheardLanguageGetsNoRouteAndNoEnglish() async {
        let lookups = Lookups()
        let r = await route("ta_IN", transcriber: ["en-US"], dictation: ["en-US", "hi-IN"], lookups: lookups)
        XCTAssertNil(r)
        XCTAssertEqual(lookups.transcriber, ["ta-IN"])
        XCTAssertEqual(lookups.dictation, ["ta-IN"])
    }

    func testDictationSegmentsJoinWithoutGluingWords() {
        XCTAssertEqual(SpeechTranscriber.joinSegments(["आज मेरा दिन", "बहुत अच्छा था।"]), "आज मेरा दिन बहुत अच्छा था।")
        XCTAssertEqual(SpeechTranscriber.joinSegments(["Hello ", "world"]), "Hello world")
        XCTAssertEqual(SpeechTranscriber.joinSegments(["Hello", " world", ""]), "Hello world")
        XCTAssertEqual(SpeechTranscriber.joinSegments([]), "")
    }

    func testFinishClosesSentencesAsBeforeAndRespectsTheDanda() throws {
        // English: the rule the app always had.
        XCTAssertEqual(try SpeechTranscriber.finish("  I went for a walk  "), "I went for a walk.")
        XCTAssertEqual(try SpeechTranscriber.finish("Was it good?"), "Was it good?")
        XCTAssertEqual(try SpeechTranscriber.finish("It was."), "It was.")
        // Hindi already ended its sentence.
        XCTAssertEqual(try SpeechTranscriber.finish("बहुत अच्छा था।"), "बहुत अच्छा था।")
        XCTAssertThrowsError(try SpeechTranscriber.finish("   "))
    }
}
