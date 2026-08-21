//
//  AppIntents.swift
//  solyn
//
//  Siri Shortcuts integration for voice diary
//

import AppIntents
import CoreData
import Foundation
import DailyVoxTwinEngine

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

// MARK: - Ask your Twin

/// "Hey Siri, ask my Twin how my week was."
///
/// FINAL-SPEC §5 lists this alongside the recording intent, and it was the one
/// missing on both platforms. It matters more than it looks: an assistant answer
/// is the only place the product's claim gets tested by someone who never opened
/// the app — so it runs the SAME retrieval-and-compose path the Ask screen uses,
/// returns the citation count out loud, and never reaches the network.
struct AskYourTwinIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Your Twin"
    /// No hardware names here: ITMS-90626 rejects them, and Siri reads this copy
    /// on whichever device you asked from, so naming one would be wrong as often
    /// as it was right. "On device" is the promise; "iPhone" was never the part
    /// carrying it.
    static var description = IntentDescription(
        "Ask your Digital Twin about your journal. Answered on device, from your own entries."
    )

    /// No `openAppWhenRun` — the whole point is an answer without a screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Question", requestValueDialog: "What would you like to ask your Twin?")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Ask me something about your journal.")
        }

        let evidence = await TwinChatEvidenceAdapter().recall(query: trimmed, topK: 3, dateRange: nil)
        let turn = RetrievalAnswerComposer.compose(
            question: trimmed,
            evidence: evidence,
            twin: DigitalTwinEngine.shared,
            profile: TwinChatProfile(from: LocalAIEngine.shared.userProfile))

        let answer = turn.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            return .result(dialog: "I don't have enough entries to answer that yet.")
        }

        // The receipt, spoken. A cited answer that does not say it is cited is
        // indistinguishable from a guess.
        let count = turn.citations.count
        let receipt = count == 0
            ? ""
            : (count == 1 ? " From one of your entries." : " From \(count) of your entries.")
        return .result(dialog: IntentDialog(stringLiteral: answer + receipt))
    }
}

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

        AppShortcut(
            intent: AskYourTwinIntent(),
            phrases: [
                "Ask my Twin in \(.applicationName)",
                "Ask my \(.applicationName) Twin",
                "What does my \(.applicationName) Twin think"
            ],
            shortTitle: "Ask Your Twin",
            systemImageName: "sparkle"
        )
    }
}
