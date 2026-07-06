// twin.swift — a local Mac replica of the DailyVox TwinEngine.
//
// Uses the SAME Apple frameworks the app uses on-device:
//   - NaturalLanguage (NLTagger sentiment/nameType/lexicalClass, NLEmbedding)
//   - FoundationModels (the ~3B on-device LLM) for the query layer
//
// It mirrors the three TwinEngine layers:
//   1. extraction  (per entry, at "write" time)
//   2. aggregation (across entries — the rolling profile)
//   3. query       (ask the Twin a question; on-device LLM)
//
// Build once:   swiftc -O twin.swift -o twin
// Or run direct: swift twin.swift <command> ...
//
// Commands:
//   ingest  <entriesDir> <store.json>   read .txt/.md entries, extract features
//   profile <store.json>                print the aggregated Twin profile
//   ask     <store.json> "<question>"   answer as a model of the author (on-device LLM)

import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Function words (stylometric backbone, ~120 common English words)
let FUNCTION_WORDS: Set<String> = [
 "a","about","above","after","again","against","all","am","an","and","any","are","as","at",
 "be","because","been","before","being","below","between","both","but","by",
 "can","could","did","do","does","doing","down","during",
 "each","few","for","from","further","had","has","have","having","he","her","here","hers",
 "herself","him","himself","his","how","i","if","in","into","is","it","its","itself",
 "just","me","more","most","my","myself","no","nor","not","now","of","off","on","once","only",
 "or","other","our","ours","out","over","own","same","she","should","so","some","such",
 "than","that","the","their","theirs","them","themselves","then","there","these","they",
 "this","those","through","to","too","under","until","up","very","was","we","were","what",
 "when","where","which","while","who","whom","why","will","with","would","you","your","yours",
 "yourself","am","really","actually","still","even","much","always","never"
]

let STOP_FOR_TERMS: Set<String> = FUNCTION_WORDS.union(["thing","things","get","got","go","going",
 "day","today","time","like","one","two","lot","bit","want","wanted","make","made","feel","felt"])

// MARK: - Per-entry feature record (extraction layer output)
struct EntryFeatures: Codable {
    var id: String
    var date: String?
    var weekday: String?
    var wordCount: Int
    var sentenceCount: Int
    var avgSentenceLen: Double
    var typeTokenRatio: Double
    var sentiment: Double
    var entities: [String: Int]      // "Name\tType" -> count
    var topTerms: [String: Int]      // content words -> count
    var functionWords: [String: Int] // function word -> count
}

// MARK: - Layer 1: extraction
func extract(_ text: String, id: String, date: String?) -> EntryFeatures {
    // sentiment, averaged over sentences
    var sentCount = 0, scored = 0
    var sentSum = 0.0
    let stag = NLTagger(tagSchemes: [.sentimentScore])
    stag.string = text
    stag.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, _ in
        sentCount += 1
        if let tag, let v = Double(tag.rawValue) { sentSum += v; scored += 1 }
        return true
    }
    let sentiment = scored > 0 ? sentSum / Double(scored) : 0.0

    // tokens: word count, types, function words, content terms
    var words = 0
    var types = Set<String>()
    var funcWords: [String: Int] = [:]
    var terms: [String: Int] = [:]
    let ltag = NLTagger(tagSchemes: [.lexicalClass])
    ltag.string = text
    let opts: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
    ltag.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
        let w = text[range].lowercased()
        guard w.first?.isLetter == true else { return true }
        words += 1
        types.insert(w)
        if FUNCTION_WORDS.contains(w) { funcWords[w, default: 0] += 1 }
        if let tag, [.noun, .verb, .adjective, .adverb].contains(tag),
           w.count > 2, !STOP_FOR_TERMS.contains(w) {
            terms[w, default: 0] += 1
        }
        return true
    }

    // named entities
    var ents: [String: Int] = [:]
    let ntag = NLTagger(tagSchemes: [.nameType])
    ntag.string = text
    ntag.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: opts) { tag, range in
        if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
            let name = String(text[range])
            ents["\(name)\t\(tag.rawValue)", default: 0] += 1
        }
        return true
    }

    return EntryFeatures(
        id: id, date: date, weekday: date.flatMap(weekday(from:)),
        wordCount: words, sentenceCount: sentCount,
        avgSentenceLen: sentCount > 0 ? Double(words) / Double(sentCount) : 0,
        typeTokenRatio: words > 0 ? Double(types.count) / Double(words) : 0,
        sentiment: sentiment, entities: ents, topTerms: terms, functionWords: funcWords)
}

func weekday(from date: String) -> String? {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    guard let d = f.date(from: date) else { return nil }
    let wf = DateFormatter(); wf.dateFormat = "EEEE"; wf.locale = Locale(identifier: "en_US_POSIX")
    return wf.string(from: d)
}

