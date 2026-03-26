//
//  ShareableInsightGenerator.swift
//  solyn
//
//  Generates provocative, shareable weekly insight cards from journal data.
//  Designed to create a viral loop — insights that feel deeply personal
//  but reveal nothing private.
//
//  All analysis is performed on-device using existing data from
//  DigitalTwinEngine, LocalAIEngine, and raw diary entries.
//

import Foundation
import NaturalLanguage

// MARK: - Shareable Insight Model

struct ShareableInsight: Identifiable {
    let id = UUID()
    let headline: String      // The provocative main line
    let subtext: String        // Supporting detail
    let category: Category
    let dataPoint: String?     // Optional stat to display
    let generatedAt: Date

    enum Category: String {
        case emotion = "emotion"
        case pattern = "pattern"
        case people = "people"
        case language = "language"
        case growth = "growth"
        case time = "time"

        var icon: String {
            switch self {
            case .emotion: return "heart.text.square"
            case .pattern: return "waveform.path.ecg"
            case .people: return "person.2"
            case .language: return "text.quote"
            case .growth: return "arrow.up.right"
            case .time: return "clock"
            }
        }

        var accentColorName: String {
            switch self {
            case .emotion: return "pink"
            case .pattern: return "purple"
            case .people: return "orange"
            case .language: return "cyan"
            case .growth: return "green"
            case .time: return "indigo"
            }
        }
    }
}

// MARK: - Generator

struct ShareableInsightGenerator {

    // MARK: - Main Entry Point

    /// Generates up to 3 shareable insights from the past 7 days of entries
    static func generateWeeklyInsights(from entries: [DiaryEntry]) -> [ShareableInsight] {
        let calendar = Calendar.current
        let weekEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return daysAgo <= 7
        }

        guard weekEntries.count >= 3 else { return [] }

        let twin = DigitalTwinEngine.shared
        let profile = LocalAIEngine.shared.userProfile

        var insights: [ShareableInsight] = []

        // Try each generator — collect all, then pick the best 3
        var candidates: [ShareableInsight] = []

        if let insight = topEmotionInsight(weekEntries: weekEntries, profile: profile) {
            candidates.append(insight)
        }
        if let insight = personSentimentInsight(weekEntries: weekEntries, twin: twin) {
            candidates.append(insight)
        }
        if let insight = shouldVsWantInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = dayOfWeekMoodInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = topicAvoidanceInsight(weekEntries: weekEntries, profile: profile) {
            candidates.append(insight)
        }
        if let insight = entryLengthEmotionInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = selfFocusInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = moodTrajectoryInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = timeOfDayMoodInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = vocabularyInsight(weekEntries: weekEntries, twin: twin) {
            candidates.append(insight)
        }
        if let insight = questionVsStatementInsight(weekEntries: weekEntries) {
            candidates.append(insight)
        }
        if let insight = topConcernInsight(weekEntries: weekEntries, twin: twin) {
            candidates.append(insight)
        }

        // Pick up to 3, preferring different categories
        var usedCategories: Set<ShareableInsight.Category> = []
        for candidate in candidates.shuffled() {
            if !usedCategories.contains(candidate.category) {
                insights.append(candidate)
                usedCategories.insert(candidate.category)
            }
            if insights.count >= 3 { break }
        }

        // If we still have room, add from any category
        if insights.count < 3 {
            for candidate in candidates.shuffled() {
                if !insights.contains(where: { $0.headline == candidate.headline }) {
                    insights.append(candidate)
                }
                if insights.count >= 3 { break }
            }
        }

