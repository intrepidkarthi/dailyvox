import Foundation

/// User-taught words that speech recognition keeps getting wrong — names,
/// places, anything uncommon. Fed into `SFSpeechURLRecognitionRequest`'s
/// `contextualStrings` so recognition is biased toward them on every entry,
/// which is what makes a correction *stick*: transcription itself has no
/// memory, so without this an uncommon name (a child's name, say) is re-heard
/// wrong every single time no matter how often the text is edited afterward.
///
/// Stored locally in UserDefaults — like everything else, it never leaves the
/// device. Apple caps `contextualStrings` influence, so this biases, never
/// forces; a very long list also dilutes the effect, hence the cap.
final class CustomVocabulary: ObservableObject {
    static let shared = CustomVocabulary()

    private let key = "customVocabularyTerms"
    /// Apple's guidance is that contextualStrings works best as a short,
    /// high-value list; keep the most recent N.
    static let maxTerms = 100

    @Published private(set) var terms: [String]

    private init() {
        terms = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// Add a term (trimmed, deduplicated case-insensitively, newest kept).
    func add(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        var next = terms.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        next.insert(term, at: 0)
        if next.count > Self.maxTerms { next = Array(next.prefix(Self.maxTerms)) }
        terms = next
        persist()
    }

    func remove(at offsets: IndexSet) {
        terms.remove(atOffsets: offsets)
        persist()
    }

    func remove(_ term: String) {
        terms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        persist()
    }

    /// The bias list handed to speech recognition. Empty is fine (no bias).
    var contextualStrings: [String] { terms }

    private func persist() {
        UserDefaults.standard.set(terms, forKey: key)
    }
}
