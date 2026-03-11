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
    let photoFileNames: String?

    init(from entry: DiaryEntry) {
        self.id = entry.id ?? UUID()
        self.date = entry.date ?? Date()
        self.text = entry.text ?? ""
        self.mood = entry.value(forKey: "mood") as? String
        self.isStarred = entry.isStarred
        self.createdAt = entry.createdAt ?? Date()
        self.updatedAt = entry.updatedAt ?? Date()
        self.audioFileName = entry.audioFileName
        self.photoFileNames = entry.value(forKey: "photoFileNames") as? String
    }
}

/// Container for full backup data
struct BackupData: Codable {
    let version: String
    let exportDate: Date
    let deviceName: String
    let entryCount: Int
    let entries: [ExportableEntry]
    
    init(entries: [ExportableEntry]) {
        self.version = "1.0"
        self.exportDate = Date()
        #if canImport(UIKit)
        self.deviceName = UIDevice.current.name
        #else
        self.deviceName = Host.current().localizedName ?? "Mac"
        #endif
        self.entryCount = entries.count
        self.entries = entries
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
                newEntry.setValue(exportedEntry.photoFileNames, forKey: "photoFileNames")

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
            let starred = entry.isStarred ? " ⭐" : ""
            
            textContent += """
            ───────────────────────────────────────────────────────────────
            📅 \(dateFormatter.string(from: date))\(starred)
            """
            
            if !mood.isEmpty {
                let moodEmoji = moodToEmoji(mood)
                textContent += "\n\(moodEmoji) Mood: \(mood.capitalized)"
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
                    let starred = entry.isStarred ? " ⭐" : ""
                    
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
    
    // MARK: - Encrypted Export

    /// Export all entries as an encrypted .dvx file
    func exportEncrypted(entries: [DiaryEntry], password: String) throws -> URL {
        let exportableEntries = entries.map { ExportableEntry(from: $0) }
        let backupData = BackupData(entries: exportableEntries)

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
                newEntry.setValue(exportedEntry.photoFileNames, forKey: "photoFileNames")

                importedCount += 1
            }
        }

        if importedCount > 0 {
            try context.save()
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
    
    private func moodToEmoji(_ mood: String) -> String {
        switch mood.lowercased() {
        case "happy": return "☀️"
        case "calm": return "🍃"
        case "grateful": return "💗"
        case "excited": return "⭐"
        case "tired": return "🌙"
        case "anxious": return "💨"
        case "sad": return "🌧️"
        case "angry": return "🔥"
        default: return "📝"
        }
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
        case .json: return "Full backup with all data. Can be imported back."
        case .text: return "Simple readable format for archiving."
        case .markdown: return "Formatted text for notes apps."
        case .csv: return "Spreadsheet format for analysis."
        case .pdf: return "Beautiful formatted document."
        case .encryptedBackup: return "Password-protected backup. Maximum privacy."
        }
    }
}