        return insights
    }

    // MARK: - Insight Generators

    /// "Your top emotion this week: guilt. Last week: excitement."
    private static func topEmotionInsight(weekEntries: [DiaryEntry], profile: UserProfile) -> ShareableInsight? {
        let moods = weekEntries.compactMap { entry -> Mood? in
            guard let moodString = entry.value(forKey: "mood") as? String,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { return nil }
            return mood
        }
        guard moods.count >= 3 else { return nil }

        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        guard let topMood = moodCounts.max(by: { $0.value < $1.value }) else { return nil }

        let percentage = Int(Double(topMood.value) / Double(moods.count) * 100)

        return ShareableInsight(
            headline: "Your dominant mood this week:\n\(topMood.key.displayName).",
            subtext: "\(percentage)% of your entries. The rest? Scattered.",
            category: .emotion,
            dataPoint: "\(topMood.key.displayName) \(percentage)%",
            generatedAt: Date()
        )
    }

    /// "You mentioned Sarah 8 times. Your mood drops every time."
    private static func personSentimentInsight(weekEntries: [DiaryEntry], twin: DigitalTwinEngine) -> ShareableInsight? {
        let tagger = NLTagger(tagSchemes: [.nameType, .sentimentScore])
        var personSentiments: [String: (count: Int, totalSentiment: Double)] = [:]

        for entry in weekEntries {
            guard let text = entry.text, !text.isEmpty else { continue }
            tagger.string = text
            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

            // Get overall sentiment
            let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
            sentimentTagger.string = text
            let (sentTag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            let sentiment = Double(sentTag?.rawValue ?? "0") ?? 0.0

            // Find people mentioned
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
                if tag == .personalName {
                    let name = String(text[range])
                    if name.count > 1 {
                        var existing = personSentiments[name] ?? (count: 0, totalSentiment: 0)
                        existing.count += 1
                        existing.totalSentiment += sentiment
                        personSentiments[name] = existing
                    }
                }
                return true
            }
        }

        // Find someone mentioned 3+ times with notable sentiment
        guard let topPerson = personSentiments
            .filter({ $0.value.count >= 3 })
            .max(by: { abs($0.value.totalSentiment / Double($0.value.count)) < abs($1.value.totalSentiment / Double($1.value.count)) })
        else { return nil }

        let avgSentiment = topPerson.value.totalSentiment / Double(topPerson.value.count)
        let moodWord = avgSentiment < -0.1 ? "drops" : avgSentiment > 0.1 ? "lifts" : "stays flat"

        return ShareableInsight(
            headline: "You mentioned \(topPerson.key) \(topPerson.value.count) times this week.",
            subtext: "Your mood \(moodWord) when you do.",
            category: .people,
            dataPoint: "\(topPerson.value.count)x",
            generatedAt: Date()
        )
    }

    /// "You used 'should' 12 times. 'Want' only twice."
    private static func shouldVsWantInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let allText = weekEntries.compactMap { $0.text }.joined(separator: " ").lowercased()

        let obligationWords = ["should", "must", "have to", "need to", "ought to"]
        let desireWords = ["want", "wish", "hope", "dream", "love to", "excited to"]

        var obligationCount = 0
        var desireCount = 0

        for word in obligationWords {
            obligationCount += allText.components(separatedBy: word).count - 1
        }
        for word in desireWords {
            desireCount += allText.components(separatedBy: word).count - 1
        }

        guard obligationCount >= 3 || desireCount >= 3 else { return nil }

        if obligationCount > desireCount * 2 && obligationCount >= 5 {
            return ShareableInsight(
                headline: "You said \"should\" \(obligationCount) times this week.\n\"Want\"? Only \(desireCount).",
                subtext: "You're living by obligation, not desire.",
                category: .language,
                dataPoint: "should: \(obligationCount) vs want: \(desireCount)",
                generatedAt: Date()
            )
        } else if desireCount > obligationCount * 2 && desireCount >= 5 {
            return ShareableInsight(
                headline: "You said \"want\" \(desireCount) times this week.\n\"Should\"? Only \(obligationCount).",
                subtext: "You know what you want. That's rare.",
                category: .language,
                dataPoint: "want: \(desireCount) vs should: \(obligationCount)",
                generatedAt: Date()
            )
        }

        return nil
    }

    /// "You're most anxious on Sundays. Most calm on Wednesdays."
    private static func dayOfWeekMoodInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let calendar = Calendar.current
        var dayMoods: [Int: [Mood]] = [:]

        for entry in weekEntries {
            guard let date = entry.date,
                  let moodString = entry.value(forKey: "mood") as? String,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayMoods[weekday, default: []].append(mood)
        }

        guard dayMoods.count >= 3 else { return nil }

        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let negativeMoods: Set<Mood> = [.anxious, .sad, .angry, .tired]
        let positiveMoods: Set<Mood> = [.happy, .excited, .grateful, .calm]

        // Find most positive and most negative days
        var bestDay: (day: Int, ratio: Double) = (1, 0)
        var worstDay: (day: Int, ratio: Double) = (1, 1)

        for (day, moods) in dayMoods where moods.count >= 1 {
            let positiveRatio = Double(moods.filter { positiveMoods.contains($0) }.count) / Double(moods.count)
            if positiveRatio > bestDay.ratio { bestDay = (day, positiveRatio) }
            if positiveRatio < worstDay.ratio { worstDay = (day, positiveRatio) }
        }

        guard bestDay.day != worstDay.day else { return nil }

        let worstMood = dayMoods[worstDay.day]?
            .filter { negativeMoods.contains($0) }
            .reduce(into: [:]) { counts, mood in counts[mood, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key

        let bestMood = dayMoods[bestDay.day]?
            .filter { positiveMoods.contains($0) }
            .reduce(into: [:]) { counts, mood in counts[mood, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key

        let worstLabel = worstMood?.displayName.lowercased() ?? "low"
        let bestLabel = bestMood?.displayName.lowercased() ?? "good"

        return ShareableInsight(
            headline: "Most \(worstLabel) on \(dayNames[worstDay.day])s.\nMost \(bestLabel) on \(dayNames[bestDay.day])s.",
            subtext: "Your week has a pattern. Do you see it?",
            category: .time,
            dataPoint: nil,
            generatedAt: Date()
        )
    }

    /// "You haven't mentioned [topic] in 2 weeks. You used to talk about it constantly."
    private static func topicAvoidanceInsight(weekEntries: [DiaryEntry], profile: UserProfile) -> ShareableInsight? {
        // Get this week's topics
        let weekText = weekEntries.compactMap { $0.text }.joined(separator: " ").lowercased()

        // Find top historical topics that are absent this week
        let topHistorical = profile.commonTopics
            .sorted { $0.value > $1.value }
            .prefix(5)

        for (topic, count) in topHistorical where count >= 5 {
            let lowered = topic.lowercased()
            if !weekText.contains(lowered) {
                return ShareableInsight(
                    headline: "You haven't mentioned \"\(topic)\" this week.",
                    subtext: "You used to bring it up all the time. What changed?",
                    category: .pattern,
                    dataPoint: "\(count) total mentions before",
                    generatedAt: Date()
                )
            }
        }

        return nil
    }

    /// "Your entries are 3x longer when you're anxious."
    private static func entryLengthEmotionInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        var moodWordCounts: [Mood: [Int]] = [:]

        for entry in weekEntries {
            guard let text = entry.text,
                  let moodString = entry.value(forKey: "mood") as? String,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { continue }
            let wordCount = text.split { $0.isWhitespace }.count
            moodWordCounts[mood, default: []].append(wordCount)
        }

        guard moodWordCounts.count >= 2 else { return nil }

        let averages = moodWordCounts.mapValues { counts -> Double in
            Double(counts.reduce(0, +)) / Double(counts.count)
        }

        guard let longest = averages.max(by: { $0.value < $1.value }),
              let shortest = averages.min(by: { $0.value < $1.value }),
              longest.key != shortest.key,
              shortest.value > 0 else { return nil }

        let ratio = longest.value / shortest.value
        guard ratio >= 1.5 else { return nil }

        let ratioText = ratio >= 2.5 ? "\(Int(ratio))x" : String(format: "%.1fx", ratio)

        return ShareableInsight(
            headline: "You write \(ratioText) more when you're \(longest.key.displayName.lowercased()).",
            subtext: "When you're \(shortest.key.displayName.lowercased())? Barely anything.",
            category: .pattern,
            dataPoint: "\(Int(longest.value)) vs \(Int(shortest.value)) words",
            generatedAt: Date()
        )
    }

    /// "82% of your sentences start with 'I'."
    private static func selfFocusInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let allText = weekEntries.compactMap { $0.text }.joined(separator: " ")
        let sentences = allText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count >= 10 else { return nil }

        let iSentences = sentences.filter { sentence in
            let first = sentence.split(separator: " ").first?.lowercased()
            return first == "i" || first == "i'm" || first == "i've" || first == "i'll" || first == "i'd"
        }

        let ratio = Double(iSentences.count) / Double(sentences.count)
        let percentage = Int(ratio * 100)

        if percentage >= 60 {
            return ShareableInsight(
                headline: "\(percentage)% of your sentences start with \"I\".",
                subtext: "Your journal is about you. But is it about what you do, or what you feel?",
                category: .language,
                dataPoint: "\(percentage)%",
                generatedAt: Date()
            )
        }

        return nil
    }

    /// "Your mood improved every day this week." or "Your mood has been declining since Tuesday."
    private static func moodTrajectoryInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let sorted = weekEntries
            .filter { $0.date != nil }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        var sentiments: [Double] = []

        for entry in sorted {
            guard let text = entry.text, !text.isEmpty else { continue }
            sentimentTagger.string = text
            let (tag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let score = Double(tag?.rawValue ?? "") {
                sentiments.append(score)
            }
        }

        guard sentiments.count >= 4 else { return nil }

        // Check for consistent trend
        let firstHalf = sentiments.prefix(sentiments.count / 2)
        let secondHalf = sentiments.suffix(sentiments.count / 2)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let diff = secondAvg - firstAvg

        if diff > 0.2 {
            return ShareableInsight(
                headline: "Your mood climbed all week.",
                subtext: "Whatever you're doing, it's working.",
                category: .growth,
                dataPoint: nil,
                generatedAt: Date()
            )
        } else if diff < -0.2 {
            return ShareableInsight(
                headline: "Your mood has been sliding this week.",
                subtext: "Small dips are normal. But are you paying attention?",
                category: .emotion,
                dataPoint: nil,
                generatedAt: Date()
            )
        }

        return nil
    }

    /// "You're happiest when you journal at 7am. Darkest entries? 11pm."
    private static func timeOfDayMoodInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let calendar = Calendar.current
        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        var hourSentiments: [Int: [Double]] = [:]

        for entry in weekEntries {
            guard let date = entry.date, let text = entry.text, !text.isEmpty else { continue }
            let hour = calendar.component(.hour, from: date)
            sentimentTagger.string = text
            let (tag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let score = Double(tag?.rawValue ?? "") {
                hourSentiments[hour, default: []].append(score)
            }
        }

        guard hourSentiments.count >= 2 else { return nil }

        let averages = hourSentiments.mapValues { $0.reduce(0, +) / Double($0.count) }
        guard let bestHour = averages.max(by: { $0.value < $1.value }),
              let worstHour = averages.min(by: { $0.value < $1.value }),
              bestHour.key != worstHour.key,
              bestHour.value - worstHour.value > 0.2 else { return nil }

        let formatHour = { (h: Int) -> String in
            if h == 0 { return "midnight" }
            if h == 12 { return "noon" }
            return h < 12 ? "\(h)am" : "\(h - 12)pm"
        }

        return ShareableInsight(
            headline: "Happiest entries at \(formatHour(bestHour.key)).\nDarkest at \(formatHour(worstHour.key)).",
            subtext: "Time of day changes how you think.",
            category: .time,
            dataPoint: nil,
            generatedAt: Date()
        )
    }

    /// "You used 347 unique words this week. That's more expressive than 80% of your weeks."
    private static func vocabularyInsight(weekEntries: [DiaryEntry], twin: DigitalTwinEngine) -> ShareableInsight? {
        let allText = weekEntries.compactMap { $0.text }.joined(separator: " ")
        let words = allText.lowercased().split { $0.isWhitespace || $0.isPunctuation }
        let uniqueWords = Set(words)

        guard words.count >= 50 else { return nil }

        let richness = Double(uniqueWords.count) / Double(words.count)
        let percentage = Int(richness * 100)

        if uniqueWords.count > 200 {
            return ShareableInsight(
                headline: "\(uniqueWords.count) unique words this week.",
                subtext: "Vocabulary richness: \(percentage)%. You have a lot on your mind.",
                category: .language,
                dataPoint: "\(uniqueWords.count) words",
                generatedAt: Date()
            )
        }

        return nil
    }

    /// "You asked 14 questions this week. Answered zero."
    private static func questionVsStatementInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let allText = weekEntries.compactMap { $0.text }.joined(separator: " ")
        let questionCount = allText.components(separatedBy: "?").count - 1
        let exclamationCount = allText.components(separatedBy: "!").count - 1

        guard questionCount >= 5 else { return nil }

        return ShareableInsight(
            headline: "You asked \(questionCount) questions this week.",
            subtext: "Your journal can't answer them. But maybe you already know.",
            category: .pattern,
            dataPoint: "\(questionCount) questions",
            generatedAt: Date()
        )
    }

    /// "Your #1 concern this week: work. It showed up in every single entry."
    private static func topConcernInsight(weekEntries: [DiaryEntry], twin: DigitalTwinEngine) -> ShareableInsight? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        var topicCounts: [String: Int] = [:]
        let entriesWithTopic: [String: Int] = [:]

        for entry in weekEntries {
            guard let text = entry.text, !text.isEmpty else { continue }
            tagger.string = text
            var entryTopics: Set<String> = []

            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
                if tag == .noun {
                    let word = String(text[range]).lowercased()
                    if word.count > 3 && !LocalAIEngine.shared.isStopWord(word) {
                        entryTopics.insert(word)
                    }
                }
                return true
            }

            for topic in entryTopics {
                topicCounts[topic, default: 0] += 1
            }
        }

        // Find a topic that appears in most entries
        let threshold = max(3, weekEntries.count / 2)
        guard let topTopic = topicCounts.filter({ $0.value >= threshold }).max(by: { $0.value < $1.value }) else {
            return nil
        }

        let ratio = Double(topTopic.value) / Double(weekEntries.count)
        let ratioText = ratio >= 0.9 ? "every single entry" : "\(topTopic.value) of \(weekEntries.count) entries"

        return ShareableInsight(
            headline: "Your #1 topic this week:\n\"\(topTopic.key.capitalized)\"",
            subtext: "It showed up in \(ratioText).",
            category: .pattern,
            dataPoint: "\(topTopic.value)/\(weekEntries.count) entries",
            generatedAt: Date()
        )
    }
}

// MARK: - LocalAIEngine Extension

extension LocalAIEngine {
    func isStopWord(_ word: String) -> Bool {
        Self.stopWords.contains(word)
    }
}
