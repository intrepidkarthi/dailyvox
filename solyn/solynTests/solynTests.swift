//
//  solynTests.swift
//  solynTests
//
//  Created by Karthikeyan NG on 01/12/25.
//

import Testing
import Foundation
import CryptoKit
import DailyVoxTwinEngine
@testable import solyn

// MARK: - Mood Tests

struct MoodTests {

    @Test func allMoodsHaveDisplayNames() {
        for mood in Mood.allCases {
            #expect(!mood.displayName.isEmpty, "Mood \(mood.rawValue) should have a display name")
        }
    }

    @Test func allMoodsHaveIcons() {
        for mood in Mood.allCases {
            #expect(!mood.icon.isEmpty, "Mood \(mood.rawValue) should have an icon")
        }
    }

    @Test func selectableMoodsExcludeNone() {
        let selectable = Mood.selectableMoods
        #expect(!selectable.contains(.none))
        #expect(selectable.count == Mood.allCases.count - 1)
    }

    @Test func moodInitFromRawValue() {
        #expect(Mood(rawValue: "happy") == .happy)
        #expect(Mood(rawValue: "sad") == .sad)
        // Explicit `Mood.none`: a bare `.none` against a `Mood?` resolves to
        // Optional.none and can never match `.some(.none)`.
        #expect(Mood(rawValue: "") == Mood.none)
        #expect(Mood(rawValue: "invalid") == nil)
    }

    @Test func moodIdentifiable() {
        for mood in Mood.allCases {
            #expect(mood.id == mood.rawValue)
        }
    }
}

// MARK: - Encryption Tests

struct EncryptionTests {

    @Test func encryptAndDecryptRoundTrip() throws {
        let originalData = Data("Hello, DailyVox! This is a test entry.".utf8)
        let password = "SecurePassword123!"

        let encrypted = try EncryptionService.encrypt(data: originalData, password: password)
        let decrypted = try EncryptionService.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test func encryptionProducesDifferentOutput() throws {
        let data = Data("Test data".utf8)
        let password = "password"

        let encrypted1 = try EncryptionService.encrypt(data: data, password: password)
        let encrypted2 = try EncryptionService.encrypt(data: data, password: password)

        // Different salt each time means different ciphertext
        #expect(encrypted1 != encrypted2)
    }

    @Test func decryptWithWrongPasswordFails() throws {
        let data = Data("Secret diary entry".utf8)
        let encrypted = try EncryptionService.encrypt(data: data, password: "correct")

        #expect(throws: EncryptionService.EncryptionError.self) {
            _ = try EncryptionService.decrypt(data: encrypted, password: "wrong")
        }
    }

    @Test func encryptEmptyPasswordThrows() {
        let data = Data("test".utf8)
        #expect(throws: EncryptionService.EncryptionError.invalidPassword) {
            _ = try EncryptionService.encrypt(data: data, password: "")
        }
    }

    @Test func decryptEmptyPasswordThrows() {
        let data = Data("test".utf8)
        #expect(throws: EncryptionService.EncryptionError.invalidPassword) {
            _ = try EncryptionService.decrypt(data: data, password: "")
        }
    }

    @Test func decryptInvalidDataThrows() {
        let invalidData = Data("not encrypted".utf8)
        #expect(throws: EncryptionService.EncryptionError.invalidFileFormat) {
            _ = try EncryptionService.decrypt(data: invalidData, password: "password")
        }
    }

    @Test func encryptedDataContainsMagicBytes() throws {
        let data = Data("test".utf8)
        let encrypted = try EncryptionService.encrypt(data: data, password: "password")

        // DVX1 magic bytes
        #expect(encrypted[0] == 0x44) // D
        #expect(encrypted[1] == 0x56) // V
        #expect(encrypted[2] == 0x58) // X
        #expect(encrypted[3] == 0x31) // 1
    }

    @Test func encryptLargeData() throws {
        let largeData = Data(repeating: 0xAB, count: 1_000_000) // 1MB
        let password = "strongPassword"

        let encrypted = try EncryptionService.encrypt(data: largeData, password: password)
        let decrypted = try EncryptionService.decrypt(data: encrypted, password: password)

        #expect(decrypted == largeData)
    }
}

// MARK: - EncryptionError Tests