func dateFromFilename(_ name: String) -> String? {
    guard let r = name.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else { return nil }
    return String(name[r])
}

// MARK: - Commands
func cmdIngest(_ dir: String, _ store: String) {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
        print("Cannot read directory: \(dir)"); exit(1)
    }
    var records: [EntryFeatures] = []
    for name in files.sorted() where name.hasSuffix(".txt") || name.hasSuffix(".md") {
        let path = (dir as NSString).appendingPathComponent(name)
        guard let text = try? String(contentsOfFile: path, encoding: .utf8), !text.isEmpty else { continue }
        let f = extract(text, id: name, date: dateFromFilename(name))
        records.append(f)
        print("  ingested \(name): \(f.wordCount) words, sentiment \(String(format: "%+.2f", f.sentiment)), \(f.entities.count) entities")
    }
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]
    try? enc.encode(records).write(to: URL(fileURLWithPath: store))
    print("\nStored \(records.count) entries -> \(store)")
}

func loadStore(_ store: String) -> [EntryFeatures] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: store)),
          let recs = try? JSONDecoder().decode([EntryFeatures].self, from: data) else {
        print("Cannot read store: \(store) (run `ingest` first)"); exit(1)
    }
    return recs
}

func cmdProfile(_ store: String) {
    let recs = loadStore(store)
    guard !recs.isEmpty else { print("No entries."); return }

    var ents: [String: Int] = [:], terms: [String: Int] = [:], funcs: [String: Int] = [:]
    var byWeekday: [String: (sum: Double, n: Int)] = [:]
    var totalWords = 0, totalSent = 0
    var ttrSum = 0.0, sentSum = 0.0
    for r in recs {
        for (k, v) in r.entities { ents[k, default: 0] += v }
        for (k, v) in r.topTerms { terms[k, default: 0] += v }
        for (k, v) in r.functionWords { funcs[k, default: 0] += v }
        totalWords += r.wordCount; totalSent += r.sentenceCount
        ttrSum += r.typeTokenRatio; sentSum += r.sentiment
        if let wd = r.weekday { let c = byWeekday[wd] ?? (0, 0); byWeekday[wd] = (c.sum + r.sentiment, c.n + 1) }
    }
    let n = Double(recs.count)

    let dates = recs.compactMap { $0.date }.sorted()
    print("=== TWIN PROFILE ===")
    print("entries: \(recs.count)   span: \(dates.first ?? "?") -> \(dates.last ?? "?")")
    print("total words: \(totalWords)   avg sentence length: \(String(format: "%.1f", Double(totalWords)/Double(max(totalSent,1)))) words")
    print(String(format: "avg lexical diversity (TTR): %.3f   avg sentiment: %+.3f", ttrSum/n, sentSum/n))

    print("\n-- people / places / orgs you mention (entity graph) --")
    for (k, v) in ents.sorted(by: { $0.value > $1.value }).prefix(15) {
        let parts = k.split(separator: "\t"); print(String(format: "  %3d  %@ (%@)", v, String(parts[0]), parts.count > 1 ? String(parts[1]) : "?"))
    }
    print("\n-- recurring concerns (top content terms) --")
    for (k, v) in terms.sorted(by: { $0.value > $1.value }).prefix(25) { print("  \(v)  \(k)") }

    if byWeekday.count > 1 {
        print("\n-- sentiment by weekday (behavioral pattern) --")
        let order = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        for wd in order { if let c = byWeekday[wd], c.n > 0 {
            print(String(format: "  %-9@ %+.3f  (n=%d)", wd, c.sum/Double(c.n), c.n)) } }
    }

    print("\n-- voiceprint (top function words, your stylometric signature) --")
    let totalFunc = funcs.values.reduce(0, +)
    for (k, v) in funcs.sorted(by: { $0.value > $1.value }).prefix(20) {
        print(String(format: "  %5.2f%%  %@", Double(v)/Double(max(totalFunc,1))*100, k))
    }

    // persist a compact profile for the query layer
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    let summary: [String: String] = [
        "entries": "\(recs.count)", "span": "\(dates.first ?? "?")..\(dates.last ?? "?")",
        "top_people": ents.sorted { $0.value > $1.value }.prefix(8).map { String($0.key.split(separator: "\t")[0]) }.joined(separator: ", "),
        "concerns": terms.sorted { $0.value > $1.value }.prefix(12).map { $0.key }.joined(separator: ", ")
    ]
    if let d = try? enc.encode(summary) {
        let p = (store as NSString).deletingPathExtension + "_profile.json"
        try? d.write(to: URL(fileURLWithPath: p)); print("\nprofile summary -> \(p)")
    }
}

