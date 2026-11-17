//
//  TranslationLoadTests.swift
//  solynTests
//
//  iOS 1.14 translations (plan section 4 Phase C, section 5). The catalog
//  values are machine drafts awaiting native review, so this does not judge
//  wording. It checks the built app carries each language, that a handful of
//  key strings resolve to a translation, and that their placeholders format
//  with real arguments, reordered or not, without crashing or leaking a raw
//  "%" conversion onto the screen.
//
//  Hindi sits in its own commit so it can be dropped if the real-device probe
//  fails; when hi.lproj is absent the Hindi cases are skipped, not failed.
//

import XCTest
@testable import solyn

final class TranslationLoadTests: XCTestCase {

    /// Languages that must be in the build.
    private static let required = ["de", "es", "fr", "it", "pt-BR"]
    /// Languages checked only when present (gated on the device probe).
    private static let optional = ["hi"]

    private static let missing = "<missing>"

    private func lproj(_ lang: String) -> Bundle? {
        Bundle.main.path(forResource: lang, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    private func languages() throws -> [(String, Bundle)] {
        var out: [(String, Bundle)] = []
        for lang in Self.required {
            out.append((lang, try XCTUnwrap(lproj(lang), "\(lang).lproj is not in the app bundle")))
        }
        for lang in Self.optional {
            if let bundle = lproj(lang) { out.append((lang, bundle)) }
        }
        return out
    }

    /// Five strings from busy screens, with the arguments the app passes and
    /// what each argument must look like once formatted.
    private struct Case {
        let key: String
        let args: [CVarArg]
        let expect: [String]
    }

    private let cases: [Case] = [
        // Journal month header: one string argument.
        Case(key: "1 entry · %@ words", args: ["128"], expect: ["128"]),
        // Twin Patterns: three arguments that most languages reorder.
        Case(key: "%@ against your %@ average, across %lld entries.",
             args: ["+0.21", "-0.05", Int64(7)], expect: ["+0.21", "-0.05", "7"]),
        // Stats, Body & Mood: two integers then a string.
        Case(key: "Morning rhythm (HRV) averaged %lld ms on brighter days and %lld ms on dimmer ones — %@.",
             args: [Int64(62), Int64(48), "steady"], expect: ["62", "48", "steady"]),
        // Journal: an integer and a string.
        Case(key: "%lld entries · %@ words", args: [Int64(3), "512"], expect: ["3", "512"]),
        // Today header: inflection markup around two counts.
        Case(key: "^[%lld entry](inflect: true) · ^[%lld day](inflect: true) spoken",
             args: [Int64(2), Int64(5)], expect: ["2", "5"]),
    ]

    func testKeyStringsResolveAndFormatInEveryLanguage() throws {
        for (lang, bundle) in try languages() {
            let locale = Locale(identifier: lang)
            for c in cases {
                let value = bundle.localizedString(forKey: c.key, value: Self.missing, table: nil)
                XCTAssertNotEqual(value, Self.missing, "[\(lang)] \(c.key) is not in the catalog")
                XCTAssertNotEqual(value, c.key, "[\(lang)] \(c.key) is still English")
                let shown = String(format: value, locale: locale, arguments: c.args)
                XCTAssertFalse(shown.isEmpty, "[\(lang)] \(c.key)")
                for piece in c.expect {
                    XCTAssertTrue(shown.contains(piece), "[\(lang)] \(c.key): \(shown) lacks \(piece)")
                }
                // No conversion left unfilled: every % that remains is a literal one.
                XCTAssertNil(shown.range(of: #"%(\d+\$)?(ll)?[@dD]"#, options: .regularExpression),
                             "[\(lang)] \(c.key): \(shown)")
            }
        }
    }

    func testPermissionPromptsAreTranslated() throws {
        for (lang, bundle) in try languages() {
            for key in ["NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"] {
                let value = bundle.localizedString(forKey: key, value: Self.missing, table: "InfoPlist")
                XCTAssertNotEqual(value, Self.missing, "[\(lang)] \(key)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "[\(lang)] \(key)")
            }
        }
    }

    /// Hindi is written in Devanagari (plan section 5), with Western digits.
    func testHindiIsDevanagariWithWesternDigits() throws {
        guard let bundle = lproj("hi") else { throw XCTSkip("hi.lproj is not in this build") }
        let value = bundle.localizedString(forKey: "%lld entries · %@ words", value: Self.missing, table: nil)
        XCTAssertNotEqual(value, Self.missing)
        let shown = String(format: value, locale: Locale(identifier: "hi"), arguments: [Int64(3), "512"])
        XCTAssertNotNil(shown.unicodeScalars.first { (0x0900...0x097F).contains($0.value) }, shown)
        XCTAssertNil(shown.unicodeScalars.first { (0x0966...0x096F).contains($0.value) },
                     "Devanagari digits in \(shown)")
    }
}
