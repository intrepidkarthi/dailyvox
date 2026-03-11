//
//  InsightsEngine.swift
//  solyn
//
//  AI-powered insights and summaries using on-device NLP.
//  All analysis is performed locally - no data sent to external servers.
//
//  Privacy: Uses Apple's NaturalLanguage framework for sentiment analysis
//  and topic extraction. All processing happens on-device.
//

import Foundation
import NaturalLanguage

/// Generates insights and summaries from diary entries using on-device NLP.
/// All analysis is performed locally using Apple's NaturalLanguage framework.
struct InsightsEngine {

    // MARK: - Insight Types

    struct Insight: Identifiable {
        let id = UUID()
        let type: InsightType
        let title: String
        let description: String
        let icon: String
        let color: String // Color name for SwiftUI
    }

    enum InsightType {
        case streak
        case mood
        case productivity
        case pattern
        case suggestion
        case milestone
    }

    // MARK: - Generate Insights

    static func generateInsights(from entries: [DiaryEntry]) -> [Insight] {
        var insights: [Insight] = []

        // Streak insights
        if let streakInsight = analyzeStreak(entries) {
            insights.append(streakInsight)
        }

        // Mood insights
        if let moodInsight = analyzeMoodPatterns(entries) {
            insights.append(moodInsight)
        }

        // Writing pattern insights
        if let patternInsight = analyzeWritingPatterns(entries) {
            insights.append(patternInsight)
        }

        // Productivity insights
        if let productivityInsight = analyzeProductivity(entries) {
            insights.append(productivityInsight)
        }

        // Milestone insights
        insights.append(contentsOf: checkMilestones(entries))

        // Sentiment analysis
        if let sentimentInsight = analyzeSentiment(entries) {
            insights.append(sentimentInsight)
        }

        // Topic analysis
        if let topicInsight = analyzeTopics(entries) {
            insights.append(topicInsight)
        }

        return insights
    }

    // MARK: - Streak Analysis

    private static func analyzeStreak(_ entries: [DiaryEntry]) -> Insight? {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's an entry today
        let hasToday = entries.contains { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: checkDate)
        }

        if !hasToday {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count streak
        while entries.contains(where: { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: checkDate)
        }) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        if streak >= 7 {
            return Insight(
                type: .streak,
                title: "🔥 You're on fire!",
                description: "You've written for \(streak) days in a row. Keep the momentum going!",
                icon: "flame.fill",
                color: "orange"
            )
        } else if streak >= 3 {
            return Insight(
                type: .streak,
                title: "Building a habit",
                description: "\(streak) day streak! You're developing a great journaling habit.",
                icon: "arrow.up.right",
                color: "green"
            )
        } else if !hasToday && streak == 0 {
            return Insight(
                type: .suggestion,
                title: "Time to write",
                description: "You haven't journaled today. Even a few words can make a difference!",
                icon: "pencil.line",
                color: "blue"
            )
        }