func cmdAsk(_ store: String, _ question: String) {
    let recs = loadStore(store)
    var ents: [String: Int] = [:], terms: [String: Int] = [:]
    for r in recs { for (k, v) in r.entities { ents[k, default: 0] += v }; for (k, v) in r.topTerms { terms[k, default: 0] += v } }
    let people = ents.sorted { $0.value > $1.value }.prefix(10).map { String($0.key.split(separator: "\t")[0]) }.joined(separator: ", ")
    let concerns = terms.sorted { $0.value > $1.value }.prefix(15).map { $0.key }.joined(separator: ", ")
    let recent = recs.suffix(5).compactMap { r -> String? in nil } // (entry text not stored; profile-only context)
    _ = recent
    let context = """
    The following facts were derived on-device from the author's journal of \(recs.count) entries.
    People/places they mention most: \(people).
    Recurring concerns and themes: \(concerns).
    """

    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            let sem = DispatchSemaphore(value: 0)
            Task {
                do {
                    let session = LanguageModelSession(instructions: """
                    You are a private, on-device model of one person, built from their journal.
                    Answer ONLY from the provided facts, in their service. Be concrete and brief.
                    If the facts do not support an answer, say so plainly.
                    """)
                    let prompt = "\(context)\n\nQuestion: \(question)"
                    let resp = try await session.respond(to: prompt)
                    print(resp.content)
                } catch { print("Query failed: \(error)") }
                sem.signal()
            }
            sem.wait()
        case .unavailable(let reason):
            print("On-device model unavailable (\(reason)). Context the Twin would use:\n\(context)")
        }
        return
    }
    #endif
    print("FoundationModels not available on this OS. Context the Twin would use:\n\(context)")
}

// MARK: - Layer 3b: generation (the personal Turing test)
// Generates two passages on the same topic: a generic BASELINE and one
// STYLED on the author's own writing. Score both with measure/voiceprint.py.
func cmdGenerate(_ exemplarsPath: String, _ outDir: String, _ topic: String) {
    guard let raw = try? String(contentsOfFile: exemplarsPath, encoding: .utf8), !raw.isEmpty else {
        print("Cannot read exemplars: \(exemplarsPath)"); exit(1)
    }
    let words = raw.split(whereSeparator: { $0.isWhitespace })
    let sample = words.prefix(1000).joined(separator: " ")  // ~1000-word style sample, fits on-device context
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        guard case .available = SystemLanguageModel.default.availability else {
            print("On-device model unavailable."); return
        }
        let sem = DispatchSemaphore(value: 0)
        Task {
            do {
                let base = LanguageModelSession(instructions:
                    "You are a writer. Write a short, reflective first-person journal entry of about 200 words. Plain prose only.")
                let baseResp = try await base.respond(to: "Write a journal entry about: \(topic)")

                let styled = LanguageModelSession(instructions: """
                Below are writing samples in a particular personal style. Study the style closely: \
                sentence length and rhythm, frequency of the word "I", plain versus ornate word choice, \
                punctuation, and cadence. Then write a NEW first-person journal entry of about 200 words \
                in that same writing style. Match the STYLE, not the content — write fresh sentences about \
                the given topic; do not copy phrases or reuse the sample's specific stories.

                WRITING SAMPLES:
                \(sample)
                """)
                let styledResp = try await styled.respond(to: "In that same writing style, write a journal entry about: \(topic)")

                let baseOut = (outDir as NSString).appendingPathComponent("baseline.txt")
                let styledOut = (outDir as NSString).appendingPathComponent("styled.txt")
                try baseResp.content.write(toFile: baseOut, atomically: true, encoding: .utf8)
                try styledResp.content.write(toFile: styledOut, atomically: true, encoding: .utf8)

                print("=== BASELINE (generic voice) ===\n\(baseResp.content)\n")
                print("=== STYLED (conditioned on your writing) ===\n\(styledResp.content)\n")
                print("wrote \(baseOut)\n      \(styledOut)")
                print("\nNow score both:")
                print("  python3 measure/voiceprint.py score voiceprint.json \(styledOut)")
                print("  python3 measure/voiceprint.py score voiceprint.json \(baseOut)")
            } catch { print("Generation failed: \(error)") }
            sem.signal()
        }
        sem.wait()
        return
    }
    #endif
    print("FoundationModels not available on this OS.")
}

// MARK: - Entry point
let args = CommandLine.arguments
guard args.count >= 2 else {
    print("""
    twin — local DailyVox TwinEngine replica
      twin ingest  <entriesDir> <store.json>
      twin profile <store.json>
      twin ask      <store.json> "<question>"
      twin generate <exemplars.txt> <outDir> "<topic>"
    """); exit(0)
}
switch args[1] {
case "ingest"  where args.count >= 4: cmdIngest(args[2], args[3])
case "profile" where args.count >= 3: cmdProfile(args[2])
case "ask"     where args.count >= 4: cmdAsk(args[2], args[3])
case "generate" where args.count >= 5: cmdGenerate(args[2], args[3], args[4])
default: print("Unknown/incomplete command. Run `twin` for usage."); exit(1)
}
