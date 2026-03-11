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
                    // Check if launched from Siri shortcut to record
                    checkForSiriRecordingIntent()
                default:
                    break
                }
            }
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
