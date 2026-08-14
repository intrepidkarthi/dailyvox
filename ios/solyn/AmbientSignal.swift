import Foundation

// v1.5.5 Ambient Signals — the first taste of the Twin learning from your day,
// not just your words. Two on-device sources (photos, music) produce only
// DERIVED LABELS — never the photos, never the audio — and every label waits
// in a review-and-discard queue before it reaches the Twin. Same gate the v1.5
// Body Twin introduced; a parallel queue rather than a refactor of the shipped
// health queue, so nothing about Body Twin's behavior changes.
//
// Off by default. "Data Not Collected" preserved: labels are computed on-device
// and, like everything else, never leave it.

/// What produced a signal — drives its icon and copy in the review sheet.
enum AmbientSignalKind: String, Codable {
    case photo   // on-device Photos/Vision scene labels for the day
    case music   // on-device music-library listening mood
}

/// A single derived-label signal offered for review. Carries no media — only
/// the short human-readable label and detail Vision/the library produced.
struct AmbientSignal: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: AmbientSignalKind
    /// The day this signal summarizes (start-of-day).
    let day: Date
    /// Short label, e.g. "Mostly trail photos" / "Reached for calm music".
    let label: String
    /// Optional secondary line, e.g. "one birthday dinner".
    let detail: String?
    let createdAt: Date

    init(id: UUID = UUID(), kind: AmbientSignalKind, day: Date,
         label: String, detail: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.day = day
        self.label = label
        self.detail = detail
        self.createdAt = createdAt
    }
}

/// File-backed storage for ambient signals, alongside (but separate from) the
/// Body Twin files. Backup-excluded like the rest of the passive-signal data.
enum AmbientSignalStorage {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var dir = base.appendingPathComponent("Ambient", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // Exclude from iCloud/iTunes backup — passive signals stay on this device.
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }
    static let pendingFile = "ambient-pending.json"
    static let keptFile = "ambient-kept.json"
    static let discardedFile = "ambient-discarded.json"

    static func read<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func write<T: Encodable>(_ value: T, to fileName: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(fileName), options: [.atomic])
    }
}

/// Ambient signals your day offered, held for review before your Twin learns
/// them. Mirrors `PendingSnapshotQueue`: bounded, tombstoned, MainActor. Keep
/// hands the signal to the caller to fold into the Twin; Let go deletes it
/// unseen and tombstones its id so a backup re-import can't resurrect it.
@MainActor
final class PendingAmbientSignalQueue: ObservableObject {
    static let shared = PendingAmbientSignalQueue()

    private let fileName = AmbientSignalStorage.pendingFile
    /// Review is a decision, not a chore backlog — hold at most a month of
    /// daily signals, dropping the oldest on overflow.
    private static let maxPending = 30
    private static let maxTombstones = 200

    private(set) var discardedIds: [UUID]
    @Published private(set) var items: [AmbientSignal]

    var count: Int { items.count }

    private init() {
        items = AmbientSignalStorage.read([AmbientSignal].self, from: fileName) ?? []
        discardedIds = AmbientSignalStorage.read([UUID].self, from: AmbientSignalStorage.discardedFile) ?? []
    }

    /// Enqueue a freshly-derived signal, unless an identical day+kind is already
    /// pending (don't stack the same day's photo summary twice) or it was
    /// tombstoned.
    func enqueue(_ signal: AmbientSignal) {
        guard !discardedIds.contains(signal.id) else { return }
        guard !items.contains(where: { $0.kind == signal.kind && Calendar.current.isDate($0.day, inSameDayAs: signal.day) }) else { return }
        items.append(signal)
        if items.count > Self.maxPending { items.removeFirst(items.count - Self.maxPending) }
        persist()
    }

    /// Let go — removed before the Twin ever saw it, and tombstoned.
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
        recordTombstones([id])
    }

    /// Keep — dequeues and returns the signal so the caller can fold it into
    /// the Twin and record it in the kept store.
    func keep(id: UUID) -> AmbientSignal? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let item = items.remove(at: index)
        persist()
        return item
    }

    /// Keep all — drains the queue in one write for a batch fold.
    func drainAll() -> [AmbientSignal] {
        guard !items.isEmpty else { return [] }
        let drained = items
        items = []
        persist()
        return drained
    }

    private func recordTombstones(_ ids: [UUID]) {
        discardedIds.append(contentsOf: ids)
        if discardedIds.count > Self.maxTombstones {
            discardedIds.removeFirst(discardedIds.count - Self.maxTombstones)
        }
        AmbientSignalStorage.write(discardedIds, to: AmbientSignalStorage.discardedFile)
    }

    private func persist() {
        AmbientSignalStorage.write(items, to: fileName)
    }
}

/// The signals you Kept — the record of what actually reached your Twin, so
/// insights can show "context you kept" and a re-import can't double-fold.
@MainActor
final class KeptAmbientSignalStore: ObservableObject {
    static let shared = KeptAmbientSignalStore()
    private let fileName = AmbientSignalStorage.keptFile

    @Published private(set) var signals: [AmbientSignal]

    private init() {
        signals = AmbientSignalStorage.read([AmbientSignal].self, from: fileName) ?? []
    }

    func contains(id: UUID) -> Bool { signals.contains { $0.id == id } }

    func append(_ signal: AmbientSignal) {
        guard !contains(id: signal.id) else { return }
        signals.append(signal)
        persist()
    }

    func append(contentsOf newSignals: [AmbientSignal]) {
        var changed = false
        for s in newSignals where !contains(id: s.id) { signals.append(s); changed = true }
        if changed { persist() }
    }

    private func persist() { AmbientSignalStorage.write(signals, to: fileName) }
}
