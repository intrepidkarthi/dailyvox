//
//  AppIntents.swift
//  solyn
//
//  Siri Shortcuts integration for voice diary
//

import AppIntents
import CoreData

// MARK: - Add Diary Entry Intent

@available(iOS 16.0, *)
struct AddDiaryEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Diary"
    static var description = IntentDescription("Add a new entry to your DailyVox diary")

    @Parameter(title: "Entry Text")
    var text: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to my diary")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext

        // Check if there's already an entry for today
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1

        let existingEntry = try? context.fetch(request).first

        if let entry = existingEntry {
            // Append to existing entry
            let existingText = entry.text ?? ""
            if existingText.isEmpty {
                entry.text = text ?? ""
            } else {
                entry.text = existingText + "\n\n" + (text ?? "")
            }
            entry.updatedAt = Date()
        } else {
            // Create new entry
            let entry = DiaryEntry(context: context)
            entry.id = UUID()
            entry.date = Date()
            entry.createdAt = Date()
            entry.updatedAt = Date()
            entry.text = text ?? ""
            entry.isStarred = false
        }

        try context.save()

        return .result(dialog: "Added to your diary.")
    }
}

// MARK: - Record Voice Entry Intent (Opens App)

@available(iOS 16.0, *)
struct RecordVoiceEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Voice Diary"
    static var description = IntentDescription("Open DailyVox to record a voice entry")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // This will open the app - the app can check for this intent
        // and automatically start recording
        UserDefaults.standard.set(true, forKey: "shouldStartRecording")
        return .result()
    }
}

// MARK: - Get Today's Entry Intent

@available(iOS 16.0, *)
struct GetTodayEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Diary Entry"
    static var description = IntentDescription("Read your diary entry from today")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DiaryEntry.updatedAt, ascending: false)]
        request.fetchLimit = 1

        if let entry = try? context.fetch(request).first,
           let text = entry.text, !text.isEmpty {
            // Truncate for Siri response
            let truncated = text.count > 500 ? String(text.prefix(500)) + "..." : text
            return .result(dialog: "Here's your entry from today: \(truncated)")
        } else {
            return .result(dialog: "You haven't recorded anything today yet. Would you like to add an entry?")
        }
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct DailyVoxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordVoiceEntryIntent(),
            phrases: [
                "Record in \(.applicationName)",
                "Add to my \(.applicationName) diary",
                "Open \(.applicationName) to record",
                "Start recording in \(.applicationName)"
            ],
            shortTitle: "Record Entry",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: AddDiaryEntryIntent(),
            phrases: [
                "Add entry to \(.applicationName)",
                "Write in my \(.applicationName) diary",
                "Save to \(.applicationName)"
            ],
            shortTitle: "Add Entry",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: GetTodayEntryIntent(),
            phrases: [
                "Read my \(.applicationName) entry",
                "What did I write in \(.applicationName) today",
                "Get today's \(.applicationName) entry"
            ],
            shortTitle: "Read Entry",
            systemImageName: "book.fill"
        )
    }
}
