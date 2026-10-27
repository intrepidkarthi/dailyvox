//
//  StringPlumbingTests.swift
//  solynTests
//
//  iOS 1.14 strings, part A (plan B-14, B-12). The rule for this round: moving
//  a string into the catalog must not move a single character of the English.
//  Every assertion below compares against the literal the code used to carry.
//

import XCTest
import DailyVoxTwinEngine
@testable import solyn

final class StringPlumbingTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    /// The extracted strings resolve through the app's catalog, so the English
    /// checks mean something only when the app is running in English. The
    /// simulator the suite runs on is; a run in another language would see
    /// the existing de/es/fr/it translations, which is correct behaviour and
    /// not what these tests pin.
    private func requireEnglish() throws {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        try XCTSkipUnless(lang.hasPrefix("en"), "app is running in \(lang), not English")
    }

    // MARK: - English reads exactly as before

    func testMoodNamesAreTheOldLiterals() throws {
        try requireEnglish()
        let old: [Mood: String] = [
            .none: "No mood", .happy: "Happy", .calm: "Calm", .grateful: "Grateful",
            .excited: "Excited", .tired: "Tired", .anxious: "Anxious", .sad: "Sad", .angry: "Angry",
        ]
        for mood in Mood.allCases {
            XCTAssertEqual(mood.displayName, old[mood], "\(mood)")
        }
    }

    func testTabTitlesAreTheOldLiterals() throws {
        try requireEnglish()
        XCTAssertEqual(Destination.allCases.map(\.title), ["Speak", "Journal", "Twin", "Ask"])
    }

    func testTranscriptionErrorsAreTheOldLiterals() throws {
        try requireEnglish()
        typealias E = SpeechTranscriber.TranscriptionError
        XCTAssertEqual(E.notAuthorized.errorDescription, "Speech recognition is not authorized.")
        XCTAssertEqual(E.recognizerUnavailable.errorDescription, "Speech recognizer is not available.")
        XCTAssertEqual(E.noFinalResult.errorDescription, "No final transcription result.")
        XCTAssertEqual(E.onDeviceUnavailable.errorDescription,
                       "No on-device speech model is installed yet, so this one is saved as audio. Turn on Settings > General > Keyboard > Dictation and iOS will fetch the model once; every entry after that transcribes here. Tap Edit to write this one yourself. DailyVox will not transcribe over a network.")
    }

    func testMaturityAndThemeNamesAreTheOldLiterals() throws {
        try requireEnglish()
        let levels: [TwinSummary.TwinMaturity] = [.nascent, .emerging, .developing, .established, .deep]
        for level in levels {
            // Was `rawValue.capitalized`.
            XCTAssertEqual(level.displayName, level.rawValue.capitalized)
        }
        for theme in AppTheme.allCases {
            // Was `Text(theme.rawValue)`.
            XCTAssertEqual(theme.displayName, theme.rawValue)
        }
        for period in SettingsView.ExportPeriod.allCases {
            XCTAssertEqual(period.title, period.rawValue)
        }
    }

    func testShareCardCopyIsTheOldLiterals() throws {
        try requireEnglish()
        typealias Card = Shareables.Card
        let titles: [Card: String] = [
            .tonight: "Tonight", .mySky: "My Sky", .receipt: "Receipt", .yearOne: "Year One",
            .milestone: "Milestone", .wallpaper: "Wallpaper", .gift: "Gift a star", .body: "Body",
        ]
        for (card, title) in titles {
            XCTAssertEqual(card.title, title)
        }
        XCTAssertEqual(Card.receipt.caption, "Everything costs zero, itemised. It argues better than a feature list.")
        XCTAssertEqual(Card.tonight.caption,
                       "The one you made today, in the sky it landed in. A new place every night \u{2014} no words on it, ever.")
        XCTAssertEqual(Shareables.milestoneHeadline(365), "A year of showing up.")
        XCTAssertEqual(Shareables.milestoneHeadline(42), "Forty-two nights.")
        XCTAssertEqual(Shareables.milestoneHeadline(1), "One night.")
        XCTAssertEqual(Shareables.milestoneHeadline(7), "7 nights.")
        XCTAssertEqual(Shareables.milestoneHeadline(1000), "1000 nights.", "never grouped, as the interpolation never was")
        XCTAssertEqual(PersonalityCardRenderer.shareText,
                       "My Digital Twin personality from DailyVox \u{2014} free AI voice journal. getdailyvox.com")
    }

    func testUsageStringsAreTheOnesThatShipped() throws {
        try requireEnglish()
        // 1.13 shipped the build-setting copies of these two, not the
        // Info.plist ones; the plist now carries those, and the build
        // settings are gone so there is a single source.
        let shipped: [String: String] = [
            "NSMicrophoneUsageDescription": "DailyVox uses the microphone to record your diary entries.",
            "NSSpeechRecognitionUsageDescription": "DailyVox uses speech recognition to convert your recorded diary into text.",
            "NSFaceIDUsageDescription": "DailyVox uses Face ID to lock and unlock access to your private diary entries.",
        ]
        for (key, value) in shipped {
            XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: key) as? String, value, key)
        }
        let keys = ["NSAppleMusicUsageDescription", "NSFaceIDUsageDescription", "NSHealthShareUsageDescription",
                    "NSHealthUpdateUsageDescription", "NSMicrophoneUsageDescription", "NSMotionUsageDescription",
                    "NSPhotoLibraryUsageDescription", "NSSpeechRecognitionUsageDescription"]
        for key in keys {
            let raw = Bundle.main.infoDictionary?[key] as? String
            XCTAssertNotNil(raw, key)
            // What iOS actually shows: the localized value wins over the
            // plist. It must be the same English.
            if let localized = Bundle.main.localizedInfoDictionary?[key] as? String {
                XCTAssertEqual(localized, raw, key)
            }
        }
    }

    // MARK: - Formats English kept

    func testSleepHoursReadAsBefore() throws {
        try requireEnglish()
        for hours in [0.0, 5.5, 6.98, 7.0, 7.09, 8.25, 10.75] {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            XCTAssertEqual(LocaleFormat.sleepHours(hours), String(format: "%dh%02d", h, m), "\(hours)")
        }
    }

    func testReminderPresetTimesReadAsBeforeInAmericanEnglish() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let enUS = Locale(identifier: "en_US")
        XCTAssertEqual(LocaleFormat.clockTime(hour: 7, minute: 0, locale: enUS, calendar: cal), "7:00 AM")
        XCTAssertEqual(LocaleFormat.clockTime(hour: 12, minute: 30, locale: enUS, calendar: cal), "12:30 PM")
        XCTAssertEqual(LocaleFormat.clockTime(hour: 20, minute: 0, locale: enUS, calendar: cal), "8:00 PM")
    }

    func testPDFPeriodTitlesReadAsBeforeInAmericanEnglish() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let enUS = Locale(identifier: "en_US")
        let oct = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        XCTAssertEqual(LocaleFormat.date(oct, template: LocaleFormat.monthYear, locale: enUS, timeZone: utc), "October 2026")
        XCTAssertEqual(LocaleFormat.date(oct, template: LocaleFormat.quarterYear, locale: enUS, timeZone: utc), "Q4 2026")
        let jan = cal.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        XCTAssertEqual(LocaleFormat.date(jan, template: LocaleFormat.quarterYear, locale: enUS, timeZone: utc), "Q1 2027")
    }

    func testJournalRowWeekdayReadsAsBeforeInAmericanEnglish() {
        let enUS = Locale(identifier: "en_US")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let fixed = DateFormatter()
        fixed.locale = enUS
        fixed.timeZone = utc
        fixed.dateFormat = "EEE"
        for day in 19...25 {
            let date = cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 21))!
            XCTAssertEqual(LocaleFormat.date(date, template: LocaleFormat.shortWeekday, locale: enUS, timeZone: utc),
                           fixed.string(from: date))
        }
    }

    // MARK: - Other locales follow their own order

    func testHindiAndGermanPutTheDayBeforeTheMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 21))!
        for id in ["hi_IN", "de_DE"] {
            let locale = Locale(identifier: id)
            let s = LocaleFormat.date(date, template: LocaleFormat.weekdayMonthDay, locale: locale, timeZone: utc)
            let names = DateFormatter()
            names.locale = locale
            let month = names.monthSymbols[9]
            guard let day = s.range(of: "26"), let name = s.range(of: month) else {
                return XCTFail("\(id): \(s) lacks the day or \(month)")
            }
            XCTAssertLessThan(day.lowerBound, name.lowerBound, "\(id): \(s)")
        }
        // The reminder presets in German: the 24-hour clock, not "8:00 PM".
        XCTAssertEqual(LocaleFormat.clockTime(hour: 20, minute: 0, locale: Locale(identifier: "de_DE"), calendar: cal), "20:00")
        XCTAssertEqual(LocaleFormat.clockTime(hour: 7, minute: 0, locale: Locale(identifier: "de_DE"), calendar: cal), "07:00")
    }
}
