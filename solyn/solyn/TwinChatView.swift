//
//  TwinChatView.swift
//  solyn
//
//  Ask Your Twin - a conversational interface to explore your journal data.
//  All responses are generated from on-device Digital Twin data.
//  No external APIs or LLMs are used.
//

import SwiftUI
import DailyVoxTwinEngine

// MARK: - Question Types

enum TwinQuestion: String, CaseIterable, Identifiable {
    case moodPattern = "What's my mood pattern this week?"
    case talkAboutMost = "Who do I talk about most?"
    case happiestWhen = "When am I happiest?"
    case dominantTopics = "What topics dominate my thoughts?"
    case moodOverTime = "How has my mood changed over time?"
    case communicationStyle = "What's my communication style?"
    case stressTriggers = "What triggers my stress?"
    case positiveOrNegative = "Am I more positive or negative overall?"
    case personality = "What's my personality like?"
    case bestJournalTime = "What time should I journal?"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .moodPattern: return "chart.line.uptrend.xyaxis"
        case .talkAboutMost: return "person.2.fill"
        case .happiestWhen: return "sun.max.fill"
        case .dominantTopics: return "tag.fill"
        case .moodOverTime: return "arrow.up.right"
        case .communicationStyle: return "text.bubble.fill"
        case .stressTriggers: return "bolt.heart.fill"
        case .positiveOrNegative: return "plusminus"
        case .personality: return "person.crop.circle.fill"
        case .bestJournalTime: return "clock.fill"
        }
    }
}

// MARK: - Chat Message

struct TwinChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Response Generator

struct TwinResponseGenerator {

    private static let insufficientData = "I need more journal entries to answer that well. Keep journaling and I'll have better insights for you soon!"

    static func generateResponse(for question: TwinQuestion) -> String {
        let twin = DigitalTwinEngine.shared
        let profile = LocalAIEngine.shared.userProfile
        let hasEnoughData = twin.summary.dataPointsCollected >= 5

        switch question {
        case .moodPattern:
            return moodPatternResponse(twin: twin, hasData: hasEnoughData)
        case .talkAboutMost:
            return talkAboutMostResponse(twin: twin, hasData: hasEnoughData)
        case .happiestWhen:
            return happiestWhenResponse(twin: twin, hasData: hasEnoughData)
        case .dominantTopics:
            return dominantTopicsResponse(twin: twin, profile: profile, hasData: hasEnoughData)
        case .moodOverTime:
            return moodOverTimeResponse(twin: twin, hasData: hasEnoughData)
        case .communicationStyle:
            return communicationStyleResponse(twin: twin, hasData: hasEnoughData)
        case .stressTriggers:
            return stressTriggersResponse(twin: twin, hasData: hasEnoughData)
        case .positiveOrNegative:
            return positiveOrNegativeResponse(twin: twin, hasData: hasEnoughData)
        case .personality:
            return personalityResponse(twin: twin, hasData: hasEnoughData)
        case .bestJournalTime:
            return bestJournalTimeResponse(twin: twin, profile: profile, hasData: hasEnoughData)
        }
    }

    // MARK: - Individual Response Builders

    private static func moodPatternResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let sig = twin.emotionalSignature
        var parts: [String] = []

        // Recent sentiments
        if !sig.recentSentiments.isEmpty {
            let recent = Array(sig.recentSentiments.suffix(7))
            let avg = recent.reduce(0, +) / Double(recent.count)
            let moodWord: String
            if avg > 0.3 { moodWord = "quite positive" }
            else if avg > 0.1 { moodWord = "generally good" }
            else if avg > -0.1 { moodWord = "fairly balanced" }
            else if avg > -0.3 { moodWord = "a bit low" }
            else { moodWord = "on the tougher side" }
            parts.append("Your recent mood has been \(moodWord).")
        }

        // Weekday vs weekend
        let weekdayLabel = sentimentWord(sig.weekdayMood)
        let weekendLabel = sentimentWord(sig.weekendMood)
        if weekdayLabel != weekendLabel {
            parts.append("Weekdays feel \(weekdayLabel), while weekends are \(weekendLabel).")
        } else {
            parts.append("Your mood stays pretty consistent between weekdays and weekends.")
        }

        // Emotional range
        if sig.emotionalRange > 0.6 {
            parts.append("You experience a wide range of emotions - lots of highs and lows.")
        } else if sig.emotionalRange < 0.3 {
            parts.append("Your emotions tend to stay steady without big swings.")
        }

