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
import DailyVoxTwinEngine
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

    // MARK: - Language

    /// Whether the generator can read a week, given each entry's text and
    /// stored `transcriptLocale`.
    ///
    /// Every card here is an English read of the person: "should" against
    /// "want", I/me focus, question marks against statements, vocabulary,
    /// concern words, and `NLTagger` sentiment pinned to names. On a Spanish
    /// or Hindi week those do not fail, they answer, and a share card is a
    /// claim about the user made to whoever sees it. So the generator reads a
    /// week only when LanguageGate says every entry in it can be read for
    /// traits and mood (English, today). A week with any entry it cannot read
    /// gives no cards at all: dropping those entries would make every
    /// percentage and count on the cards wrong.
    static func canRead(_ week: [(text: String, language: String?)]) -> Bool {
        week.allSatisfy { FeatureLanguage.readsShareableInsights($0.text, stored: $0.language) }
    }

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
        guard canRead(weekEntries.map { ($0.text ?? "", $0.transcriptLocale) }) else { return [] }

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
    //
    // Mood-based cards read `userMood`: a card is a claim about the user made
    // to whoever it is shared with, so it counts only moods they chose, never
    // ones suggested from their words.

    /// "Your top emotion this week: guilt. Last week: excitement."
    private static func topEmotionInsight(weekEntries: [DiaryEntry], profile: UserProfile) -> ShareableInsight? {
        let moods = weekEntries.compactMap { entry -> Mood? in
            guard let moodString = entry.userMood,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { return nil }
            return mood
        }
        guard moods.count >= 3 else { return nil }

        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        guard let topMood = moodCounts.max(by: { $0.value < $1.value }) else { return nil }

        let percentage = Int(Double(topMood.value) / Double(moods.count) * 100)

        return ShareableInsight(
            headline: String(localized: "Your dominant mood this week:\n\(topMood.key.displayName).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines; the placeholder is a mood name (Happy, Calm, Anxious…). About 40 characters."),
            subtext: String(localized: "\(percentage)% of your entries. The rest? Scattered.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). The placeholder is a percentage from 0 to 100 (the share of the week's entries with that mood). About 45 characters."),
            category: .emotion,
            dataPoint: String(localized: "\(topMood.key.displayName) \(percentage)%", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. A mood name, then the percentage of entries with it (0 to 100)."),
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
        let moodLine = avgSentiment < -0.1
            ? String(localized: "Your mood drops when you do.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Follows 'You mentioned <name> N times this week.': the user's mood is lower in entries that mention that person. About 35 characters.")
            : avgSentiment > 0.1
                ? String(localized: "Your mood lifts when you do.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Follows 'You mentioned <name> N times this week.': the user's mood is higher in entries that mention that person. About 35 characters.")
                : String(localized: "Your mood stays flat when you do.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Follows 'You mentioned <name> N times this week.': the user's mood does not change in entries that mention that person. About 35 characters.")

        return ShareableInsight(
            headline: String(localized: "You mentioned \(topPerson.key) \(topPerson.value.count) times this week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. First placeholder: a person's name from the journal. Second: how many times (3 or more). About 45 characters."),
            subtext: moodLine,
            category: .people,
            dataPoint: String(localized: "weekDecoded.personMentions.count", defaultValue: "\(topPerson.value.count)x", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. How many times a person was mentioned this week, as a multiplier ('8x'). Keep it very short."),
            generatedAt: Date()
        )
    }

    /// "You used 'should' 12 times. 'Want' only twice."
    private static func shouldVsWantInsight(weekEntries: [DiaryEntry]) -> ShareableInsight? {
        let allText = weekEntries.compactMap { $0.text }.joined(separator: " ").lowercased()

        let obligationWords = ["should", "must", "have to", "need to", "ought to"]  // i18n-ignore: English words matched in transcripts
        let desireWords = ["want", "wish", "hope", "dream", "love to", "excited to"]  // i18n-ignore: English words matched in transcripts

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
                headline: String(localized: "You said \"should\" \(obligationCount) times this week.\n\"Want\"? Only \(desireCount).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines. 'should' and 'want' are the English words the user actually said (counted in English text), so keep them in English inside the quotation marks. First placeholder: count of obligation words (should, must, have to…), 5 or more. Second: count of desire words (want, wish, hope…). About 60 characters."),
                subtext: String(localized: "You're living by obligation, not desire.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under the 'should' versus 'want' headline. About 40 characters."),
                category: .language,
                dataPoint: String(localized: "should: \(obligationCount) vs want: \(desireCount)", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. 'should' and 'want' are the English words counted in the user's entries; keep them in English. First placeholder: obligation-word count. Second: desire-word count."),
                generatedAt: Date()
            )
        } else if desireCount > obligationCount * 2 && desireCount >= 5 {
            return ShareableInsight(
                headline: String(localized: "You said \"want\" \(desireCount) times this week.\n\"Should\"? Only \(obligationCount).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines. 'want' and 'should' are the English words the user actually said (counted in English text), so keep them in English inside the quotation marks. First placeholder: count of desire words (want, wish, hope…), 5 or more. Second: count of obligation words (should, must, have to…). About 60 characters."),
                subtext: String(localized: "You know what you want. That's rare.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under the 'want' versus 'should' headline. About 40 characters."),
                category: .language,
                dataPoint: String(localized: "want: \(desireCount) vs should: \(obligationCount)", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. 'want' and 'should' are the English words counted in the user's entries; keep them in English. First placeholder: desire-word count. Second: obligation-word count."),
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
                  let moodString = entry.userMood,
                  let mood = Mood(rawValue: moodString),
                  mood != .none else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayMoods[weekday, default: []].append(mood)
        }

        guard dayMoods.count >= 3 else { return nil }

        // Plural weekday names, as in "on Sundays". Calendar weekday numbering: 1 is Sunday.
        let dayNames = [
            "",
            String(localized: "Sundays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Sundays = every Sunday). One word."),
            String(localized: "Mondays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Mondays = every Monday). One word."),
            String(localized: "Tuesdays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Tuesdays = every Tuesday). One word."),
            String(localized: "Wednesdays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Wednesdays = every Wednesday). One word."),
            String(localized: "Thursdays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Thursdays = every Thursday). One word."),
            String(localized: "Fridays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Fridays = every Friday). One word."),
            String(localized: "Saturdays", comment: "Stats > Your Week, Decoded: weekday in the plural, used in 'Most <mood> on <weekday>.' (on Saturdays = every Saturday). One word."),
        ]
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

        let worstLabel = worstMood?.displayName.lowercased() ?? String(localized: "weekDecoded.moodFallback.low", defaultValue: "low", comment: "Stats > Your Week, Decoded: stands in for a mood name in 'Most <mood> on <weekday>.' when the weekday's low mood has no name. Lower case, one word.")
        let bestLabel = bestMood?.displayName.lowercased() ?? String(localized: "good", comment: "Stats > Your Week, Decoded: stands in for a mood name in 'Most <mood> on <weekday>.' when the weekday's good mood has no name. Lower case, one word.")

        return ShareableInsight(
            headline: String(localized: "Most \(worstLabel) on \(dayNames[worstDay.day]).\nMost \(bestLabel) on \(dayNames[bestDay.day]).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines. Placeholders 1 and 3: a mood name in lower case (anxious, calm…). Placeholders 2 and 4: a weekday in the plural (Sundays). About 30 characters per line."),
            subtext: String(localized: "Your week has a pattern. Do you see it?", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under the weekday pattern headline. About 40 characters."),
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
                    headline: String(localized: "You haven't mentioned \"\(topic)\" this week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The placeholder is a topic word from the user's past entries, shown in quotation marks. About 45 characters."),
                    subtext: String(localized: "You used to bring it up all the time. What changed?", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under 'You haven't mentioned <topic> this week.' About 50 characters."),
                    category: .pattern,
                    dataPoint: String(localized: "\(String(count)) total mentions before", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. The placeholder is how many times the topic came up in earlier weeks (5 or more). It arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count."),
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
                  let moodString = entry.userMood,
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

        let ratioText = ratio >= 2.5
            ? String(localized: "\(Int(ratio))x", comment: "Stats > Your Week, Decoded: a whole-number multiplier ('3x'), used inside 'You write <multiplier> more when you're <mood>.' Keep it very short.")
            : String(localized: "\(LocaleFormat.decimal(ratio, fractionDigits: 1))x", comment: "Stats > Your Week, Decoded: a multiplier with one decimal ('1.8x'), already formatted for the locale, used inside 'You write <multiplier> more when you're <mood>.' Keep it very short.")

        return ShareableInsight(
            headline: String(localized: "You write \(ratioText) more when you're \(longest.key.displayName.lowercased()).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. First placeholder: a multiplier such as '3x' or '1.8x'. Second: a mood name in lower case. About 45 characters."),
            subtext: String(localized: "When you're \(shortest.key.displayName.lowercased())? Barely anything.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). The placeholder is a mood name in lower case. About 40 characters."),
            category: .pattern,
            dataPoint: String(localized: "\(Int(longest.value)) vs \(Int(shortest.value)) words", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. Average words per entry in the two moods: the longest, then the shortest."),
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
                headline: String(localized: "\(percentage)% of your sentences start with \"I\".", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The placeholder is a percentage (60 to 100). It counts English sentences beginning with the word 'I' (I, I'm, I've…), so the quoted I can stay as the English word. About 45 characters."),
                subtext: String(localized: "Your journal is about you. But is it about what you do, or what you feel?", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under the 'sentences start with I' headline. About 75 characters."),
                category: .language,
                dataPoint: String(localized: "\(percentage)%", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. A percentage from 60 to 100."),
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
                headline: String(localized: "Your mood climbed all week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The week's entries read more positive from start to end. About 30 characters."),
                subtext: String(localized: "Whatever you're doing, it's working.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under 'Your mood climbed all week.' About 40 characters."),
                category: .growth,
                dataPoint: nil,
                generatedAt: Date()
            )
        } else if diff < -0.2 {
            return ShareableInsight(
                headline: String(localized: "Your mood has been sliding this week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The week's entries read less positive from start to end. Gentle, not alarming. About 40 characters."),
                subtext: String(localized: "Small dips are normal. But are you paying attention?", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under 'Your mood has been sliding this week.' Gentle, not alarming. About 55 characters."),
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
            if h == 0 { return String(localized: "midnight", comment: "Stats > Your Week, Decoded: the hour 0:00, used in 'Happiest entries at <hour>.' Lower case.") }
            if h == 12 { return String(localized: "noon", comment: "Stats > Your Week, Decoded: the hour 12:00, used in 'Happiest entries at <hour>.' Lower case.") }
            return h < 12
                ? String(localized: "\(h)am", comment: "Stats > Your Week, Decoded: a morning hour, used in 'Happiest entries at <hour>.' The placeholder is the hour from 1 to 11 ('7am'). Use the local way of writing a time of day; 24-hour languages can write the hour as is.")
                : String(localized: "\(h - 12)pm", comment: "Stats > Your Week, Decoded: an afternoon or evening hour, used in 'Happiest entries at <hour>.' The placeholder is the hour on the 12-hour clock, 1 to 11 ('11pm' is 23:00). Use the local way of writing a time of day; 24-hour languages need the hour plus 12.")
        }

        return ShareableInsight(
            headline: String(localized: "Happiest entries at \(formatHour(bestHour.key)).\nDarkest at \(formatHour(worstHour.key)).", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines. Each placeholder is an hour of the day ('7am', 'noon', 'midnight'). About 30 characters per line."),
            subtext: String(localized: "Time of day changes how you think.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under the happiest/darkest hour headline. About 35 characters."),
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
                headline: String(localized: "\(String(uniqueWords.count)) unique words this week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The placeholder is the number of different words used this week (more than 200). It arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count. About 35 characters."),
                subtext: String(localized: "Vocabulary richness: \(percentage)%. You have a lot on your mind.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). The placeholder is a percentage from 0 to 100: different words divided by all words. About 60 characters."),
                category: .language,
                dataPoint: String(localized: "\(String(uniqueWords.count)) words", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. The number of different words used this week, as digits in a string placeholder (never grouped), so the catalog cannot vary it by count."),
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
            headline: String(localized: "You asked \(questionCount) questions this week.", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. The placeholder is the number of question marks in the week's entries (5 or more). About 40 characters."),
            subtext: String(localized: "Your journal can't answer them. But maybe you already know.", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). Under 'You asked N questions this week.' About 60 characters."),
            category: .pattern,
            dataPoint: String(localized: "\(questionCount) questions", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. The number of questions asked this week (5 or more)."),
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
        let ratioText = ratio >= 0.9
            ? String(localized: "every single entry", comment: "Stats > Your Week, Decoded: used in 'It showed up in <how often>.' when the topic was in 90% or more of the week's entries. Lower case.")
            : String(localized: "\(topTopic.value) of \(weekEntries.count) entries", comment: "Stats > Your Week, Decoded: used in 'It showed up in <how often>.' First placeholder: entries that mention the topic. Second: all entries this week (3 or more). Lower case.")

        return ShareableInsight(
            headline: String(localized: "Your #1 topic this week:\n\"\(topTopic.key.capitalized)\"", comment: "Stats > Your Week, Decoded: insight card headline (large type, also drawn into a shared image). The card appears only for weeks the app could read, which today means English entries. Two lines; the placeholder is a noun from the user's own entries, shown in quotation marks. '#1' means most frequent. About 30 characters per line."),
            subtext: String(localized: "It showed up in \(ratioText).", comment: "Stats > Your Week, Decoded: insight card line under the headline (also drawn into a shared image). The placeholder is 'every single entry' or 'N of M entries'. About 35 characters."),
            category: .pattern,
            dataPoint: String(localized: "\(topTopic.value)/\(weekEntries.count) entries", comment: "Stats > Your Week, Decoded: small stat chip on the insight card (also drawn into a shared image). About 20 characters. Entries that mention the topic, then all entries this week ('4/6 entries')."),
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
