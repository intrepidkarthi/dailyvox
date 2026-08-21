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
        self.deviceName = Host.current().localizedName ?? "Mac"
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

    // MARK: - Research Export (pilot)

    /// One row of the pilot research export: the fields the affect research
    /// protocol requires (docs/research-affect, R1 §"what the pilot MUST
    /// collect") — transcript, recording-time self-label + intensity,
    /// timestamp, duration — joinable on the entry's stable id.
    struct ResearchEntry: Codable {
        let id: UUID
        let date: Date
        let text: String
        let emotions: [String]      // corpus-shaped: [selfLabelEmotion rawValue]
        let intensity: Int?         // 1–3, nil when the participant skipped it
        let duration: Double
        let audioCount: Int         // >1 flags a multi-recording day (label = latest)
    }

    struct ResearchExport: Codable {
        let name: String
        let source: String
        let exportDate: Date
        let deviceModel: String
        let systemVersion: String
        let appleIntelligenceAvailable: Bool
        let entryCount: Int
        let entries: [ResearchEntry]
    }

    /// Export ONLY self-labeled entries as research JSON, chronological
    /// (the analysis protocol splits per-user by time, never randomly).
    /// User-initiated share only — this file is handed to the share sheet
    /// and goes wherever the participant chooses to send it.
    func exportResearchJSON(entries: [DiaryEntry], appleIntelligenceAvailable: Bool) throws -> URL {
        let labeled = entries
            .filter { ($0.value(forKey: "selfLabelEmotion") as? String)?.isEmpty == false }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        let rows: [ResearchEntry] = labeled.map { entry in
            let intensity = entry.value(forKey: "selfLabelIntensity") as? Int16 ?? 0
            let audio = AudioFileList.parse(entry.value(forKey: "audioFileNames") as? String,
                                            legacy: entry.value(forKey: "audioFileName") as? String)
            return ResearchEntry(
                id: entry.id ?? UUID(),
                date: entry.date ?? Date(),
                text: entry.text ?? "",
                emotions: [(entry.value(forKey: "selfLabelEmotion") as? String) ?? ""],
                intensity: intensity > 0 ? Int(intensity) : nil,
                duration: entry.duration,
                audioCount: audio.count
            )
        }

        #if canImport(UIKit)
        let model = UIDevice.current.model
        let osVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        let model = "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let export = ResearchExport(
            name: "dailyvox-pilot-export",
            source: "DailyVox research pilot — writer self-report at recording time",
            exportDate: Date(),
            deviceModel: model,
            systemVersion: osVersion,
            appleIntelligenceAvailable: appleIntelligenceAvailable,
            entryCount: rows.count,
            entries: rows
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

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
        var textContent = """
        ═══════════════════════════════════════════════════════════════
                              DAILYVOX DIARY EXPORT
        ═══════════════════════════════════════════════════════════════
        
        Exported: \(formattedFullDate(Date()))
        Total Entries: \(entries.count)
        
        ═══════════════════════════════════════════════════════════════
        
        """
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        for entry in sortedEntries {
            let date = entry.date ?? Date()
            let text = entry.text ?? "(No text)"
            let mood = entry.value(forKey: "mood") as? String ?? ""
            let starred = entry.isStarred ? " \u{2726}" : ""
            
            textContent += """
            ───────────────────────────────────────────────────────────────
            \(dateFormatter.string(from: date))\(starred)
            """
            
            if !mood.isEmpty {
                textContent += "\nMood: \(moodLabel(mood))"
            }
            
            textContent += """
            
            ───────────────────────────────────────────────────────────────
            
            \(text)
            
            
            """
        }
        
        textContent += """
        ═══════════════════════════════════════════════════════════════
                              END OF EXPORT
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
        var mdContent = """
        # DailyVox Diary Export
        
        **Exported:** \(formattedFullDate(Date()))  
        **Total Entries:** \(entries.count)
        
        ---
        
        """
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        let groupedByMonth = Dictionary(grouping: sortedEntries) { entry -> String in
            let date = entry.date ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        
        let sortedMonths = groupedByMonth.keys.sorted { month1, month2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let date1 = formatter.date(from: month1) ?? Date()
            let date2 = formatter.date(from: month2) ?? Date()
            return date1 > date2
        }
        
        for month in sortedMonths {
            mdContent += "## \(month)\n\n"
            
            if let monthEntries = groupedByMonth[month] {
                for entry in monthEntries {
                    let date = entry.date ?? Date()
                    let text = entry.text ?? "(No text)"
                    let mood = entry.value(forKey: "mood") as? String ?? ""
                    let starred = entry.isStarred ? " \u{2726}" : ""
                    
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "EEEE, MMMM d"
                    
                    mdContent += "### \(dayFormatter.string(from: date))\(starred)\n\n"
                    
                    if !mood.isEmpty {
                        mdContent += "**Mood:** \(mood.capitalized)\n\n"
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
        var csvContent = "Date,Time,Mood,Starred,Word Count,Text\n"
        
        let sortedEntries = entries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for entry in sortedEntries {
            let date = entry.date ?? Date()
            let text = (entry.text ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let mood = entry.value(forKey: "mood") as? String ?? ""
            let starred = entry.isStarred ? "Yes" : "No"
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy · h:mm a"

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let fileName = "dailyvox_diary_\(formattedDate()).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: tempURL) { context in
            context.beginPage()
            var cursorY: CGFloat = margin

            // Cover heading
            let title = "DailyVox Diary"
            title.draw(at: CGPoint(x: margin, y: cursorY),
                       withAttributes: [.font: titleFont, .foregroundColor: UIColor.label])
            cursorY += 38
            "Exported \(formattedFullDate(Date())) · \(sortedEntries.count) entries"
                .draw(at: CGPoint(x: margin, y: cursorY),
                      withAttributes: [.font: metaFont, .foregroundColor: UIColor.secondaryLabel])
            cursorY += 30

            for entry in sortedEntries {
                let date = entry.date ?? Date()
                let mood = entry.value(forKey: "mood") as? String ?? ""
                let starred = entry.isStarred ? "  ★" : ""
                let header = dateFormatter.string(from: date) + starred
                let body = entry.text ?? "(No text)"

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
                    "Mood: \(mood.capitalized)".draw(
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
    /// out as the word it always was.
    private func moodLabel(_ mood: String) -> String {
        mood.isEmpty ? "" : mood.capitalized
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
        case .json: return "Full backup of your entries. Can be imported back."
        case .text: return "Simple readable format for archiving."
        case .markdown: return "Formatted text for notes apps."
        case .csv: return "Spreadsheet format for analysis."
        case .pdf: return "Beautiful formatted document."
        case .encryptedBackup: return "Password-protected backup, including your Body Twin's health data — the only export that carries it."
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
