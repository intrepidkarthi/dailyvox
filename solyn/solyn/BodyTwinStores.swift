//
//  BodyTwinStores.swift
//  solyn
//
//  LOCAL-ONLY persistence for the Body Twin (v1.5).
//
//  Everything HealthKit-derived lives in Application Support/BodyTwin/ as
//  plain JSON, excluded from device backup, and never touches Core Data or
//  the CloudKit-synced AIState store (guideline 2.5.1 — see the engine's
//  BodyTwinStateStore.swift for the full privacy boundary). Three stores
//  share the directory:
//
//    state.json    — the engine's BodyTwin sub-model (FileBodyTwinStateStore)
//    pending.json  — snapshots waiting for review before your Twin learns them
//    kept.json     — snapshots the user chose to keep (for future insights)
//

import Foundation
import DailyVoxTwinEngine

// MARK: - Shared Directory

/// Application Support/BodyTwin/, created on demand. The backup-exclusion
/// flag is (re)applied on every access so health-derived JSON can never ride
/// a device backup into iCloud, even for users upgrading from older installs.
private enum BodyTwinFileStorage {

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var dir = base.appendingPathComponent("BodyTwin", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }

    static func read<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func write<T: Encodable>(_ value: T, to fileName: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(fileName), options: [.atomic])
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}

// MARK: - Body Twin State Store

/// The app's concrete `BodyTwinStateStore`: baseline and counters as a local
/// JSON file. Injected via `DigitalTwinEngine.configureBodyTwinStore(_:)` at
/// launch (solynApp), beside the CloudKit-backed store the text Twin uses.
final class FileBodyTwinStateStore: BodyTwinStateStore {

    private let fileName = "state.json"

    func loadBodyTwin() -> BodyTwin? {
        BodyTwinFileStorage.read(BodyTwin.self, from: fileName)
    }

    func saveBodyTwin(_ bodyTwin: BodyTwin) {
        BodyTwinFileStorage.write(bodyTwin, to: fileName)
    }
}

// MARK: - Pending Snapshot Queue

/// One snapshot waiting for review, keyed by its own id — snapshots are
/// per-recording-session, not per-entry, so several can share a day.
struct PendingSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let snapshot: HealthSnapshot
    let createdAt: Date
}

/// Snapshots your body offered, held for review before your Twin learns them.
/// Nothing in this queue has touched the Twin: Keep hands a snapshot to
/// `foldHealthSnapshot`, Let go deletes it unseen.
@MainActor
final class PendingSnapshotQueue: ObservableObject {
    static let shared = PendingSnapshotQueue()

    private let fileName = "pending.json"

    @Published private(set) var items: [PendingSnapshot]

    var count: Int { items.count }

    private init() {
        items = BodyTwinFileStorage.read([PendingSnapshot].self, from: fileName) ?? []
    }

    func enqueue(_ snapshot: HealthSnapshot) {
        items.append(PendingSnapshot(id: UUID(), snapshot: snapshot, createdAt: Date()))
        persist()
    }

    /// Let go — removed before the Twin ever saw it.
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    /// Keep — dequeues and returns the snapshot so the caller can fold it
    /// into the Twin and record it in `KeptSnapshotStore`.
    func keep(id: UUID) -> HealthSnapshot? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let item = items.remove(at: index)
        persist()
        return item.snapshot
    }

    func wipe() {
        items = []
        persist()
    }

    private func persist() {
        BodyTwinFileStorage.write(items, to: fileName)
    }
}

// MARK: - Kept Snapshot Store

/// A snapshot the user chose to keep, dated for calendar-day correlation.
struct KeptSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let snapshot: HealthSnapshot
    let keptAt: Date
}

/// Append-only record of approved snapshots, so future insights can line up
/// body signals with the day's mood. A day is ~10 small numbers, so all of
/// them are kept; ids dedupe any repeated Keep.
@MainActor
final class KeptSnapshotStore {
    static let shared = KeptSnapshotStore()

    private let fileName = "kept.json"
    private var cache: [KeptSnapshot]

    private init() {
        cache = BodyTwinFileStorage.read([KeptSnapshot].self, from: fileName) ?? []
    }

    func append(id: UUID, snapshot: HealthSnapshot, keptAt: Date = Date()) {
        guard !cache.contains(where: { $0.id == id }) else { return }
        cache.append(KeptSnapshot(id: id, snapshot: snapshot, keptAt: keptAt))
        BodyTwinFileStorage.write(cache, to: fileName)
    }

    func loadAll() -> [KeptSnapshot] { cache }

    func wipe() {
        cache = []
        BodyTwinFileStorage.delete(fileName)
    }
}
