//
//  TwinChatEvidenceAdapter.swift
//  solyn
//
//  The app's side of the Twin Brain evidence seam (v1.7). The engine has no
//  Core Data and the semantic index returns only entry ids, so this adapter
//  resolves queries to id + snippet tuples: SemanticSearchManager (which owns
//  the abstention threshold) finds the ids, Core Data supplies the text, and
//  snippets are word-boundary truncated here so raw full entries never reach
//  a prompt. All work hops to the main actor — the same singleton-access
//  discipline as the rest of the app.
//

import Foundation
import CoreData
import DailyVoxTwinEngine

final class TwinChatEvidenceAdapter: TwinChatEvidenceSource, @unchecked Sendable {

    /// Snippet cap matches FoundationTwinChat.Options.snippetMaxChars.
    private let snippetMaxChars: Int

    init(snippetMaxChars: Int = 600) {
        self.snippetMaxChars = snippetMaxChars
    }

    func recall(query: String, topK: Int, dateRange: ClosedRange<Date>?) async -> [TwinChatEvidence] {
        await MainActor.run {
            let hits = SemanticSearchManager.shared.search(query, topK: topK, in: dateRange)
            guard !hits.isEmpty else { return [] }
            let context = PersistenceController.shared.container.viewContext
            return hits.compactMap { hit -> TwinChatEvidence? in
                guard let uuid = UUID(uuidString: hit.id) else { return nil }
                let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
                request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                request.fetchLimit = 1
                guard let entry = (try? context.fetch(request))?.first,
                      let text = entry.text, !text.isEmpty else { return nil }
                return TwinChatEvidence(entryId: hit.id,
                                        date: entry.date ?? Date(timeIntervalSince1970: 0),
                                        snippet: Self.truncate(text, to: snippetMaxChars),
                                        score: hit.score)
            }
        }
    }

    func recentEntries(days: Int) async -> [TwinEntryInput] {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
            request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            guard let entries = try? context.fetch(request) else { return [] }
            return entries.map {
                TwinEntryInput(date: $0.date,
                               text: $0.text,
                               mood: $0.mood,
                               duration: $0.duration,
                               isStarred: $0.isStarred)
            }
        }
    }

    /// Head-truncate at a word boundary. Long entries collapse to their
    /// opening; per-sentence snippet windowing is a Phase E follow-up.
    static func truncate(_ text: String, to maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let head = String(text.prefix(maxChars))
        if let lastSpace = head.lastIndex(of: " "), head.distance(from: head.startIndex, to: lastSpace) > maxChars / 2 {
            return String(head[..<lastSpace]) + "…"
        }
        return head + "…"
    }
}