        return parts.isEmpty ? insufficientData : parts.joined(separator: " ")
    }

    private static func talkAboutMostResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let people = twin.knowledgeGraph.topNodes(ofType: .person, limit: 5)
        guard !people.isEmpty else {
            return "I haven't picked up on specific people in your entries yet. Try mentioning people by name and I'll start tracking who matters most to you."
        }

        var parts: [String] = []
        let top = people[0]
        parts.append("\(top.label) comes up the most in your journal (\(top.mentions) mentions).")

        if top.sentimentAssociation > 0.2 {
            parts.append("You tend to feel positive when writing about them.")
        } else if top.sentimentAssociation < -0.2 {
            parts.append("Entries about them carry some heavier emotions.")
        }

        if people.count > 1 {
            let others = people.dropFirst().prefix(3).map { $0.label }
            parts.append("You also mention \(others.joined(separator: ", ")) frequently.")
        }

        return parts.joined(separator: " ")
    }

    private static func happiestWhenResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let sig = twin.emotionalSignature
        var parts: [String] = []

        // Time of day
        let morningBetter = sig.morningMood > sig.eveningMood
        if abs(sig.morningMood - sig.eveningMood) > 0.1 {
            parts.append("You tend to be happier in the \(morningBetter ? "morning" : "evening").")
        } else {
            parts.append("Your mood is fairly consistent throughout the day.")
        }

        // Weekday vs weekend
        if sig.weekendMood > sig.weekdayMood + 0.1 {
            parts.append("Weekends clearly lift your spirits.")
        } else if sig.weekdayMood > sig.weekendMood + 0.1 {
            parts.append("Interestingly, you seem happier on weekdays.")
        }

        // Positive triggers
        let positiveTriggers = sig.positiveTriggersTopics
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key.capitalized }

        if !positiveTriggers.isEmpty {
            parts.append("Topics that lift your mood include: \(positiveTriggers.joined(separator: ", ")).")
        }

        return parts.isEmpty ? insufficientData : parts.joined(separator: " ")
    }

    private static func dominantTopicsResponse(twin: DigitalTwinEngine, profile: UserProfile, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let graphTopics = twin.knowledgeGraph.topNodes(ofType: .topic, limit: 5)
        let profileTopics = profile.commonTopics.sorted { $0.value > $1.value }.prefix(5)

        var allTopics: [String] = []
        for node in graphTopics {
            allTopics.append(node.label)
        }
        for (topic, _) in profileTopics {
            let capitalized = topic.capitalized
            if !allTopics.contains(where: { $0.lowercased() == capitalized.lowercased() }) {
                allTopics.append(capitalized)
            }
        }

        guard !allTopics.isEmpty else {
            return "I haven't identified strong themes yet. The more you journal, the clearer your thought patterns will become."
        }

        let topList = allTopics.prefix(5).joined(separator: ", ")
        var response = "The themes that dominate your journal are: \(topList)."

        // Add concerns if available
        let concerns = twin.thoughtPatterns.topConcerns
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { $0.key.capitalized }
        if !concerns.isEmpty {
            response += " Your main concerns seem to revolve around \(concerns.joined(separator: " and "))."
        }

        return response
    }

    private static func moodOverTimeResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let sig = twin.emotionalSignature
        var parts: [String] = []

        // Trend
        if sig.sentimentTrend > 0.05 {
            parts.append("Your mood has been trending upward recently. Things are looking brighter.")
        } else if sig.sentimentTrend < -0.05 {
            parts.append("Your mood has been dipping a bit lately. That's okay - acknowledging it is the first step.")
        } else {
            parts.append("Your emotional state has been fairly stable recently.")
        }

        // Baseline
        let baselineWord: String
        if sig.baselineValence > 0.2 { baselineWord = "positive" }
        else if sig.baselineValence > -0.1 { baselineWord = "balanced" }
        else { baselineWord = "reflective" }
        parts.append("Your overall emotional baseline is \(baselineWord).")

        // Resilience
        if sig.resilienceScore > 0.6 {
            parts.append("You show good emotional resilience - you bounce back well.")
        }

        // Data points
        if sig.recentSentiments.count >= 10 {
            parts.append("This is based on your last \(sig.recentSentiments.count) journal entries.")
        }

        return parts.joined(separator: " ")
    }

    private static func communicationStyleResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData, twin.communicationStyle.analysisCount >= 3 else { return insufficientData }

        let style = twin.communicationStyle
        var parts: [String] = []

        // Formality
        if style.formalityLevel > 0.6 {
            parts.append("You write in a fairly formal, polished way.")
        } else if style.formalityLevel < 0.4 {
            parts.append("Your writing style is casual and conversational.")
        } else {
            parts.append("Your writing strikes a nice balance between casual and formal.")
        }

        // Expressiveness
        if style.expressiveness > 0.6 {
            parts.append("You're quite expressive - you use exclamations and vivid language.")
        } else if style.expressiveness < 0.3 {
            parts.append("You tend to be measured and understated in your expression.")
        }

        // Directness
        if style.directness > 0.6 {
            parts.append("You're direct and to the point.")
        } else if style.directness < 0.4 {
            parts.append("You often take a more nuanced, reflective approach.")
        }

        // Sentence length
        parts.append("Your average sentence is about \(Int(style.averageSentenceLength)) words long.")

        // Signature words
        let topWords = style.signatureWords
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        if !topWords.isEmpty {
            parts.append("Some of your signature words are: \(topWords.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }

    private static func stressTriggersResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let negativeTriggers = twin.emotionalSignature.negativeTriggersTopics
            .sorted { $0.value > $1.value }
            .prefix(5)

        guard !negativeTriggers.isEmpty else {
            // No celebratory spin on a data gap: an empty trigger map means the
            // Twin hasn't learned triggers yet — it says nothing about how the
            // person is doing. The old "actually a good sign!" copy misfired on
            // genuinely-negative baselines (engine groundedness tonal audit).
            return "I haven't identified clear stress triggers yet — I need more entries before patterns in what weighs on you become visible."
        }

        let triggerList = negativeTriggers.map { $0.key.capitalized }
        var response = "Based on your entries, these topics tend to bring your mood down: \(triggerList.joined(separator: ", "))."

        // Contrast with positive
        let positiveTriggers = twin.emotionalSignature.positiveTriggersTopics
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key.capitalized }
        if !positiveTriggers.isEmpty {
            response += " On the flip side, \(positiveTriggers.joined(separator: ", ")) tend to lift you up."
        }

        return response
    }

    private static func positiveOrNegativeResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let valence = twin.emotionalSignature.baselineValence
        var parts: [String] = []

        if valence > 0.2 {
            parts.append("Overall, your journal entries lean positive. You tend to focus on good things.")
        } else if valence > 0.05 {
            parts.append("You're slightly on the positive side - a healthy, realistic optimism.")
        } else if valence > -0.05 {
            parts.append("You're remarkably balanced. Your entries show an even mix of positive and negative.")
        } else if valence > -0.2 {
            parts.append("Your entries lean slightly toward processing challenges. That's what journaling is great for.")
        } else {
            parts.append("You've been working through some tough things. Your journal is a safe space for that.")
        }

        // Emotion frequency breakdown
        let emotions = twin.emotionalSignature.emotionFrequency
            .sorted { $0.value > $1.value }
            .prefix(3)
        if !emotions.isEmpty {
            let topEmotions = emotions.map { "\($0.key.capitalized)" }
            parts.append("Your most frequent moods are: \(topEmotions.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }

    private static func personalityResponse(twin: DigitalTwinEngine, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        let twinProfile = TwinProfileGenerator.generate()
        var parts: [String] = []

        parts.append("Here's what your journal reveals about you:")

        // Core traits from profile
        let traitDescriptions = twinProfile.traits.map { $0.displayLabel }
        if !traitDescriptions.isEmpty {
            parts.append("Your core traits are: \(traitDescriptions.joined(separator: ", ")).")
        }

        // Communication & thinking style
        parts.append("Communication style: \(twinProfile.communicationStyle). Thinking style: \(twinProfile.thinkingStyle).")

        // Dominant mood
        parts.append("Your dominant mood is \(twinProfile.dominantMood) with \(twinProfile.emotionalRange.lowercased()) emotional range.")

        // Growth indicators
        if twin.thoughtPatterns.growthMindsetScore > 0.6 {
            parts.append("You show a strong growth mindset.")
        }
        if twin.thoughtPatterns.gratitudeTendency > 0.5 {
            parts.append("Gratitude is a natural part of how you think.")
        }
        if twin.thoughtPatterns.selfAwarenessLevel > 0.6 {
            parts.append("You have a high level of self-awareness.")
        }

        return parts.joined(separator: " ")
    }

    private static func bestJournalTimeResponse(twin: DigitalTwinEngine, profile: UserProfile, hasData: Bool) -> String {
        guard hasData else { return insufficientData }

        var parts: [String] = []

        // Peak hour from behavioral patterns
        if let peakHour = twin.behavioralPatterns.peakHour {
            parts.append("Based on your habits, you journal most often around \(formatHour(peakHour)).")
        }

        // Cross-reference with mood
        let sig = twin.emotionalSignature
        if sig.morningMood > sig.eveningMood + 0.1 {
            parts.append("You tend to be in a better mood in the morning, so that might be ideal for reflection.")
        } else if sig.eveningMood > sig.morningMood + 0.1 {
            parts.append("Your evening entries tend to be more positive - evenings might be your sweet spot.")
        }

        // Peak day
        if let peakDay = twin.behavioralPatterns.peakDay {
            let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            if peakDay >= 1 && peakDay <= 7 {
                parts.append("\(days[peakDay]) is when you journal most frequently.")
            }
        }

        // Consistency note
        if twin.behavioralPatterns.consistencyScore > 0.5 {
            parts.append("You've built a solid journaling habit - keep it up!")
        } else {
            parts.append("Try picking a consistent time each day to build the habit.")
        }

        return parts.isEmpty ? insufficientData : parts.joined(separator: " ")
    }

    // MARK: - Helpers

    private static func sentimentWord(_ value: Double) -> String {
        if value > 0.3 { return "great" }
        if value > 0.1 { return "good" }
        if value > -0.1 { return "neutral" }
        if value > -0.3 { return "a bit low" }
        return "tough"
    }

    private static func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "midnight" }
        if hour < 12 { return "\(hour)am" }
        if hour == 12 { return "noon" }
        return "\(hour - 12)pm"
    }
}

