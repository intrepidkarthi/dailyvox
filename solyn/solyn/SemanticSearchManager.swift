import Foundation
import CoreData
import DailyVoxTwinEngine

/// A device-local, file-backed `TwinStateStore` for derived indexes that should
/// NOT sync (the semantic memory index is rebuildable from entries and stays on
/// this iPhone, backup-excluded).
final class LocalFileTwinStateStore: TwinStateStore {
    private let directory: URL

    init(subfolder: String) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent(subfolder, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var dir = directory; try? dir.setResourceValues(values)
        }
    }

    private func url(_ key: String) -> URL { directory.appendingPathComponent("\(key).bin") }

    func loadState(forKey key: String) -> Data? { try? Data(contentsOf: url(key)) }
    func saveState(_ data: Data, forKey key: String) { try? data.write(to: url(key), options: [.atomic]) }
}

/// v1.6 semantic memory — find an entry by meaning, not keywords. Owns the
/// on-device `SemanticMemoryIndex`, keeps it in step with Core Data, and
/// answers phrase queries. Sentence-like queries work best (short keyword
/// queries rank poorly — the UI nudges full phrases).
@MainActor
final class SemanticSearchManager: ObservableObject {
    static let shared = SemanticSearchManager()

    /// Below this top-cosine, the index is declining rather than answering —
    /// the abstention operating point measured by TwinEval's retrieval suite
    /// (τ ≈ 0.37 on synthetic data; re-measure on real diaries before trusting).
    static let abstentionThreshold: Double = 0.37

    private let index = SemanticMemoryIndex(store: LocalFileTwinStateStore(subfolder: "SemanticMemory"))
    private var indexedIds = Set<String>()
    private let indexedIdsKey = "semanticIndexedEntryIds"

    @Published var isReady = false

    private init() {
        indexedIds = Set(UserDefaults.standard.stringArray(forKey: indexedIdsKey) ?? [])
    }

    /// Ensure every entry is indexed (idempotent upsert). Cheap to re-run —
    /// only entries not already indexed are embedded.
    func indexAll(from context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "DiaryEntry")
        guard let entries = try? context.fetch(request) else { isReady = true; return }
        for entry in entries {
            guard let id = (entry.value(forKey: "id") as? UUID)?.uuidString,
                  !indexedIds.contains(id),
                  let text = entry.value(forKey: "text") as? String, !text.isEmpty
            else { continue }
            let date = (entry.value(forKey: "date") as? Date) ?? Date(timeIntervalSince1970: 0)
            if index.index(entryId: id, text: text, date: date) {
                indexedIds.insert(id)
            }
        }
        UserDefaults.standard.set(Array(indexedIds), forKey: indexedIdsKey)
        isReady = true
    }

    /// Index (or re-index) a single entry as it's saved/edited.
    func indexEntry(id: UUID, text: String, date: Date) {
        guard !text.isEmpty else { return }
        if index.index(entryId: id.uuidString, text: text, date: date) {
            indexedIds.insert(id.uuidString)
            UserDefaults.standard.set(Array(indexedIds), forKey: indexedIdsKey)
        }
    }

    func removeEntry(id: UUID) {
        index.remove(entryId: id.uuidString)
        indexedIds.remove(id.uuidString)
        UserDefaults.standard.set(Array(indexedIds), forKey: indexedIdsKey)
    }

    struct Hit: Identifiable {
        let id: String   // entry UUID string
        let score: Double
    }

    /// Search by meaning. Returns [] when the best match is below the
    /// abstention threshold (the honest "I don't have anything on that").
    func search(_ query: String, topK: Int = 12) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }
        let results = index.search(trimmed, topK: topK)
        guard let best = results.first, best.score >= Self.abstentionThreshold else { return [] }
        return results.map { Hit(id: $0.entryId, score: $0.score) }
    }
}
