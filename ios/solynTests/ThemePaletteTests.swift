//
//  ThemePaletteTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// Every theme is a set of colours dropped into screens that were designed
/// once. These hold each set to the contrast those screens assume: text on
/// paper and on cards, white on the action colour (buttons do that
/// everywhere), gold text on cards, and the sky's text on the sky. High
/// contrast is held to AAA for its text.
final class ThemePaletteTests: XCTestCase {

    private func assertContrast(_ fg: UInt32, on bg: UInt32, atLeast min: Double,
                                _ what: String, _ theme: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let r = ContrastMath.ratio(fg, bg)
        XCTAssertGreaterThanOrEqual(r, min,
            "\(theme): \(what) is \(String(format: "%.2f", r)):1, needs \(min)",
            file: file, line: line)
    }

    func testEveryThemeIsReadable() {
        var sets: [(String, ThemePalette, Double)] = ThemeID.allCases.map {
            ($0.displayName, $0.palette, $0 == .highContrast ? 7 : 4.5)
        }
        sets.append(("High contrast (night)", .highContrastNight, 7))

        for (name, p, text) in sets {
            assertContrast(p.ink, on: p.ivory, atLeast: text, "ink on paper", name)
            assertContrast(p.ink, on: p.ivory2, atLeast: text, "ink on card", name)
            assertContrast(p.inkSoft, on: p.ivory2, atLeast: 4.5, "soft ink on card", name)
            assertContrast(p.navyText, on: p.navy, atLeast: text, "sky text on sky", name)
            assertContrast(p.navyText, on: p.navySurface, atLeast: 4.5, "sky text on sky card", name)
            assertContrast(0xFFFFFF, on: p.sage, atLeast: 4.5, "white on action colour", name)
            assertContrast(p.sage, on: p.ivory2, atLeast: 3, "action colour on card", name)
            assertContrast(p.goldDay, on: p.ivory2, atLeast: 4.5, "gold text on card", name)
            assertContrast(p.sagePositive, on: p.ivory2, atLeast: 4.5, "positive text on card", name)
        }
    }

    /// The default theme is the app as it shipped; it must not drift.
    func testDefaultIsTheShippedPalette() {
        let p = ThemeID.standard.palette
        XCTAssertEqual(p.ivory, 0xF7F3EA)
        XCTAssertEqual(p.sage, 0x2E5B44)
        XCTAssertEqual(p.gold, 0xD9A441)
        XCTAssertEqual(p.navy, 0x101B2D)
        XCTAssertEqual(p.coral, 0xD44F45)
    }

    /// Theme IDs are a save format.
    func testStoredNamesAreStable() {
        XCTAssertEqual(ThemeID.standard.rawValue, "default")
        XCTAssertEqual(ThemeID(rawValue: "monsoon"), .monsoon)
        XCTAssertEqual(ThemeID.allCases.count, 19)
        XCTAssertEqual(ThemeGroup.allCases.flatMap(\.themes).count, ThemeID.allCases.count)
    }

    /// Mood colours are a record, not decoration: they do not follow the theme.
    func testMoodColoursIgnoreTheTheme() {
        XCTAssertEqual(Mood.calm.color, DS.Brand.forest)
        XCTAssertEqual(Mood.happy.color, DS.Brand.gold)
        XCTAssertEqual(Mood.angry.color, DS.Brand.coral)
    }

    /// Old appearance values still decode to the look they meant.
    func testOldAppearanceValuesDecode() {
        XCTAssertEqual(AppTheme.decode("Ivory"), .day)
        XCTAssertEqual(AppTheme.decode("Light"), .day)
        XCTAssertEqual(AppTheme.decode("Dark"), .night)
        XCTAssertEqual(AppTheme.decode("Sunset"), .sunset)
        XCTAssertEqual(AppTheme.decode("system"), .sunset)
    }
}