// MARK: - Twin Chat View

struct TwinChatView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var messages: [TwinChatMessage] = []
    @State private var askedQuestions: Set<TwinQuestion> = []
    @Namespace private var bottomAnchor

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome message
                        if messages.isEmpty {
                            welcomeCard
                                .padding(.top, 20)
                        }

                        ForEach(messages) { message in
                            chatBubble(for: message)
                        }

                        // Invisible anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()
                .background(themeManager.secondaryTextColor.opacity(0.3))

            // Suggested questions chips
            questionChips
        }
        .navigationTitle("Ask Your Twin")
        .background(themeManager.backgroundColor.ignoresSafeArea())
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            // Small twin orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.accentColor.opacity(0.6),
                                themeManager.accentColor.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }

            Text("Ask me anything about your journal")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            Text("Tap a question below to get insights from your Digital Twin. All answers come from your on-device data.")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Chat Bubble

    private func chatBubble(for message: TwinChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // Twin orb icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.accentColor.opacity(0.7),
                                    themeManager.accentColor.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(message.isUser ? .white : themeManager.textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isUser
                                  ? themeManager.accentColor
                                  : themeManager.cardBackgroundColor)
                    )
            }

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Question Chips

    private var questionChips: some View {
        VStack(spacing: 8) {
            if availableQuestions.isEmpty {
                Text("You've asked all the questions! Tap any to ask again.")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.top, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedQuestions) { question in
                        Button {
                            askQuestion(question)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: question.icon)
                                    .font(.system(size: 11))
                                Text(question.rawValue)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(askedQuestions.contains(question)
                                             ? themeManager.secondaryTextColor
                                             : themeManager.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(askedQuestions.contains(question)
                                          ? themeManager.cardBackgroundColor.opacity(0.6)
                                          : themeManager.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        askedQuestions.contains(question)
                                        ? Color.clear
                                        : themeManager.accentColor.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
        }
        .background(themeManager.backgroundColor)
    }

    // MARK: - Logic

    private var availableQuestions: [TwinQuestion] {
        TwinQuestion.allCases.filter { !askedQuestions.contains($0) }
    }

    private var displayedQuestions: [TwinQuestion] {
        // Show unasked first, then asked ones
        let unasked = TwinQuestion.allCases.filter { !askedQuestions.contains($0) }
        let asked = TwinQuestion.allCases.filter { askedQuestions.contains($0) }
        return unasked + asked
    }

    private func askQuestion(_ question: TwinQuestion) {
        // Add user message
        let userMessage = TwinChatMessage(text: question.rawValue, isUser: true)
        messages.append(userMessage)
        askedQuestions.insert(question)

        // Generate response with a small delay for natural feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let responseText = TwinResponseGenerator.generateResponse(for: question)
            let twinMessage = TwinChatMessage(text: responseText, isUser: false)
            withAnimation(.easeIn(duration: 0.2)) {
                messages.append(twinMessage)
            }
        }
    }
}

#Preview {
    NavigationView {
        TwinChatView()
    }
}
