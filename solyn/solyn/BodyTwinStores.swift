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

    static let stateFile     = "state.json"
    static let pendingFile   = "pending.json"
    static let keptFile      = "kept.json"
    /// Ids of snapshots the user Let go of (no snapshot data, just UUIDs) —
    /// see `PendingSnapshotQueue.discardedIds`.
    static let discardedFile = "discarded.json"

    /// Resolved once per launch: the directory is created and the exclusion
    /// flag applied on first access each run (covering users upgrading from
    /// older installs), then reused — store reads/writes happen on every
    /// Keep, so re-running the fileExists/setResourceValues syscalls per
    /// access was measurable churn for zero extra safety.
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var dir = base.appendingPathComponent("BodyTwin", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }()

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

    private let fileName = BodyTwinFileStorage.stateFile

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

    private let fileName = BodyTwinFileStorage.pendingFile

    /// Review is a decision, not a chore backlog: the queue holds at most
    /// this many snapshots, dropping the OLDEST on overflow. Capture fires on
    /// every entry save, so a daily journaler who ignores the sheet for
    /// months would otherwise accumulate an unbounded pending.json — paid for
    /// in first-Twin-tab decode time and a 3N-file-write "Keep all". 30 is
    /// a month of daily signals; anything older was never going to be
    /// meaningfully reviewed.
    private static let maxPending = 30

    /// Ids the user explicitly Let go of, persisted (ids only — the snapshot
    /// data itself is deleted immediately). A backup exported while one of
    /// these was still pending would otherwise resurrect it on re-import;
    /// the tombstone keeps "Let go" deleted. Capped — see `recordTombstones`.
    private(set) var discardedIds: [UUID]

    @Published private(set) var items: [PendingSnapshot]

    var count: Int { items.count }

    private init() {
        items = BodyTwinFileStorage.read([PendingSnapshot].self, from: fileName) ?? []
        discardedIds = BodyTwinFileStorage.read([UUID].self, from: BodyTwinFileStorage.discardedFile) ?? []
    }

    func enqueue(_ snapshot: HealthSnapshot) {
        items.append(PendingSnapshot(id: UUID(), snapshot: snapshot, createdAt: Date()))
        capOverflow()
        persist()
    }

    /// Let go — removed before the Twin ever saw it, and tombstoned so no
    /// backup re-import can bring it back for review.
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
        recordTombstones([id])
    }

    /// Keep — dequeues and returns the snapshot so the caller can fold it
    /// into the Twin and record it in `KeptSnapshotStore`.
    func keep(id: UUID) -> HealthSnapshot? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let item = items.remove(at: index)
        persist()
        return item.snapshot
    }

    /// Keep all — drains the whole queue in one pass with a single
    /// pending.json write, so the caller can batch-fold and batch-append
    /// instead of paying three file rewrites per snapshot.
    func drainAll() -> [PendingSnapshot] {
        guard !items.isEmpty else { return [] }
        let drained = items
        items = []
        persist()
        return drained
    }

    /// Backup restore: merge imported items in, deduped against ids still
    /// waiting here AND against the Let-go tombstones — a decided Discard
    /// stays decided. The caller (`BodyTwinManager.restoreFromBackup`)
    /// additionally filters out ids already in `KeptSnapshotStore`, so a
    /// decided Keep is never re-queued (and never re-folded).
    func restore(_ imported: [PendingSnapshot]) {
        let existing = Set(items.map(\.id))
        let discarded = Set(discardedIds)
        let added = imported.filter { !existing.contains($0.id) && !discarded.contains($0.id) }
        guard !added.isEmpty else { return }
        items.append(contentsOf: added)
        items.sort { $0.createdAt < $1.createdAt }
        capOverflow()
        persist()
    }

    func wipe() {
        items = []
        persist()
        // A wipe is a full reset — tombstones are bookkeeping for the wiped
        // queue and go with it.
        discardedIds = []
        BodyTwinFileStorage.delete(BodyTwinFileStorage.discardedFile)
    }

    private func persist() {
        BodyTwinFileStorage.write(items, to: fileName)
    }

    /// Enforces `maxPending`, dropping the oldest first (items are kept in
    /// createdAt order).
    private func capOverflow() {
        if items.count > Self.maxPending {
            items.removeFirst(items.count - Self.maxPending)
        }
    }

    private func recordTombstones(_ ids: [UUID]) {
        discardedIds.append(contentsOf: ids)
        // Tombstones only need to outlive the backups a user plausibly
        // re-imports; 200 ids (~3 KB of UUIDs) covers months of decisions
        // without growing forever.
        if discardedIds.count > 200 {
            discardedIds.removeFirst(discardedIds.count - 200)
        }
        BodyTwinFileStorage.write(discardedIds, to: BodyTwinFileStorage.discardedFile)
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
///
/// Accepted trade-off: every append re-encodes and rewrites the full file.
/// At ~350 bytes/snapshot and 1–2 Keeps a day that is well under 1 MB after
/// YEARS of daily journaling — sharding or compaction would be complexity
/// without a felt win. Revisit only if the Watch release multiplies capture
/// frequency.
@MainActor
final class KeptSnapshotStore {
    static let shared = KeptSnapshotStore()

    private let fileName = BodyTwinFileStorage.keptFile
    private var cache: [KeptSnapshot]

    private init() {
        cache = BodyTwinFileStorage.read([KeptSnapshot].self, from: fileName) ?? []
    }

    func append(id: UUID, snapshot: HealthSnapshot, keptAt: Date = Date()) {
        guard !cache.contains(where: { $0.id == id }) else { return }
        cache.append(KeptSnapshot(id: id, snapshot: snapshot, keptAt: keptAt))
        BodyTwinFileStorage.write(cache, to: fileName)
    }

    /// Batch append for "Keep all": one dedupe pass, one file write.
    func appendAll(_ newItems: [KeptSnapshot]) {
        let existing = ids
        let fresh = newItems.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return }
        cache.append(contentsOf: fresh)
        BodyTwinFileStorage.write(cache, to: fileName)
    }

    func loadAll() -> [KeptSnapshot] { cache }

    /// All kept ids — the fold-once invariant's source of truth: an id in
    /// here has already been folded into the Twin exactly once.
    var ids: Set<UUID> { Set(cache.map(\.id)) }

    func contains(id: UUID) -> Bool { cache.contains { $0.id == id } }

    /// Backup restore: merge imported snapshots in, deduped by id.
    func restore(_ imported: [KeptSnapshot]) {
        let existing = Set(cache.map(\.id))
        let added = imported.filter { !existing.contains($0.id) }
        guard !added.isEmpty else { return }
        cache.append(contentsOf: added)
        cache.sort { $0.keptAt < $1.keptAt }
        BodyTwinFileStorage.write(cache, to: fileName)
    }

    func wipe() {
        cache = []
        BodyTwinFileStorage.delete(fileName)
    }
}

// MARK: - Backup Bridge

extension ExportableBodyTwin {
    /// Everything the Body Twin holds, gathered for the encrypted export
    /// from the authoritative in-memory MainActor state — one consistent
    /// payload. Re-reading the three files from the export's background
    /// queue was a torn-read hazard: a Keep mid-export is a three-file
    /// transaction (pending → state → kept), and interleaved per-file reads
    /// could produce a backup whose snapshot is in NEITHER list or whose
    /// counters disagree with kept.json. Gather here on the main actor; only
    /// encode/encrypt/write happen off it.
    @MainActor
    static func currentInMemory() -> ExportableBodyTwin? {
        let bodyTwin = DigitalTwinEngine.shared.bodyTwin
        let payload = ExportableBodyTwin(
            // A pristine sub-model means the feature was never used — omit
            // it so entry-only users keep emitting format-1.0 backups.
            state: bodyTwin == BodyTwin() ? nil : bodyTwin,
            keptSnapshots: KeptSnapshotStore.shared.loadAll(),
            pendingSnapshots: PendingSnapshotQueue.shared.items
        )
        return payload.isEmpty ? nil : payload
    }
}
