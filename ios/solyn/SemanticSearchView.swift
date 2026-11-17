import SwiftUI
import CoreData

/// v1.6 semantic search — find an entry by what you meant, not the exact words.
/// Phrase queries work best (the field nudges this). Results are ranked by
/// meaning; if nothing is close enough, the Twin says so rather than guessing.
///
/// 1.14: meaning search is English only. A query the engine reads in another
/// language is a WORD search, and the screen says so: plain title, a word
/// placeholder, no "% match" (word overlap is not closeness of meaning). The
/// mode is the manager's decision (`SemanticSearchManager.mode`), the same
/// gate the engine applies, never a guess from the UI language.
struct SemanticSearchView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var search = SemanticSearchManager.shared

    @State private var query = ""
    @State private var hits: [SemanticSearchManager.Hit] = []
    @State private var didSearch = false
    /// Meaning or words: before a search, what the person's speaking
    /// language gets; after one, how that query actually ran.
    @State private var mode = SemanticSearchManager.defaultMode()

    var body: some View {
        NavigationStack {
            List {
                if didSearch && hits.isEmpty && query.trimmingCharacters(in: .whitespaces).count >= 3 {
                    if mode == .meaning {
                        ContentUnavailableView(
                            "Nothing close enough",
                            systemImage: "text.magnifyingglass",
                            description: Text("Your Twin doesn't have an entry that matches this meaning. Try a fuller phrase — \u{201C}the day I decided to leave my job\u{201D} works better than \u{201C}job\u{201D}.")
                        )
                    } else {
                        ContentUnavailableView(
                            "No entries with these words",
                            systemImage: "text.magnifyingglass",
                            description: Text("Search looks for the words you type. Try another word or a name. Searching by meaning works in English for now.")
                        )
                    }
                }
                ForEach(hits) { hit in
                    if let entry = entry(for: hit.id) {
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            resultRow(entry: entry, hit: hit)
                        }
                    }
                }
            }
            .navigationTitle(mode == .meaning ? Text("Search by meaning") : Text("Search your journal"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query,
                        prompt: mode == .meaning ? Text("Describe what you're looking for")
                                                 : Text("Search for a word or a name"))
            .onSubmit(of: .search, runSearch)
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    hits = []; didSearch = false
                    mode = SemanticSearchManager.defaultMode()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                search.indexAll(from: context)
                // Screenshot mode only: run a real query so the store frame
                // shows ranked results rather than an empty field.
                if ScreenshotScene.current == .search {
                    query = ScreenshotScene.cannedQuery
                    runSearch()
                }
            }
        }
    }

    private func runSearch() {
        mode = SemanticSearchManager.mode(for: query)
        hits = search.search(query)
        didSearch = true
    }

    private func resultRow(entry: DiaryEntry, hit: SemanticSearchManager.Hit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text ?? "")
                .font(.dv(.subheadline))
                .lineLimit(2)
            HStack(spacing: 8) {
                if let date = entry.date {
                    Text(date, style: .date)
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                }
                // Only a hit ranked by meaning has a meaning score to show.
                // A word match's score is word overlap: shown as nothing.
                if hit.byMeaning {
                    Text("· \(Int(hit.score * 100))% match")
                        .font(.dv(.caption2))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func entry(for idString: String) -> DiaryEntry? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
