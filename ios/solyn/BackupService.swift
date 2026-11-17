//
//  BackupService.swift
//  solyn
//
//  Handles data backup and export functionality.
//  Supports JSON export/import and plain text export.
//  All data remains on-device or in user-controlled locations.
//

import Foundation
import CoreData
import UniformTypeIdentifiers
import DailyVoxTwinEngine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Backup Data Models

/// Represents a single diary entry for export/import
struct ExportableEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let text: String
    let mood: String?
    let isStarred: Bool
    let createdAt: Date
    let updatedAt: Date
    let audioFileName: String?
    let audioFileNames: String?
    let photoFileNames: String?
    /// Research-pilot self-label (7-class canon + intensity 1–3). Optional so
    /// pre-existing backups decode unchanged and older builds ignore them.
    let selfLabelEmotion: String?
    let selfLabelIntensity: Int?
    /// The mood the app suggested from the words, so a restore still knows
    /// the mood is a suggestion and not the user's. Optional: older backups
    /// decode unchanged, and their moods were all chosen by hand.
    let suggestedMood: String?
    /// The language the words are in (BCP-47; "und"/"mul" allowed), as the
    /// recogniser or the backfill recorded it. Optional: older backups
    /// decode unchanged and the launch backfill reads their language.
    let transcriptLocale: String?

    init(from entry: DiaryEntry) {
        self.id = entry.id ?? UUID()
        self.date = entry.date ?? Date()
        self.text = entry.text ?? ""
        self.mood = entry.value(forKey: "mood") as? String
        self.isStarred = entry.isStarred
        self.createdAt = entry.createdAt ?? Date()
        self.updatedAt = entry.updatedAt ?? Date()
        self.audioFileName = entry.audioFileName
        self.audioFileNames = entry.value(forKey: "audioFileNames") as? String
        self.photoFileNames = entry.value(forKey: "photoFileNames") as? String
        self.selfLabelEmotion = entry.value(forKey: "selfLabelEmotion") as? String
        let intensity = entry.value(forKey: "selfLabelIntensity") as? Int16 ?? 0
        self.selfLabelIntensity = intensity > 0 ? Int(intensity) : nil
        self.suggestedMood = entry.suggestedMood
        self.transcriptLocale = entry.transcriptLocale
    }
}

/// Body Twin data carried ONLY by the encrypted .dvx backup (format 1.1).
/// Health signals never ride the plain JSON export — the password-protected
/// file is the single way they leave this iPhone, user-initiated and
/// user-held key. See BodyTwinStores.swift for the gathering side.
struct ExportableBodyTwin: Codable {
    let state: BodyTwin?
    let keptSnapshots: [KeptSnapshot]
    let pendingSnapshots: [PendingSnapshot]

    var isEmpty: Bool { state == nil && keptSnapshots.isEmpty && pendingSnapshots.isEmpty }
}

/// Container for full backup data
struct BackupData: Codable {
    let version: String
    let exportDate: Date
    let deviceName: String
    let entryCount: Int
    let entries: [ExportableEntry]
    /// Optional so 1.0 backups decode unchanged and older app builds ignore it.
    let bodyTwin: ExportableBodyTwin?

    init(entries: [ExportableEntry], bodyTwin: ExportableBodyTwin? = nil) {
        self.version = bodyTwin == nil ? "1.0" : "1.1"
        self.exportDate = Date()
        #if canImport(UIKit)
        self.deviceName = UIDevice.current.name
        #else
        self.deviceName = Host.current().localizedName ?? "Mac"  // i18n-ignore: macOS build only
        #endif
        self.entryCount = entries.count
        self.entries = entries
        self.bodyTwin = bodyTwin
    }
}

// MARK: - Backup Service

