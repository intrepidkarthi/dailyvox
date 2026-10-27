//
//  StringExtractionTests.swift
//  solynTests
//
//  iOS 1.14 strings, part B (plan B-14). The rest of the user-facing English
//  moved into the catalog. Same rule as part A: the English must read exactly
//  as it did, character for character, so every assertion compares against the
//  literal the code used to carry.
//

import XCTest
@testable import solyn

final class StringExtractionTests: XCTestCase {

    /// The strings resolve through the app's catalog; these checks pin the
    /// English, so they only mean something when the app runs in English.
    private func requireEnglish() throws {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        try XCTSkipUnless(lang.hasPrefix("en"), "app is running in \(lang), not English")
    }

    // MARK: - Enum names that used to be raw values

    func testExportFormatNamesAndLinesAreTheOldLiterals() throws {
        try requireEnglish()
        for format in ExportFormat.allCases {
            // Was `Text(format.rawValue)`.
            XCTAssertEqual(format.title, format.rawValue)
        }
        XCTAssertEqual(ExportFormat.json.description, "Full backup of your entries. Can be imported back.")
        XCTAssertEqual(ExportFormat.text.description, "Simple readable format for archiving.")
        XCTAssertEqual(ExportFormat.markdown.description, "Formatted text for notes apps.")
        XCTAssertEqual(ExportFormat.csv.description, "Spreadsheet format for analysis.")
        XCTAssertEqual(ExportFormat.pdf.description, "Beautiful formatted document.")
        XCTAssertEqual(ExportFormat.encryptedBackup.description,
                       "Password-protected backup, including your Body Twin's health data \u{2014} the only export that carries it.")
    }

    func testJournalChipsAndLifeAreasAreTheOldLiterals() throws {
        try requireEnglish()
        for filter in JournalFilter.allCases {
            XCTAssertEqual(filter.title, filter.rawValue)
        }
        for area in LifeArea.allCases {
            XCTAssertEqual(area.title, area.rawValue)
        }
    }

    func testJournalMoodChipStaysLowerCase() throws {
        try requireEnglish()
        // The mood filter chips showed the raw value, which is lower case.
        for mood in Mood.allCases where mood != .none {
            XCTAssertEqual(mood.displayName.lowercased(), mood.rawValue)
        }
    }

    func testSelfLabelEmotionsAreTheOldLiterals() throws {
        try requireEnglish()
        for emotion in SelfLabelEmotion.allCases {
            XCTAssertEqual(emotion.displayName, emotion.rawValue.capitalized)
        }
    }

    func testBackupErrorsAreTheOldLiterals() throws {
        try requireEnglish()
        typealias E = EncryptionService.EncryptionError
        XCTAssertEqual(E.invalidData.errorDescription, "Data is invalid or corrupted.")
        XCTAssertEqual(E.invalidPassword.errorDescription, "Incorrect password.")
        XCTAssertEqual(E.decryptionFailed.errorDescription, "Failed to decrypt. Check your password.")
        XCTAssertEqual(E.invalidFileFormat.errorDescription, "This file is not a valid DailyVox encrypted backup.")
    }

    @MainActor
    func testTwinResolutionQuestionsAreTheOldLiterals() throws {
        try requireEnglish()
        let old: [(String, String, String)] = [
            ("How do you tend to express yourself?", "Reserved", "Expressive"),
            ("When you say what you mean, you're usually\u{2026}", "Nuanced", "Direct"),
            ("You make sense of things more through\u{2026}", "Intuition", "Analysis"),
            ("Your thinking leans\u{2026}", "Concrete", "Abstract"),
            ("Your mind spends more time on\u{2026}", "The past", "The future"),
            ("When something goes wrong, you tend to feel you can\u{2026}", "Accept it", "Grow from it"),
            ("Across a week, your emotions are\u{2026}", "Steady", "Wide-ranging"),
        ]
        let questions = TwinResolutionManager.shared.questions
        XCTAssertEqual(questions.count, old.count)
        for (q, (prompt, low, high)) in zip(questions, old) {
            XCTAssertEqual(q.prompt, prompt)
            XCTAssertEqual(q.lowLabel, low)
            XCTAssertEqual(q.highLabel, high)
        }
    }

    // MARK: - Export files

    /// The text and Markdown exports carry their own headings; a thousand
    /// entries pins that the count is never grouped ("1000", not "1,000").
    func testTextAndMarkdownExportHeadingsAreTheOldLiterals() throws {
        try requireEnglish()
        let ctx = PersistenceController(inMemory: true).container.viewContext
        var entries: [DiaryEntry] = []
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        for i in 0..<1000 {
            let e = DiaryEntry(context: ctx)
            e.id = UUID(); e.date = day; e.createdAt = day; e.updatedAt = day
            e.text = i == 0 ? nil : "Entry \(i)"
            entries.append(e)
        }

        let text = try String(contentsOf: BackupService.shared.exportToText(entries: entries), encoding: .utf8)
        XCTAssertTrue(text.contains("\n                      DAILYVOX DIARY EXPORT\n"), "heading")
        XCTAssertTrue(text.contains("\nTotal Entries: 1000\n"), "count, never grouped")
        XCTAssertTrue(text.contains("\nExported: "))
        XCTAssertTrue(text.contains("\n(No text)\n"), "an entry with no words")
        XCTAssertTrue(text.contains("\n                      END OF EXPORT\n"), "ending")

        let md = try String(contentsOf: BackupService.shared.exportToMarkdown(entries: entries), encoding: .utf8)
        XCTAssertTrue(md.hasPrefix("# DailyVox Diary Export\n\n**Exported:** "))
        XCTAssertTrue(md.contains("  \n**Total Entries:** 1000\n"), "the hard line break and the count")
        XCTAssertTrue(md.contains("\n(No text)\n"))
    }
}