        return nil
    }

    // MARK: - Mood Analysis

    private static func analyzeMoodPatterns(_ entries: [DiaryEntry]) -> Insight? {
        let calendar = Calendar.current
        let recentEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return daysAgo <= 7
        }

        let moods = recentEntries.compactMap { entry -> Mood? in
            guard let moodString = entry.value(forKey: "mood") as? String,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { return nil }
            return mood
        }

        guard moods.count >= 3 else { return nil }

        let positiveMoods: Set<Mood> = [.happy, .excited, .grateful, .calm]
        let positiveCount = moods.filter { positiveMoods.contains($0) }.count
        let positiveRatio = Double(positiveCount) / Double(moods.count)

        if positiveRatio >= 0.7 {
            return Insight(
                type: .mood,
                title: "Positive week!",
                description: "You've been feeling great lately. \(Int(positiveRatio * 100))% of your recent moods were positive.",
                icon: "sun.max.fill",
                color: "yellow"
            )
        } else if positiveRatio <= 0.3 {
            return Insight(
                type: .mood,
                title: "Tough week",
                description: "It seems like you've had some challenging days. Remember, it's okay to have difficult moments.",
                icon: "heart.fill",
                color: "pink"
            )
        }

        // Check for mood improvement
        let firstHalf = Array(moods.prefix(moods.count / 2))
        let secondHalf = Array(moods.suffix(moods.count / 2))

        let firstPositive = Double(firstHalf.filter { positiveMoods.contains($0) }.count) / Double(max(1, firstHalf.count))
        let secondPositive = Double(secondHalf.filter { positiveMoods.contains($0) }.count) / Double(max(1, secondHalf.count))

        if secondPositive > firstPositive + 0.3 {
            return Insight(
                type: .mood,
                title: "Mood improving",
                description: "Your mood has been trending upward recently. Keep doing what you're doing!",
                icon: "arrow.up.heart.fill",
                color: "green"
            )
        }

        return nil
    }

    // MARK: - Writing Patterns

    private static func analyzeWritingPatterns(_ entries: [DiaryEntry]) -> Insight? {
        let calendar = Calendar.current

        // Analyze time of day
        var morningCount = 0
        var eveningCount = 0

        for entry in entries.prefix(30) {
            guard let date = entry.date else { continue }
            let hour = calendar.component(.hour, from: date)
            if hour < 12 {
                morningCount += 1
            } else if hour >= 18 {
                eveningCount += 1
            }
        }

        if morningCount > eveningCount * 2 {
            return Insight(
                type: .pattern,
                title: "Morning writer",
                description: "You tend to journal in the morning. Starting the day with reflection is a great habit!",
                icon: "sunrise.fill",
                color: "orange"
            )
        } else if eveningCount > morningCount * 2 {
            return Insight(
                type: .pattern,
                title: "Evening reflector",
                description: "You prefer journaling in the evening. Reflecting on your day helps process experiences.",
                icon: "moon.stars.fill",
                color: "indigo"
            )
        }

        return nil
    }

    // MARK: - Productivity Analysis

    private static func analyzeProductivity(_ entries: [DiaryEntry]) -> Insight? {
        let calendar = Calendar.current
        let thisMonth = entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        }

        let lastMonth = entries.filter { entry in
            guard let date = entry.date,
                  let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: Date()) else { return false }
            return calendar.isDate(date, equalTo: lastMonthDate, toGranularity: .month)
        }

        let thisMonthWords = thisMonth.reduce(0) { $0 + ($1.text ?? "").split { $0.isWhitespace }.count }
        let lastMonthWords = lastMonth.reduce(0) { $0 + ($1.text ?? "").split { $0.isWhitespace }.count }

        if lastMonthWords > 0 && thisMonthWords > lastMonthWords {
            let increase = Int(Double(thisMonthWords - lastMonthWords) / Double(lastMonthWords) * 100)
            if increase >= 20 {
                return Insight(
                    type: .productivity,
                    title: "Writing more!",
                    description: "You've written \(increase)% more this month compared to last month. Great progress!",
                    icon: "chart.line.uptrend.xyaxis",
                    color: "green"
                )
            }
        }

        return nil
    }

    // MARK: - Milestones

    private static func checkMilestones(_ entries: [DiaryEntry]) -> [Insight] {
        var milestones: [Insight] = []
        let count = entries.count

        let milestoneNumbers = [10, 25, 50, 100, 200, 365, 500, 1000]
        for milestone in milestoneNumbers {
            if count >= milestone && count < milestone + 5 {
                milestones.append(Insight(
                    type: .milestone,
                    title: "\(milestone) entries!",
                    description: "Congratulations! You've reached \(milestone) diary entries. That's amazing dedication!",
                    icon: "trophy.fill",
                    color: "yellow"
                ))
                break
            }
        }

        return milestones
    }

    // MARK: - Sentiment Analysis

    private static func analyzeSentiment(_ entries: [DiaryEntry]) -> Insight? {
        let recentTexts = entries.prefix(10).compactMap { $0.text }.filter { !$0.isEmpty }
        guard !recentTexts.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var totalSentiment: Double = 0

        for text in recentTexts {
            tagger.string = text
            let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let sentimentValue = sentiment?.rawValue, let score = Double(sentimentValue) {
                totalSentiment += score
            }
        }

        let avgSentiment = totalSentiment / Double(recentTexts.count)

        if avgSentiment > 0.3 {
            return Insight(
                type: .mood,
                title: "Positive writing",
                description: "Your recent entries have a positive tone. Writing about good things reinforces happiness!",
                icon: "face.smiling.fill",
                color: "green"
            )
        } else if avgSentiment < -0.3 {
            return Insight(
                type: .suggestion,
                title: "Try gratitude",
                description: "Consider writing about things you're grateful for. It can help shift perspective.",
                icon: "heart.text.square.fill",
                color: "pink"
            )
        }

        return nil
    }

    // MARK: - Topic Analysis

    private static func analyzeTopics(_ entries: [DiaryEntry]) -> Insight? {
        let recentTexts = entries.prefix(20).compactMap { $0.text }.filter { !$0.isEmpty }
        guard recentTexts.count >= 5 else { return nil }

        let combinedText = recentTexts.joined(separator: " ")
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = combinedText

        var topics: [String: Int] = [:]
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]

        tagger.enumerateTags(in: combinedText.startIndex..<combinedText.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(combinedText[range])
                topics[word, default: 0] += 1
            }
            return true
        }

        if let topTopic = topics.max(by: { $0.value < $1.value }), topTopic.value >= 3 {
            return Insight(
                type: .pattern,
                title: "Recurring theme",
                description: "'\(topTopic.key)' appears frequently in your entries. It seems important to you.",
                icon: "text.magnifyingglass",
                color: "purple"
            )
        }

        return nil
    }

    // MARK: - Weekly Summary

    static func generateWeeklySummary(from entries: [DiaryEntry]) -> String {
        let calendar = Calendar.current
        let weekEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return daysAgo <= 7
        }

        guard !weekEntries.isEmpty else {
            return "No entries this week. Start journaling to see your weekly summary!"
        }

        let entryCount = weekEntries.count
        let wordCount = weekEntries.reduce(0) { $0 + ($1.text ?? "").split { $0.isWhitespace }.count }

        let moods = weekEntries.compactMap { entry -> Mood? in
            guard let moodString = entry.value(forKey: "mood") as? String,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { return nil }
            return mood
        }

        var summary = "This week you wrote \(entryCount) \(entryCount == 1 ? "entry" : "entries") with \(wordCount) words. "

        if !moods.isEmpty {
            let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
            if let topMood = moodCounts.max(by: { $0.value < $1.value }) {
                summary += "Your most common mood was \(topMood.key.displayName.lowercased()). "
            }
        }

        return summary
    }
}