final class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    // MARK: - JSON Export
    
    /// Export all entries to JSON format
    func exportToJSON(entries: [DiaryEntry]) throws -> URL {
        let exportableEntries = entries.map { ExportableEntry(from: $0) }
        let backupData = BackupData(entries: exportableEntries)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(backupData)
        
        // Create temp file
        let fileName = "dailyvox_backup_\(formattedDate()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try jsonData.write(to: tempURL)
        
        return tempURL
    }
    
    /// Export selected entries to JSON
    func exportToJSON(entries: [DiaryEntry], startDate: Date?, endDate: Date?, starredOnly: Bool) throws -> URL {
        var filteredEntries = entries
        
        if let start = startDate {
            filteredEntries = filteredEntries.filter { ($0.date ?? Date.distantPast) >= start }
        }
        
        if let end = endDate {
            filteredEntries = filteredEntries.filter { ($0.date ?? Date.distantFuture) <= end }
        }
        
        if starredOnly {
            filteredEntries = filteredEntries.filter { $0.isStarred }
        }
        
        return try exportToJSON(entries: filteredEntries)
    }

    // MARK: - Research Export (dailyvox-research-export/1)

    /// Export ONLY self-labelled entries in the shared cross-platform format
    /// (ResearchExport.swift has the shape and the reasons for it).
    /// User-initiated share only — this file is handed to the share sheet
    /// and goes wherever the participant chooses to send it.
    func exportResearchJSON(entries: [DiaryEntry]) throws -> URL {
        // A row with no date or no id is left out rather than patched. A
        // missing date used to become year 0001, which sorted first and
        // silently joined the participant's adaptation entries; a missing id
        // became a fresh UUID on every export, so two exports of the same
        // journal never matched. Both are rare (pre-1.0 restores) and neither
        // is a row the analysis can place in time.
        let rows: [ResearchExportV1.Row] = entries.compactMap { entry in
            guard let id = entry.id, let when = entry.createdAt ?? entry.date else { return nil }
            let audio = AudioFileList.parse(entry.value(forKey: "audioFileNames") as? String,
                                            legacy: entry.value(forKey: "audioFileName") as? String)
            return ResearchExportV1.Row(
                id: id,
                // createdAt is when the day's entry was first spoken; `date`
                // is the same instant on every creation path and is the
                // fallback for rows restored from a backup that lacked it.
                createdAt: when,
                text: entry.text ?? "",
                selfLabel: entry.value(forKey: "selfLabelEmotion") as? String,
                hasAudio: !audio.isEmpty,
                duration: entry.duration
            )
        }

        #if canImport(UIKit)
        let model = UIDevice.current.model
        let osVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        let model = "Mac"  // i18n-ignore: macOS build only
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let export = ResearchExportV1.build(
            rows: rows,
            participantCode: ResearchParticipant.code(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            osVersion: osVersion,
            deviceModel: model
        )
        let data = try ResearchExportV1.encode(export)

        let fileName = "dailyvox_research_\(formattedDate()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }

    // MARK: - JSON Import
    
    /// Import entries from JSON backup
    func importFromJSON(url: URL, context: NSManagedObjectContext) throws -> Int {
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backupData = try decoder.decode(BackupData.self, from: data)
        
        var importedCount = 0
        
        for exportedEntry in backupData.entries {
            // Check if entry already exists
            let fetchRequest: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", exportedEntry.id as CVarArg)
            
            let existingEntries = try context.fetch(fetchRequest)
            
            if existingEntries.isEmpty {
                // Create new entry
                let newEntry = DiaryEntry(context: context)
                newEntry.id = exportedEntry.id
                newEntry.date = exportedEntry.date
                newEntry.text = exportedEntry.text
                newEntry.setValue(exportedEntry.mood, forKey: "mood")
                newEntry.isStarred = exportedEntry.isStarred
                newEntry.createdAt = exportedEntry.createdAt
                newEntry.updatedAt = exportedEntry.updatedAt
                newEntry.audioFileName = exportedEntry.audioFileName
                newEntry.setValue(exportedEntry.audioFileNames, forKey: "audioFileNames")
                newEntry.setValue(exportedEntry.photoFileNames, forKey: "photoFileNames")
                newEntry.setValue(exportedEntry.selfLabelEmotion, forKey: "selfLabelEmotion")
                newEntry.setValue(Int16(exportedEntry.selfLabelIntensity ?? 0), forKey: "selfLabelIntensity")
                newEntry.suggestedMood = exportedEntry.suggestedMood
                newEntry.transcriptLocale = exportedEntry.transcriptLocale

                importedCount += 1
            }
        }

        if importedCount > 0 {
            try context.save()
        }

        return importedCount
    }

    // MARK: - Plain Text Export
    
    /// Export entries to plain text format
    func exportToText(entries: [DiaryEntry]) throws -> URL {
        let heading = String(localized: "DAILYVOX DIARY EXPORT", comment: "Export file (plain text export): heading at the top of the .txt file, centred between rules of = signs. Upper case. DailyVox is the app name. About 21 characters.")
        let exportedLine = String(localized: "Exported: \(formattedFullDate(Date()))", comment: "Export file (plain text export): line under the heading; the placeholder is today's date, already written out for the locale.")
        let totalLine = String(localized: "Total Entries: \(String(entries.count))", comment: "Export file (plain text export): line under the heading; the placeholder is the number of entries in the file. It arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
        var textContent = """
        ═══════════════════════════════════════════════════════════════
                              \(heading)
        ═══════════════════════════════════════════════════════════════
        
        \(exportedLine)
        \(totalLine)
        
        ═══════════════════════════════════════════════════════════════
        
        """
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        for entry in sortedEntries {
            let date = entry.date ?? Date()
            let text = entry.text ?? String(localized: "(No text)", comment: "Export file (plain text, Markdown and PDF exports): stands in for the body of an entry that has no words. Keep the parentheses.")
            let mood = moodLabel(of: entry)
            let starred = entry.isStarred ? " \u{2726}" : ""
            
            textContent += """
            ───────────────────────────────────────────────────────────────
            \(dateFormatter.string(from: date))\(starred)
            """
            
            if !mood.isEmpty {
                textContent += "\n" + String(localized: "Mood: \(mood)", comment: "Export file (plain text and PDF exports): line under an entry's date; the placeholder is the mood name, possibly followed by '(suggested)'.")
            }
            
            textContent += """
            
            ───────────────────────────────────────────────────────────────
            
            \(text)
            
            
            """
        }
        
        let ending = String(localized: "END OF EXPORT", comment: "Export file (plain text export): closing line at the bottom of the .txt file, centred between rules of = signs. Upper case. About 13 characters.")
        textContent += """
        ═══════════════════════════════════════════════════════════════
                              \(ending)
        ═══════════════════════════════════════════════════════════════
        """
        
        // Create temp file
        let fileName = "dailyvox_diary_\(formattedDate()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try textContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    /// Export selected entries to plain text
    func exportToText(entries: [DiaryEntry], startDate: Date?, endDate: Date?, starredOnly: Bool) throws -> URL {
        var filteredEntries = Array(entries)
        
        if let start = startDate {
            filteredEntries = filteredEntries.filter { ($0.date ?? Date.distantPast) >= start }
        }
        
        if let end = endDate {
            filteredEntries = filteredEntries.filter { ($0.date ?? Date.distantFuture) <= end }
        }
        
        if starredOnly {
            filteredEntries = filteredEntries.filter { $0.isStarred }
        }
        
        return try exportToText(entries: filteredEntries)
    }
    
    // MARK: - Markdown Export
    
    /// Export entries to Markdown format
    func exportToMarkdown(entries: [DiaryEntry]) throws -> URL {
        let mdTitle = String(localized: "DailyVox Diary Export", comment: "Export file (Markdown export): the document's title, a level-1 heading. DailyVox is the app name. About 21 characters.")
        let mdExported = String(localized: "Exported:", comment: "Export file (Markdown export): bold label before today's date under the title. Keep the colon.")
        let mdTotal = String(localized: "Total Entries:", comment: "Export file (Markdown export): bold label before the number of entries under the title. Keep the colon.")
        var mdContent = """
        # \(mdTitle)
        
        **\(mdExported)** \(formattedFullDate(Date()))  
        **\(mdTotal)** \(entries.count)
        
        ---
        
        """
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        // The reader's own month heading ("October 2026", "Oktober 2026"),
        // parsed back by the same formatter to order the months.
        let monthFormatter = LocaleFormat.formatter(template: LocaleFormat.monthYear)
        let groupedByMonth = Dictionary(grouping: sortedEntries) { entry -> String in
            monthFormatter.string(from: entry.date ?? Date())
        }

        let sortedMonths = groupedByMonth.keys.sorted { month1, month2 in
            let formatter = monthFormatter
            let date1 = formatter.date(from: month1) ?? Date()
            let date2 = formatter.date(from: month2) ?? Date()
            return date1 > date2
        }
        
        for month in sortedMonths {
            mdContent += "## \(month)\n\n"
            
            if let monthEntries = groupedByMonth[month] {
                for entry in monthEntries {
                    let date = entry.date ?? Date()
                    let text = entry.text ?? String(localized: "(No text)", comment: "Export file (plain text, Markdown and PDF exports): stands in for the body of an entry that has no words. Keep the parentheses.")
                    let mood = moodLabel(of: entry)
                    let starred = entry.isStarred ? " \u{2726}" : ""
                    
                    let day = LocaleFormat.date(date, template: LocaleFormat.weekdayMonthDay)
                    mdContent += "### \(day)\(starred)\n\n"
                    
                    if !mood.isEmpty {
                        mdContent += "**" + String(localized: "Mood:", comment: "Export file (Markdown export): bold label before an entry's mood. Keep the colon.") + "** \(mood)\n\n"
                    }
                    
                    mdContent += "\(text)\n\n---\n\n"
                }
            }
        }
        
        // Create temp file
        let fileName = "dailyvox_diary_\(formattedDate()).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try mdContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    // MARK: - CSV Export
    
    /// Export entries to CSV format
    func exportToCSV(entries: [DiaryEntry]) throws -> URL {
        var csvContent = "Date,Time,Mood,Starred,Word Count,Text\n"  // i18n-ignore: CSV column names, fixed for spreadsheets
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        // Machine-readable columns: fixed, whatever the reader's locale or
        // calendar, so a spreadsheet always parses them.
        let dateFormatter = LocaleFormat.posix("yyyy-MM-dd")
        let timeFormatter = LocaleFormat.posix("HH:mm")
        
        for entry in sortedEntries {
            let date = entry.date ?? Date()
            let text = (entry.text ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            // The raw value, as this column always held; a suggestion says so.
            let raw = entry.mood ?? ""
            let mood = entry.isMoodSuggested ? raw + " (suggested)" : raw
            let starred = entry.isStarred ? "Yes" : "No"  // i18n-ignore: CSV value, fixed for spreadsheets
            let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
            
            // Escape text for CSV
            let escapedText = "\"\(text.replacingOccurrences(of: "\n", with: " "))\""
            
            csvContent += "\(dateFormatter.string(from: date)),\(timeFormatter.string(from: date)),\(mood),\(starred),\(wordCount),\(escapedText)\n"
        }
        
        // Create temp file
        let fileName = "dailyvox_entries_\(formattedDate()).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    // MARK: - PDF Export

    #if canImport(UIKit)
    /// Export entries to a formatted PDF document (iOS only).
    func exportToPDF(entries: [DiaryEntry]) throws -> URL {
        let pageWidth: CGFloat = 612   // US Letter @ 72dpi
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        let titleFont = UIFont.systemFont(ofSize: 26, weight: .bold)
        let dateFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let metaFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)

        let dateFormatter = LocaleFormat.formatter(template: LocaleFormat.weekdayMonthDayYear)
        let timeFormatter = LocaleFormat.formatter(template: LocaleFormat.time)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let fileName = "dailyvox_diary_\(formattedDate()).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: tempURL) { context in
            context.beginPage()
            var cursorY: CGFloat = margin

            // Cover heading
            let title = String(localized: "DailyVox Diary", comment: "Export file (PDF export): large title at the top of the first page. DailyVox is the app name. About 14 characters.")
            title.draw(at: CGPoint(x: margin, y: cursorY),
                       withAttributes: [.font: titleFont, .foregroundColor: UIColor.label])
            cursorY += 38
            String(localized: "Exported \(formattedFullDate(Date())) · \(String(sortedEntries.count)) entries", comment: "Export file (PDF export): line under the title on the first page. First placeholder: today's date, already written out for the locale. Second: the number of entries, as digits in a string placeholder (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
                .draw(at: CGPoint(x: margin, y: cursorY),
                      withAttributes: [.font: metaFont, .foregroundColor: UIColor.secondaryLabel])
            cursorY += 30

            for entry in sortedEntries {
                let date = entry.date ?? Date()
                let mood = moodLabel(of: entry)
                let starred = entry.isStarred ? "  ★" : ""
                let header = dateFormatter.string(from: date) + " · " + timeFormatter.string(from: date) + starred
                let body = entry.text ?? String(localized: "(No text)", comment: "Export file (plain text, Markdown and PDF exports): stands in for the body of an entry that has no words. Keep the parentheses.")

                // Measure the body so we can page-break cleanly
                let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.label]
                let bodyBounding = (body as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: bodyAttrs, context: nil)
                let blockHeight = 22 + (mood.isEmpty ? 0 : 16) + ceil(bodyBounding.height) + 24

                if cursorY + min(blockHeight, pageHeight - margin * 2) > pageHeight - margin {
                    context.beginPage()
                    cursorY = margin
                }

                header.draw(at: CGPoint(x: margin, y: cursorY),
                            withAttributes: [.font: dateFont, .foregroundColor: UIColor.label])
                cursorY += 22

                if !mood.isEmpty {
                    String(localized: "Mood: \(mood)", comment: "Export file (plain text and PDF exports): line under an entry's date; the placeholder is the mood name, possibly followed by '(suggested)'.").draw(
                        at: CGPoint(x: margin, y: cursorY),
                        withAttributes: [.font: metaFont, .foregroundColor: UIColor.secondaryLabel])
                    cursorY += 16
                }

                (body as NSString).draw(
                    with: CGRect(x: margin, y: cursorY, width: contentWidth, height: bodyBounding.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: bodyAttrs, context: nil)
                cursorY += ceil(bodyBounding.height) + 24
            }
        }

        return tempURL
    }

    /// Export selected entries to PDF
    func exportToPDF(entries: [DiaryEntry], startDate: Date?, endDate: Date?, starredOnly: Bool) throws -> URL {
        var filtered = entries
        if let start = startDate { filtered = filtered.filter { ($0.date ?? Date.distantPast) >= start } }
        if let end = endDate { filtered = filtered.filter { ($0.date ?? Date.distantFuture) <= end } }
        if starredOnly { filtered = filtered.filter { $0.isStarred } }
        return try exportToPDF(entries: filtered)
    }
    #endif

    // MARK: - Encrypted Export

    /// Export all entries as an encrypted .dvx file.
    ///
    /// `bodyTwin` must be assembled on the main actor BEFORE hopping to the
    /// export queue (`ExportableBodyTwin.currentInMemory()`), so the payload
    /// is one consistent picture of the three Body Twin stores — a Keep
    /// mid-export can no longer tear it.
    func exportEncrypted(entries: [DiaryEntry], password: String,
                         bodyTwin: ExportableBodyTwin?) throws -> URL {
        let exportableEntries = entries.map { ExportableEntry(from: $0) }
        let backupData = BackupData(entries: exportableEntries,
                                    bodyTwin: bodyTwin)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let jsonData = try encoder.encode(backupData)
        let encryptedData = try EncryptionService.encrypt(data: jsonData, password: password)

        let fileName = "dailyvox_backup_\(formattedDate()).dvx"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try encryptedData.write(to: tempURL)

        return tempURL
    }

    /// Import entries from an encrypted .dvx file
    func importEncrypted(url: URL, password: String, context: NSManagedObjectContext) throws -> Int {
        let encryptedData = try Data(contentsOf: url)
        let jsonData = try EncryptionService.decrypt(data: encryptedData, password: password)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        var importedCount = 0

        for exportedEntry in backupData.entries {
            let fetchRequest: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", exportedEntry.id as CVarArg)

            let existingEntries = try context.fetch(fetchRequest)

            if existingEntries.isEmpty {
                let newEntry = DiaryEntry(context: context)
                newEntry.id = exportedEntry.id
                newEntry.date = exportedEntry.date
                newEntry.text = exportedEntry.text
                newEntry.setValue(exportedEntry.mood, forKey: "mood")
                newEntry.isStarred = exportedEntry.isStarred
                newEntry.createdAt = exportedEntry.createdAt
                newEntry.updatedAt = exportedEntry.updatedAt
                newEntry.audioFileName = exportedEntry.audioFileName
                newEntry.setValue(exportedEntry.audioFileNames, forKey: "audioFileNames")
                newEntry.setValue(exportedEntry.photoFileNames, forKey: "photoFileNames")
                newEntry.setValue(exportedEntry.selfLabelEmotion, forKey: "selfLabelEmotion")
                newEntry.setValue(Int16(exportedEntry.selfLabelIntensity ?? 0), forKey: "selfLabelIntensity")
                newEntry.suggestedMood = exportedEntry.suggestedMood
                newEntry.transcriptLocale = exportedEntry.transcriptLocale

                importedCount += 1
            }
        }

        if importedCount > 0 {
            try context.save()
        }

        // Restore Body Twin data even when every entry already exists — on a
        // fresh device CloudKit brings the entries back, but health data is
        // local-only and can ONLY return through this encrypted backup.
        if let bodyTwin = backupData.bodyTwin {
            Task { @MainActor in
                BodyTwinManager.shared.restoreFromBackup(bodyTwin)
            }
        }

        return importedCount
    }

    // MARK: - Helpers

    private func formattedDate() -> String {
        // A file name: fixed digits in any locale or calendar.
        LocaleFormat.posix("yyyy-MM-dd").string(from: Date())
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// §8.9: no emoji anywhere in the product, and an export is the product in
    /// someone else's hands — it is the copy most likely to be read years from
    /// now, in an app whose emoji font we do not control. The mood is written
    /// out as the word it always was — and a mood the app suggested says so,
    /// because a file read years from now cannot show "Sounds calm?".
    private func moodLabel(of entry: DiaryEntry) -> String {
        let mood = entry.mood ?? ""
        guard !mood.isEmpty else { return "" }
        return entry.isMoodSuggested
            ? String(localized: "\(mood.capitalized) (suggested)", comment: "Export file (plain text, Markdown and PDF exports): a mood the app suggested and the user did not pick. The placeholder is the mood's English name as stored (Happy, Calm…).")
            : mood.capitalized
    }
}

// MARK: - Export Format Enum

enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON Backup"
    case text = "Plain Text"
    case markdown = "Markdown"
    case csv = "CSV Spreadsheet"
    case pdf = "PDF Document"
    case encryptedBackup = "Encrypted Backup"

    var id: String { rawValue }

    /// What the export screen calls it. The raw value is only an identity.
    var title: String {
        switch self {
        case .json: return String(localized: "JSON Backup", comment: "Export Data screen: name of an export format. JSON is a file format; keep it. About 16 characters.")
        case .text: return String(localized: "Plain Text", comment: "Export Data screen: name of an export format (.txt file). About 16 characters.")
        case .markdown: return String(localized: "Markdown", comment: "Export Data screen: name of an export format. Markdown is a file format's name; usually kept as is. About 16 characters.")
        case .csv: return String(localized: "CSV Spreadsheet", comment: "Export Data screen: name of an export format. CSV is a file format; keep it. About 16 characters.")
        case .pdf: return String(localized: "PDF Document", comment: "Export Data screen: name of an export format. PDF is a file format; keep it. About 16 characters.")
        case .encryptedBackup: return String(localized: "Encrypted Backup", comment: "Export Data screen: name of an export format, a password-protected backup file. About 16 characters.")
        }
    }

    var icon: String {
        switch self {
        case .json: return "doc.badge.gearshape"
        case .text: return "doc.text"
        case .markdown: return "text.badge.checkmark"
        case .csv: return "tablecells"
        case .pdf: return "doc.richtext"
        case .encryptedBackup: return "lock.shield.fill"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .text: return "txt"
        case .markdown: return "md"
        case .csv: return "csv"
        case .pdf: return "pdf"
        case .encryptedBackup: return "dvx"
        }
    }

    var description: String {
        switch self {
        case .json: return String(localized: "Full backup of your entries. Can be imported back.", comment: "Export Data screen: line under 'JSON Backup'. About 50 characters.")
        case .text: return String(localized: "Simple readable format for archiving.", comment: "Export Data screen: line under 'Plain Text'. About 40 characters.")
        case .markdown: return String(localized: "Formatted text for notes apps.", comment: "Export Data screen: line under 'Markdown'. About 35 characters.")
        case .csv: return String(localized: "Spreadsheet format for analysis.", comment: "Export Data screen: line under 'CSV Spreadsheet'. About 35 characters.")
        case .pdf: return String(localized: "Beautiful formatted document.", comment: "Export Data screen: line under 'PDF Document'. About 30 characters.")
        case .encryptedBackup: return String(localized: "Password-protected backup, including your Body Twin's health data — the only export that carries it.", comment: "Export Data screen: line under 'Encrypted Backup'. Body Twin is the feature's name. The privacy claim must stay exact: this is the only export with health data. About 100 characters.")
        }
    }
}

// MARK: - Audio File List Helper

/// Encodes/decodes the newline-delimited list of audio recording filenames stored
/// in `DiaryEntry.audioFileNames`. Supports multiple recordings per entry while
/// keeping the legacy single `audioFileName` field for backward compatibility.
enum AudioFileList {
    /// Parse the stored list, falling back to the legacy single `audioFileName`.
    static func parse(_ stored: String?, legacy: String?) -> [String] {
        var names = (stored ?? "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        if names.isEmpty, let legacy, !legacy.isEmpty {
            names = [legacy]
        }
        return names
    }

    /// Encode a list of filenames for storage.
    static func encode(_ names: [String]) -> String {
        names.joined(separator: "\n")
    }
}