struct EncryptionErrorTests {

    @Test func errorDescriptionsExist() {
        let errors: [EncryptionService.EncryptionError] = [
            .invalidData, .invalidPassword, .decryptionFailed, .invalidFileFormat
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Body Twin Restore-Filtering Tests

/// The fold-once / decided-stays-decided invariants around backup restore:
/// a snapshot the user already Kept or Let go of must never re-enter the
/// review queue, no matter how many times a stale .dvx is re-imported.
@MainActor
struct BodyTwinRestoreFilteringTests {

    private func pending(_ id: UUID, at date: Date = Date()) -> PendingSnapshot {
        PendingSnapshot(id: id,
                        snapshot: HealthSnapshot(capturedAt: date, sleepHours: 7.0),
                        createdAt: date)
    }

    private func resetStores() {
        PendingSnapshotQueue.shared.wipe()
        KeptSnapshotStore.shared.wipe()
    }

    @Test func discardedIdNeverReentersTheQueue() {
        resetStores()
        defer { resetStores() }

        let tombstoned = UUID()
        PendingSnapshotQueue.shared.restore([pending(tombstoned)])
        #expect(PendingSnapshotQueue.shared.count == 1)

        // Let go — deleted, and the id is tombstoned.
        BodyTwinManager.shared.discardSnapshot(id: tombstoned)
        #expect(PendingSnapshotQueue.shared.count == 0)

        // Re-importing a backup that still carried it must NOT resurrect it.
        PendingSnapshotQueue.shared.restore([pending(tombstoned)])
        #expect(PendingSnapshotQueue.shared.count == 0,
                "A Let-go snapshot came back through backup restore")
    }

    @Test func alreadyKeptIdIsFilteredOutOfRestoredPending() {
        resetStores()
        defer { resetStores() }

        let keptId = UUID()
        let freshId = UUID()
        KeptSnapshotStore.shared.restore([
            KeptSnapshot(id: keptId,
                         snapshot: HealthSnapshot(capturedAt: Date(), sleepHours: 6.5),
                         keptAt: Date())
        ])

        // A stale backup exported while keptId was still pending.
        let payload = ExportableBodyTwin(state: nil,
                                         keptSnapshots: [],
                                         pendingSnapshots: [pending(keptId), pending(freshId)])
        BodyTwinManager.shared.restoreFromBackup(payload)

        let queuedIds = PendingSnapshotQueue.shared.items.map(\.id)
        #expect(!queuedIds.contains(keptId),
                "An already-Kept snapshot re-entered the review queue")
        #expect(queuedIds.contains(freshId))
    }

    @Test func keepSnapshotSkipsFoldWhenIdAlreadyKept() {
        resetStores()
        defer { resetStores() }

        let id = UUID()
        let snapshot = HealthSnapshot(capturedAt: Date(), sleepHours: 8.0)
        KeptSnapshotStore.shared.restore([KeptSnapshot(id: id, snapshot: snapshot, keptAt: Date())])
        PendingSnapshotQueue.shared.restore([pending(id)])
        // (Duplicate deliberately forced past the restore filters.)
        let foldedBefore = DigitalTwinEngine.shared.bodyTwin.entriesWithSnapshot

        BodyTwinManager.shared.keepSnapshot(id: id)

        #expect(DigitalTwinEngine.shared.bodyTwin.entriesWithSnapshot == foldedBefore,
                "Keeping an already-kept id must not fold the snapshot a second time")
        #expect(PendingSnapshotQueue.shared.count == 0)
    }

    @Test func pendingQueueCapsAtThirtyDroppingOldest() {
        resetStores()
        defer { resetStores() }

        let base = Date(timeIntervalSince1970: 1_780_000_000)
        for i in 0..<35 {
            PendingSnapshotQueue.shared.enqueue(
                HealthSnapshot(capturedAt: base.addingTimeInterval(Double(i) * 60),
                               sleepHours: 7.0))
        }

        #expect(PendingSnapshotQueue.shared.count == 30)
        // Oldest five dropped: the earliest surviving capture is #5.
        let earliest = PendingSnapshotQueue.shared.items.map(\.snapshot.capturedAt).min()
        #expect(earliest == base.addingTimeInterval(5 * 60))
    }
}
