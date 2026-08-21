//
//  solynApp.swift
//  solyn
//
//  Main entry point for the DailyVox voice diary app.
//  A privacy-focused journaling app with voice-to-text transcription.
//
//  Created by Karthikeyan NG on 01/12/25.
//

import SwiftUI
import WidgetKit
import CoreData
import DailyVoxTwinEngine

/// Main app entry point.
/// Manages app lifecycle, authentication state, and theme.
@main
struct DailyVoxApp: App {
    
    // MARK: - Properties
    let persistenceController = PersistenceController.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        // Inject the Core Data + CloudKit-backed store into the Twin engines BEFORE any
        // UI (or the seeder) touches them, so each reloads its existing state from the
        // same AIState rows it always used — no Twin reset for existing users.
        let twinStore = CoreDataTwinStateStore()
        LocalAIEngine.configure(store: twinStore)
        DigitalTwinEngine.configure(store: twinStore)

        // Body Twin state is LOCAL-ONLY (guideline 2.5.1): a backup-excluded
        // JSON file, never the CloudKit-synced store above.
        DigitalTwinEngine.configureBodyTwinStore(FileBodyTwinStateStore())

        // The entity→entry mention index is per-entry data and must NEVER go in
        // the CloudKit-synced `digital_twin` blob (~1 MB at diary scale). Same
        // device-local, rebuildable-from-entries store the semantic index uses.
        // Injected BEFORE the seeder below, or seeded entries fold into the
        // throwaway in-memory default and the index starts empty.
        DigitalTwinEngine.configureEntityGraphStore(LocalFileTwinStateStore(subfolder: "EntityGraph"))

        ScreenshotDataSeeder.seedIfNeeded(context: persistenceController.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    ZStack {
                        ContentView()

                        // Show lock screen if app lock is enabled and not unlocked
                        if lockManager.isEnabled && !lockManager.isUnlocked {
                            LockScreenView()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: lockManager.isUnlocked)
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            // The app theme, as a value the tree can carry. The Twin screen
            // overrides it with `.night`; everywhere else this is what
            // `@Environment(\.dvTheme)` resolves to, and it re-injects on
            // change because this view observes the manager.
            .environment(\.dvTheme, themeManager.palette)
            .tint(themeManager.selectedTheme.accentColor)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    if lockManager.isEnabled {
                        lockManager.lock()
                    }
                    // Refresh widgets when app goes to background
                    WidgetCenter.shared.reloadAllTimelines()
                    runAudioCleanup()
                case .active:
                    // Re-arm reminders against what has actually been spoken.
                    // The window is armed a week ahead, so coming forward is
                    // where a day that got journalled elsewhere (Siri, the
                    // widget, an import) gets its reminder withdrawn.
                    ReminderManager.shared.refresh(
                        in: persistenceController.container.viewContext)
                    // Check if launched from Siri shortcut to record
                    checkForSiriRecordingIntent()
                    // Refresh the persistent streak Live Activity (if opted in)
                    refreshStreakLiveActivity()
                    // v1.5.5: derive today's ambient signals into the review
                    // queue (no-op unless a source is enabled + authorized).
                    Task { await AmbientSignalManager.shared.refreshTodaySignals() }
                default:
                    break
                }
            }
        }
    }

    private func refreshStreakLiveActivity() {
        let context = persistenceController.container.viewContext
        Task { @MainActor in
            let streak = currentStreak(in: context)
            let total = totalEntryCount(in: context)
            let hasToday = hasEntryToday(in: context)
            LiveActivityManager.shared.refreshStreakActivity(
                streak: streak,
                hasEntryToday: hasToday,
                totalEntries: total
            )
        }
    }

    private func checkForSiriRecordingIntent() {
        if UserDefaults.standard.bool(forKey: "shouldStartRecording") {
            UserDefaults.standard.set(false, forKey: "shouldStartRecording")
            // Post notification to start recording
            NotificationCenter.default.post(name: .startRecordingFromSiri, object: nil)
        }
    }

    private func runAudioCleanup() {
        #if os(iOS)
        DispatchQueue.global(qos: .background).async {
            let context = persistenceController.container.viewContext
            var fileNames: [String] = []

            context.performAndWait {
                let fetchRequest: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
                fetchRequest.propertiesToFetch = ["audioFileName"]
                fetchRequest.returnsObjectsAsFaults = false

                if let results = try? context.fetch(fetchRequest) {
                    fileNames = results.compactMap { entry in
                        entry.value(forKey: "audioFileName") as? String
                    }.filter { !$0.isEmpty }
                }
            }

            let fileManager = FileManager.default
            guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                AudioRecorder.cleanupOrphanedRecordings(keepURLs: [])
                return
            }

            let recordingsDirectory = base.appendingPathComponent("Recordings", isDirectory: true)
            let keepURLs: Set<URL> = Set(fileNames.map { recordingsDirectory.appendingPathComponent($0) })

            AudioRecorder.cleanupOrphanedRecordings(keepURLs: keepURLs)
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromSiri = Notification.Name("startRecordingFromSiri")
}
