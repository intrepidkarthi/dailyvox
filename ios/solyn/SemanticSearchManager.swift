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

    /// Below this top HYBRID score, the index is declining rather than
    /// answering. Single source of truth is the engine's measured operating
    /// point (TwinEval retrieval suite: best-separating τ=0.29, balanced
    /// accuracy 98.2% — the old hardcoded 0.37 was calibrated on synthetic
    /// whole-entry cosine and abstained on essentially every real question).
    static let abstentionThreshold: Double = SemanticMemoryIndex.recommendedAbstentionThreshold

    private let index = SemanticMemoryIndex(store: LocalFileTwinStateStore(subfolder: "SemanticMemory"))  // i18n-ignore: folder name on disk
    private var indexedIds = Set<String>()
    // ".v2" busts the indexed-set cache so every entry re-embeds into the
    // hybrid sentence-level format on next indexAll — legacy whole-entry
    // vectors would otherwise stay on the pure-cosine path and keep
    // abstaining under the new threshold. Re-indexing is ~5 ms/entry.
    //
    // ".v3" (1.14, plan B-10): every entry re-indexes once with its own
    // language. Before, a Spanish entry was embedded with the ENGLISH model
    // and ranked in English space; now it is indexed by its words with
    // Spanish function words removed, and an entry in a language the engine
    // cannot search is left out. English entries re-index to exactly the
    // record they had.
    private let indexedIdsKey = "semanticIndexedEntryIds.v3"

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
            let language = FeatureLanguage.indexLanguage(stored: entry.value(forKey: "transcriptLocale") as? String)
            if index.index(entryId: id, text: text, date: date, language: language) {
                indexedIds.insert(id)
            }
        }
        UserDefaults.standard.set(Array(indexedIds), forKey: indexedIdsKey)
        isReady = true
    }

    /// Index (or re-index) a single entry as it's saved/edited. `language`
    /// is the entry's stored `transcriptLocale`.
    func indexEntry(id: UUID, text: String, date: Date, language: String? = nil) {
        guard !text.isEmpty else { return }
        if index.index(entryId: id.uuidString, text: text, date: date,
                       language: FeatureLanguage.indexLanguage(stored: language)) {
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
        /// True when this entry was ranked by meaning: the query ran in a
        /// language with a sentence model AND the entry is in that same
        /// language. False when it matched on words alone (a Spanish query,
        /// or an English query meeting a Spanish entry), where the score is
        /// word overlap, not closeness of meaning, and must not be shown as a
        /// "% match".
        let byMeaning: Bool
    }

    /// How a query is searched. 1.14: meaning (sentence-embedding) search is
    /// English only; every other language the engine's `LanguageGate` lists
    /// gets word search (`.searchLexical`).
    enum Mode: Equatable {
        case meaning
        case words
    }

    /// The language the engine reads `query` in: the exact composition
    /// `SemanticMemoryIndex.search` uses (`readingLanguage(of:declared:)`
    /// over the language this manager declares for it).
    nonisolated static func searchLanguage(of query: String, speaking: Locale) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return LanguageGate.readingLanguage(of: trimmed,
                                            declared: FeatureLanguage.queryLanguage(trimmed, speaking: speaking))
    }

    /// Whether `query` is searched by meaning or by words. The same gate the
    /// engine applies before it embeds the query (`.searchSemantic`).
    nonisolated static func mode(for query: String,
                                 speaking: Locale = SpeechTranscriber.speakerLocale) -> Mode {
        LanguageGate.supports(.searchSemantic, languageCode: searchLanguage(of: query, speaking: speaking))
            ? .meaning : .words
    }

    /// The mode before anything is typed: what a query in the language the
    /// person speaks gets.
    nonisolated static func defaultMode(speaking: Locale = SpeechTranscriber.speakerLocale) -> Mode {
        LanguageGate.supports(.searchSemantic, locale: speaking) ? .meaning : .words
    }

    /// Search by meaning. Returns [] when the best match is below the
    /// abstention threshold (the honest "I don't have anything on that").
    /// `dateRange` (v1.7) narrows candidates before ranking — the Twin
    /// Brain's recallEntries "monthsBack" window.
    ///
    /// The query is read in its own language when the recogniser is sure of
    /// it, else in the language the person speaks (B-10): the engine embeds it
    /// only against entries in that same language and matches every other
    /// entry by words alone, with that language's function words removed.
    func search(_ query: String, topK: Int = 12, in dateRange: ClosedRange<Date>? = nil,
                speaking: Locale = SpeechTranscriber.speakerLocale) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }
        let language = FeatureLanguage.queryLanguage(trimmed, speaking: speaking)
        let results = index.search(trimmed, topK: topK, in: dateRange, language: language)
        guard let best = results.first, best.score >= Self.abstentionThreshold else { return [] }
        let queryLanguage = Self.searchLanguage(of: trimmed, speaking: speaking)
        let semantic = LanguageGate.supports(.searchSemantic, languageCode: queryLanguage)
        return results.map {
            Hit(id: $0.entryId, score: $0.score,
                byMeaning: semantic && index.language(ofEntry: $0.entryId) == queryLanguage)
        }
    }
}
