//
//  DVFontTests.swift
//  solynTests
//
//  Guards FINAL-SPEC §8.2 — "no Roboto/SF anywhere; Nunito/Inter/DM Mono only".
//

import XCTest
import UIKit
@testable import solyn

/// A missing font does not crash, throw, or lay out differently — it silently
/// renders in San Francisco, which is precisely the state this app spent its
/// whole life in and which no other test would notice. Hence these.
final class DVFontTests: XCTestCase {

    func testAllThreeFacesResolve() {
        XCTAssertTrue(DVFont.isAvailable,
                      "Bundled faces did not register. Check UIAppFonts in Info.plist and that the .ttf files are in Copy Bundle Resources.")
    }

    func testFacesAreNotFallingBackToSystem() {
        for name in [DVFont.Face.nunito, DVFont.Face.inter, DVFont.Face.mono] {
            let font = UIFont(name: name, size: 17)
            XCTAssertNotNil(font, "\(name) is unavailable")
            // UIFont(name:) returns nil rather than a substitute, but the
            // descriptor round-trip is what actually proves we did not get a
            // system face back through some other path.
            XCTAssertFalse(font?.familyName.contains("System") ?? true,
                           "\(name) resolved to a system face")
        }
    }

    /// The one that matters. Nunito ships with a DEFAULT weight of 200
    /// (ExtraLight) — if the `wght` variation axis is not being applied, every
    /// heading in the app renders hairline-thin and still passes every other
    /// check here.
    func testNunitoWeightAxisIsApplied() {
        let light = DVFont.nunito(40, .regular)
        let heavy = DVFont.nunito(40, .black)

        let attrsLight = light.fontDescriptor.fontAttributes
        let attrsHeavy = heavy.fontDescriptor.fontAttributes
        let key = kCTFontVariationAttribute as UIFontDescriptor.AttributeName
        XCTAssertNotNil(attrsLight[key], "no variation dictionary on the descriptor")
        XCTAssertNotEqual(
            attrsLight[key] as? [Int: CGFloat],
            attrsHeavy[key] as? [Int: CGFloat],
            "regular and black asked for the same axis value"
        )

        // And that the axis change reaches the rasteriser: heavier glyphs are
        // wider. Measured rather than assumed, because a descriptor can carry a
        // variation the font ignores.
        let sample = "Wednesday 42"
        let wLight = (sample as NSString).size(withAttributes: [.font: light]).width
        let wHeavy = (sample as NSString).size(withAttributes: [.font: heavy]).width
        XCTAssertGreaterThan(wHeavy, wLight,
                             "Nunito black is not wider than regular — the wght axis is not being applied")
    }

    func testInterWeightAxisIsApplied() {
        let sample = "Wednesday 42"
        let wRegular = (sample as NSString).size(withAttributes: [.font: DVFont.inter(24, .regular)]).width
        let wBold = (sample as NSString).size(withAttributes: [.font: DVFont.inter(24, .bold)]).width
        XCTAssertGreaterThan(wBold, wRegular,
                             "Inter bold is not wider than regular — the wght axis is not being applied")
    }

    /// DM Mono is the data face precisely because digits do not shift width
    /// between values — a timestamp that reflows as the seconds tick is the
    /// reason the spec names a mono face at all.
    func testMonoIsMonospaced() {
        let font = DVFont.mono(12)
        let one = ("1111111111" as NSString).size(withAttributes: [.font: font]).width
        let eight = ("8888888888" as NSString).size(withAttributes: [.font: font]).width
        XCTAssertEqual(one, eight, accuracy: 0.5, "DM Mono is not advancing uniformly")
    }
}
