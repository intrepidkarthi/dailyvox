//
//  EntryReflection.swift
//  solyn
//
//  What the Today screen gives back once an entry is saved.
//

import Foundation
import DailyVoxTwinEngine

/// The per-entry reflection, lifted out of the collapsed "AI Insights" panel
/// in `EntryDetailView` so it can be shown at the moment it is earned: right
/// after saving. Before this, speaking for a minute got you four lines of your
/// own transcript back and nothing else.
///
/// Not shown yet. The only source for the reflection today is
/// `LocalAIEngine.analyze(text:)`, and that call is not read-only: it also
/// updates and saves the user profile (entry count, topics, people, places).
/// Running it on every save would recount a day's earlier segments with each
/// new recording, and the inflated counts feed back into the reflection
/// ("'<topic>' comes up often for you") and the Twin. So this type only
/// shapes a result handed to it, and calls nothing in the engine; the Today
/// screen wires it in once the engine has a side-effect-free entry point.
struct EntryReflection: Equatable {
    /// The entry this belongs to, so a reflection never outlives its day.
    let entryID: UUID?
    /// The engine's reflection for the entry, verbatim.
    let reflection: String
    /// A name the entry actually contains, to carry into tomorrow — or nil.
    let anchor: String?

    /// Builds the reflection from an analysis already made of the entry's
    /// full text. Pure: it never runs the engine itself.
    static func make(entryText: String, entryID: UUID?, analysis: AIAnalysisResult) -> EntryReflection? {
        make(entryText: entryText, entryID: entryID,
             suggestedResponse: analysis.suggestedResponse,
             people: analysis.people, places: analysis.places)
    }

    static func make(entryText: String, entryID: UUID?, suggestedResponse: String,
                     people: [String], places: [String]) -> EntryReflection? {
        let text = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let reflection = suggestedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reflection.isEmpty else { return nil }
        return EntryReflection(
            entryID: entryID,
            reflection: reflection,
            anchor: groundedAnchor(people: people, places: places, in: text))
    }

    /// One person or place to pick up tomorrow, only if the entry says it.
    ///
    /// The tagger's names are re-checked against the text itself: a "for
    /// tomorrow" line about someone you never mentioned would be the app
    /// putting words in your mouth, and silence is always the better miss.
    /// People before places, because "you mentioned Sarah" is the more useful
    /// thread to pull; within each, the one said first, so the choice does not
    /// depend on the tagger's (unordered) output. Whole words only: "Sam" is
    /// not in "samosa".
    static func groundedAnchor(people: [String], places: [String], in text: String) -> String? {
        func firstMentioned(_ names: [String]) -> String? {
            names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                // A single letter or a stray token is not a name worth
                // carrying forward.
                .filter { $0.count >= 2 && $0.first?.isLetter == true }
                .compactMap { name -> (String, Int)? in
                    let pattern = "\\b" + NSRegularExpression.escapedPattern(for: name) + "\\b"
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
                    else { return nil }
                    return (name, match.range.location)
                }
                .min { $0.1 < $1.1 }?
                .0
        }
        return firstMentioned(people) ?? firstMentioned(places)
    }
}
