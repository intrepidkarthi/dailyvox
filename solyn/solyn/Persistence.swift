//
//  Persistence.swift
//  solyn
//
//  Core Data persistence controller with CloudKit sync support.
//  All data is stored locally and optionally synced via user's personal iCloud.
//
//  Created by Karthikeyan NG on 01/12/25.
//

import CoreData
import CloudKit

/// Manages Core Data persistence with optional CloudKit synchronization.
/// Data is stored locally on device and synced through user's personal iCloud account.
struct PersistenceController {
    
    // MARK: - Shared Instance
    
    static let shared = PersistenceController()

    /// App Group identifier for sharing data with widgets
    static let appGroupIdentifier = "group.com.dailyvox.app"

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let entry = DiaryEntry(context: viewContext)
            let now = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            entry.id = UUID()
            entry.date = now
            entry.createdAt = now
            entry.updatedAt = now
            entry.text = "Sample entry for preview day \(i + 1)"
            entry.isStarred = i % 3 == 0
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "solyn")

        // Configure store location
        // Data is stored in the shared App Group container so widgets can access it
        let storeURL: URL
        if inMemory {
            storeURL = URL(fileURLWithPath: "/dev/null")
        } else if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PersistenceController.appGroupIdentifier) {
            storeURL = appGroupURL.appendingPathComponent("solyn.sqlite")
        } else {
            // Fallback to default directory if App Group is unavailable
            storeURL = NSPersistentCloudKitContainer.defaultDirectoryURL().appendingPathComponent("solyn.sqlite")
        }

        let description = NSPersistentStoreDescription(url: storeURL)

        // Only enable CloudKit if iCloud is available and properly configured
        if PersistenceController.shouldEnableCloudKit {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: PersistenceController.cloudKitContainerIdentifier
            )
        }

        // File protection (iOS only - not available on macOS)
        #if os(iOS)
        description.setOption(FileProtectionType.complete as NSObject,
                              forKey: NSPersistentStoreFileProtectionKey)
        #endif

        // Enable history tracking (works with or without CloudKit)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Log error but don't crash - app can work without CloudKit
                // Note: In production, consider using os_log instead of print
                #if DEBUG
                print("Core Data error: \(error), \(error.userInfo)")
                #endif
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Listen for remote changes (only relevant when CloudKit is enabled)
        let coordinator = container.persistentStoreCoordinator
        let viewContext = container.viewContext
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coordinator,
            queue: .main
        ) { _ in
            // Refresh the view context when remote changes arrive
            viewContext.refreshAllObjects()
        }
    }

    /// Check if CloudKit should be enabled
    private static var shouldEnableCloudKit: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// CloudKit container identifier based on bundle ID
    private static var cloudKitContainerIdentifier: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.dailyvox.app"
        return "iCloud.\(bundleId)"
    }

    // MARK: - Sync Status

    /// Check if iCloud is available
    static var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
