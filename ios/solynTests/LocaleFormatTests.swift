//
//  LocaleFormatTests.swift
//  solynTests
//
//  iOS 1.14 core: B-12 locale formatting and B-16 script/RTL hygiene.
//  American English must read exactly as it did; other locales get their own
//  conventions.
//

import XCTest
import UIKit
import CoreText
@testable import solyn

final class LocaleFormatTests: XCTestCase {

    private let enUS = Locale(identifier: "en_US")
    private let utc = TimeZone(identifier: "UTC")!

    /// Dates that exercise one- and two-digit days, every weekday and both
    /// halves of the day.
    private var dates: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let comps: [(Int, Int, Int, Int, Int)] = [
            (2026, 10, 26, 22, 30), (2026, 1, 1, 0, 5), (2025, 12, 31, 12, 0),
            (2026, 2, 7, 9, 41), (2026, 6, 14, 18, 2), (2026, 3, 3, 7, 7), (2026, 9, 9, 13, 59),
        ]
        return comps.map {
            cal.date(from: DateComponents(year: $0.0, month: $0.1, day: $0.2, hour: $0.3, minute: $0.4))!
        }
    }

    private func fixed(_ format: String, _ date: Date) -> String {
        let f = DateFormatter()
        f.locale = enUS
        f.timeZone = utc
        f.dateFormat = format
        return f.string(from: date)
    }

    // MARK: - Dates: English unchanged

    func testAmericanEnglishDatesAreExactlyTheOldFixedFormats() {
        let pairs: [(template: String, old: String)] = [
            (LocaleFormat.weekdayMonthDay, "EEEE, MMMM d"),        // Today header, Markdown export
            (LocaleFormat.weekdayMonthDayYear, "EEEE, MMMM d, yyyy"), // Entry detail, PDF export
            (LocaleFormat.monthDayYear, "MMMM d, yyyy"),           // PDF cover, privacy receipt
            (LocaleFormat.shortMonthDay, "MMM d"),                  // Entry detail
            (LocaleFormat.monthYear, "LLLL yyyy"),                  // Timeline sections
            (LocaleFormat.monthYear, "MMMM yyyy"),                  // Markdown month headings
            (LocaleFormat.month, "MMMM"),                           // Settings
            (LocaleFormat.time, "h:mm a"),                          // PDF export
        ]
        for date in dates {
            for (template, old) in pairs {
                // The one byte that differs: CLDR puts a narrow no-break
                // space (U+202F) before AM/PM where the hand-written format
                // had a plain space. It renders the same, and it is what the
                // system clock itself uses.
                let new = LocaleFormat.date(date, template: template, locale: enUS, timeZone: utc)
                    .replacingOccurrences(of: "\u{202F}", with: " ")
                XCTAssertEqual(new, fixed(old, date), "\(template) vs \(old)")
            }
            // Stats strip: the first letter of the short weekday.
            XCTAssertEqual(LocaleFormat.date(date, template: LocaleFormat.narrowWeekday, locale: enUS, timeZone: utc),
                           String(fixed("EEE", date).prefix(1)))
        }
    }

    func testMarkdownMonthHeadingsStillParseBackForSorting() throws {
        let f = LocaleFormat.formatter(template: LocaleFormat.monthYear, locale: Locale(identifier: "de_DE"), timeZone: utc)
        let s = f.string(from: dates[0])
        let parsed = try XCTUnwrap(f.date(from: s))
        XCTAssertEqual(Calendar(identifier: .gregorian).dateComponents(in: utc, from: parsed).month, 10)
    }

    // MARK: - Dates: other locales in their own order

    func testGermanAndFrenchReadTheirOwnWay() {
        let date = dates[0]
        XCTAssertEqual(LocaleFormat.date(date, template: LocaleFormat.weekdayMonthDay,
                                         locale: Locale(identifier: "de_DE"), timeZone: utc), "Montag, 26. Oktober")
        XCTAssertEqual(LocaleFormat.date(date, template: LocaleFormat.weekdayMonthDay,
                                         locale: Locale(identifier: "fr_FR"), timeZone: utc), "lundi 26 octobre")
        XCTAssertEqual(LocaleFormat.date(date, template: LocaleFormat.time,
                                         locale: Locale(identifier: "de_DE"), timeZone: utc), "22:30")
    }

    func testBritishEnglishPutsTheDayFirst() {
        // The one visible change for English: en_GB/en_IN read the way they
        // write, not the American way.
        XCTAssertEqual(LocaleFormat.date(dates[0], template: LocaleFormat.weekdayMonthDay,
                                         locale: Locale(identifier: "en_GB"), timeZone: utc), "Monday 26 October")
    }

    func testMachineFormatsIgnoreTheCalendar() {
        let f = LocaleFormat.posix("yyyy-MM-dd")
        f.timeZone = utc
        XCTAssertEqual(f.string(from: dates[0]), "2026-10-26")
        XCTAssertEqual(f.calendar.identifier, .gregorian)
        XCTAssertEqual(f.locale.identifier, "en_US_POSIX")
    }

    // MARK: - Numbers

    func testAmericanEnglishDecimalsMatchStringFormat() {
        let values: [Double] = [0, 0.04, 0.05, 0.15, 0.25, 0.42, 1, 1.25, 1.5, 2.349, 7.25, 12.75, 1234.5,
                                -0.42, -0.5, -1.25, -3.14159, 2.5, 0.995]
        for v in values {
            XCTAssertEqual(LocaleFormat.decimal(v, fractionDigits: 1, locale: enUS), String(format: "%.1f", v), "\(v)")
            XCTAssertEqual(LocaleFormat.decimal(v, fractionDigits: 2, locale: enUS), String(format: "%.2f", v), "\(v)")
            XCTAssertEqual(LocaleFormat.decimal(v, fractionDigits: 1, signed: true, locale: enUS),
                           String(format: "%+.1f", v), "\(v)")
            XCTAssertEqual(LocaleFormat.decimal(v, fractionDigits: 2, signed: true, locale: enUS),
                           String(format: "%+.2f", v), "\(v)")
        }
    }

    func testAmericanEnglishPercentMatchesStringFormat() {
        for fraction in [0, 0.004, 0.42, 0.5, 0.999, 1] as [Double] {
            XCTAssertEqual(LocaleFormat.percent(fraction, locale: enUS), String(format: "%.0f%%", fraction * 100), "\(fraction)")
        }
    }

    func testOtherLocalesUseTheirOwnSeparator() {
        XCTAssertEqual(LocaleFormat.decimal(0.42, fractionDigits: 1, signed: true, locale: Locale(identifier: "de_DE")), "+0,4")
        XCTAssertEqual(LocaleFormat.decimal(1.5, fractionDigits: 1, locale: Locale(identifier: "fr_FR")), "1,5")
        XCTAssertEqual(LocaleFormat.decimal(1234.5, fractionDigits: 1, locale: Locale(identifier: "de_DE")), "1234,5",
                       "never grouped, as String(format:) never was")
    }

    // MARK: - Quotes

    func testQuotesFollowTheLocale() {
        XCTAssertEqual(LocaleFormat.quoted("hello", locale: enUS), "\u{201C}hello\u{201D}",
                       "English keeps the exact curly quotes it had")
        XCTAssertEqual(LocaleFormat.quoted("hallo", locale: Locale(identifier: "de_DE")), "\u{201E}hallo\u{201C}")
        XCTAssertEqual(LocaleFormat.quoted("salut", locale: Locale(identifier: "fr_FR")), "\u{00AB}salut\u{00BB}")
    }

    // MARK: - B-16: forward chevrons

    func testNoHardCodedRightChevrons() throws {
        // chevron.forward mirrors under a right-to-left layout; chevron.right
        // points into the text there.
        let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for folder in ["solyn", "SolynWidget"] {
            let dir = ios.appendingPathComponent(folder)
            let files = try XCTUnwrap(FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil))
            for case let url as URL in files where url.pathExtension == "swift" {
                let source = try String(contentsOf: url, encoding: .utf8)
                if source.contains("\"chevron.right\"") || source.contains("\"chevron.left\"") {
                    offenders.append(url.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    // MARK: - B-16: Devanagari falls back to a designed face, at weight

    private func fallbackFont(for text: String, in font: UIFont) -> CTFont {
        CTFontCreateForString(font as CTFont, text as CFString, CFRange(location: 0, length: (text as NSString).length))
    }

    func testLatinStillComesFromTheBundledFaces() {
        let inter = DVFont.inter(17, .regular)
        let latin = fallbackFont(for: "Wednesday", in: inter)
        XCTAssertEqual(CTFontCopyFamilyName(latin) as String, inter.familyName)
        XCTAssertTrue(DVFont.isAvailable)
    }

    func testDevanagariFallsBackToTheSystemDevanagariFace() {
        for font in [DVFont.inter(17, .regular), DVFont.nunito(28, .bold)] {
            let hindi = fallbackFont(for: "नमस्ते", in: font)
            let family = CTFontCopyFamilyName(hindi) as String
            XCTAssertTrue(family.localizedCaseInsensitiveContains("Devanagari"), family)
        }
    }

    func testDevanagariKeepsTheRequestedWeight() {
        let regular = fallbackFont(for: "नमस्ते", in: DVFont.nunito(28, .regular))
        let bold = fallbackFont(for: "नमस्ते", in: DVFont.nunito(28, .bold))
        func weight(_ f: CTFont) -> Double {
            let traits = CTFontCopyTraits(f) as NSDictionary
            return (traits[kCTFontWeightTrait] as? NSNumber)?.doubleValue ?? 0
        }
        XCTAssertGreaterThan(weight(bold), weight(regular),
                             "a bold heading in Hindi must not fall back to the regular face")
    }

    func testCascadeWeightMapping() {
        XCTAssertEqual(DVFont.uiWeight(axis: 400), .regular)
        XCTAssertEqual(DVFont.uiWeight(axis: 700), .bold)
        XCTAssertEqual(DVFont.uiWeight(axis: 600), .semibold)
        XCTAssertEqual(DVFont.cascade(weight: 700).count, DVFont.nonLatinFamilies.count)
    }
}
