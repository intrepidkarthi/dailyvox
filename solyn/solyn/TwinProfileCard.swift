//
//  TwinProfileCard.swift
//  solyn
//
//  Shareable personality profile card — "Spotify Wrapped for your personality."
//  Pulls data from DigitalTwinEngine to create a visually striking,
//  share-worthy summary of who you are based on your journal entries.
//

import SwiftUI
import DailyVoxTwinEngine

// MARK: - Twin Profile Data

struct TwinProfile {
    let traits: [Trait]
    let signatureWords: [String]
    let peakTime: String
    let totalEntries: Int
    let totalWords: Int
    let dominantMood: String
    let emotionalRange: String
    let communicationStyle: String
    let thinkingStyle: String
    let topPerson: String?
    let topTopic: String?
    let maturityLevel: String

    struct Trait {
        let label: String
        let value: Double       // 0-1
        let lowLabel: String
        let highLabel: String
        let displayLabel: String // which end the user leans toward
    }
}

// MARK: - Profile Generator

struct TwinProfileGenerator {

    static func generate() -> TwinProfile {
        let twin = DigitalTwinEngine.shared
        let profile = LocalAIEngine.shared.userProfile

        // Traits
        var traits: [TwinProfile.Trait] = []

        let expr = twin.communicationStyle.expressiveness
        traits.append(.init(
            label: "Expression",
            value: expr,
            lowLabel: "Reserved",
            highLabel: "Expressive",
            displayLabel: expr > 0.6 ? "Expressive" : expr < 0.4 ? "Reserved" : "Balanced"
        ))

        let direct = twin.communicationStyle.directness
        traits.append(.init(
            label: "Directness",
            value: direct,
            lowLabel: "Nuanced",
            highLabel: "Direct",
            displayLabel: direct > 0.6 ? "Direct" : direct < 0.4 ? "Nuanced" : "Measured"
        ))

        let analytical = twin.thoughtPatterns.analyticalScore
        traits.append(.init(
            label: "Thinking",
            value: analytical,
            lowLabel: "Intuitive",
            highLabel: "Analytical",
            displayLabel: analytical > 0.6 ? "Analytical" : analytical < 0.4 ? "Intuitive" : "Balanced"
        ))

        let timeFocus = twin.thoughtPatterns.futureOriented
        traits.append(.init(
            label: "Time Focus",
            value: timeFocus,
            lowLabel: "Past",
            highLabel: "Future",
            displayLabel: timeFocus > 0.6 ? "Future-focused" : timeFocus < 0.4 ? "Reflective" : "Present"
        ))

        let growth = twin.thoughtPatterns.growthMindsetScore
        traits.append(.init(
            label: "Mindset",
            value: growth,
            lowLabel: "Fixed",
            highLabel: "Growth",
            displayLabel: growth > 0.6 ? "Growth" : growth < 0.4 ? "Fixed" : "Evolving"
        ))

        // Signature words
        let topWords = twin.communicationStyle.signatureWords
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        // Peak time
        let peakHour = twin.behavioralPatterns.peakHour ?? 21
        let peakTime = formatHour(peakHour)

        // Dominant mood
        let dominantMood: String
        if let topMood = twin.emotionalSignature.emotionFrequency
            .max(by: { $0.value < $1.value })?.key {
            dominantMood = topMood.capitalized
        } else {
            dominantMood = "Neutral"
        }

        // Emotional range
        let range = twin.emotionalSignature.emotionalRange
        let emotionalRange = range > 0.6 ? "Wide" : range < 0.3 ? "Steady" : "Moderate"

        // Communication style summary
        let formality = twin.communicationStyle.formalityLevel
        let communicationStyle: String
        if formality > 0.6 && direct > 0.6 {
            communicationStyle = "Clear & Professional"
        } else if formality < 0.4 && expr > 0.6 {
            communicationStyle = "Casual & Expressive"
        } else if direct > 0.6 && expr < 0.4 {
            communicationStyle = "Blunt & Reserved"
        } else if formality < 0.4 && direct < 0.4 {
            communicationStyle = "Soft & Indirect"
        } else {
            communicationStyle = "Adaptive"
        }

        // Thinking style summary
        let abstract = twin.thoughtPatterns.abstractScore
        let thinkingStyle: String
        if analytical > 0.6 && abstract > 0.6 {
            thinkingStyle = "Conceptual Thinker"
        } else if analytical > 0.6 && abstract < 0.4 {
            thinkingStyle = "Practical Analyst"
        } else if analytical < 0.4 && abstract > 0.6 {
            thinkingStyle = "Creative Dreamer"
        } else if analytical < 0.4 && abstract < 0.4 {
            thinkingStyle = "Grounded Feeler"
        } else {
            thinkingStyle = "Flexible Thinker"
        }

        // Top person & topic from knowledge graph
        let topPerson = twin.knowledgeGraph.topNodes(ofType: .person, limit: 1).first?.label
        let topTopic = twin.knowledgeGraph.topNodes(ofType: .topic, limit: 1).first?.label

        return TwinProfile(
            traits: traits,
            signatureWords: topWords,
            peakTime: peakTime,
            totalEntries: twin.behavioralPatterns.totalEntries,
            totalWords: twin.behavioralPatterns.totalWords,
            dominantMood: dominantMood,
            emotionalRange: emotionalRange,
            communicationStyle: communicationStyle,
            thinkingStyle: thinkingStyle,
            topPerson: topPerson,
            topTopic: topTopic,
            maturityLevel: twin.summary.maturityLevel.rawValue.capitalized
        )
    }

    private static func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "midnight" }
        if hour == 12 { return "noon" }
        return hour < 12 ? "\(hour)am" : "\(hour - 12)pm"
    }
}

// MARK: - Profile Card View (in-app)

struct TwinProfileCardSection: View {
    @State private var profile: TwinProfile?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showFormatPicker = false

    var body: some View {
        Group {
            if let profile = profile, profile.totalEntries >= 3 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(DS.Palette.gold)
                        Text("Your Personality Card")
                            .font(.headline)
                        Spacer()
                        Button {
                            shareProfile(profile, format: .story)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(DS.Palette.gold)
                        }
                    }

                    TwinProfileCardContent(profile: profile)
                }
                .sheet(isPresented: $showShareSheet) {
                    if let image = shareImage {
                        ShareSheet(activityItems: [
                            image,
                            PersonalityCardRenderer.shareText
                        ])
                    }
                }
            }
        }
        .onAppear { profile = TwinProfileGenerator.generate() }
    }

    private func shareProfile(_ profile: TwinProfile, format: PersonalityCardFormat) {
        Task { @MainActor in
            if let image = PersonalityCardRenderer.renderCard(profile: profile, format: format) {
                shareImage = image
                showShareSheet = true
            }
        }
    }
}

// MARK: - Card Content (shown in-app)

struct TwinProfileCardContent: View {
    let profile: TwinProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Style labels
            HStack(spacing: 12) {
                styleBadge(profile.communicationStyle, color: DS.Palette.gold)
                styleBadge(profile.thinkingStyle, color: DS.Palette.terracotta)
            }

            // Trait bars
            ForEach(Array(profile.traits.enumerated()), id: \.offset) { _, trait in
                traitRow(trait)
            }

            // Signature words
            if !profile.signatureWords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR WORDS")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(profile.signatureWords, id: \.self) { word in
                            Text(word)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DS.Palette.gold.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: 0) {
                miniStat(value: profile.peakTime, label: "Peak Time")
                miniStat(value: profile.dominantMood, label: "Dominant Mood")
                miniStat(value: profile.emotionalRange, label: "Emotional Range")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.12),
                            Color(red: 0.10, green: 0.10, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DS.Palette.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func styleBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }

    private func traitRow(_ trait: TwinProfile.Trait) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(trait.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(trait.displayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [DS.Palette.gold, DS.Palette.terracotta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0.05, min(1, trait.value)))
                }
            }
            .frame(height: 6)
            HStack {
                Text(trait.lowLabel)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
                Text(trait.highLabel)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Export Card (for sharing as image)

private struct TwinProfileCardExport: View {
    let profile: TwinProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 12, weight: .semibold))
                Text("My Personality Profile")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.0)
            }
            .foregroundColor(DS.Palette.gold.opacity(0.9))

            // Style labels
            HStack(spacing: 10) {
                exportBadge(profile.communicationStyle, color: DS.Palette.gold)
                exportBadge(profile.thinkingStyle, color: DS.Palette.terracotta)
            }

            // Traits
            ForEach(Array(profile.traits.enumerated()), id: \.offset) { _, trait in
                exportTraitRow(trait)
            }

            // Signature words
            if !profile.signatureWords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MY WORDS")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.4))

                    HStack(spacing: 8) {
                        ForEach(profile.signatureWords, id: \.self) { word in
                            Text(word)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DS.Palette.gold.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 0) {
                exportStat(value: profile.peakTime, label: "Peak Time")
                exportStat(value: profile.dominantMood, label: "Top Mood")
                exportStat(value: profile.emotionalRange, label: "Range")
                exportStat(value: "\(profile.totalEntries)", label: "Entries")
            }

            // Branding
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DailyVox")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("AI Voice Diary")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.2))
                }
                Spacer()
                Text("getdailyvox.com")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.06, blue: 0.10),
                            Color(red: 0.10, green: 0.08, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DS.Palette.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func exportBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(10)
    }

    private func exportTraitRow(_ trait: TwinProfile.Trait) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(trait.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(trait.displayLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [DS.Palette.gold, DS.Palette.terracotta], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * max(0.05, min(1, trait.value)))
                }
            }
            .frame(height: 6)
        }
    }

    private func exportStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        TwinProfileCardContent(profile: TwinProfile(
            traits: [
                .init(label: "Expression", value: 0.7, lowLabel: "Reserved", highLabel: "Expressive", displayLabel: "Expressive"),
                .init(label: "Directness", value: 0.8, lowLabel: "Nuanced", highLabel: "Direct", displayLabel: "Direct"),
                .init(label: "Thinking", value: 0.3, lowLabel: "Intuitive", highLabel: "Analytical", displayLabel: "Intuitive"),
                .init(label: "Time Focus", value: 0.6, lowLabel: "Past", highLabel: "Future", displayLabel: "Future-focused"),
                .init(label: "Mindset", value: 0.75, lowLabel: "Fixed", highLabel: "Growth", displayLabel: "Growth"),
            ],
            signatureWords: ["maybe", "honestly", "actually", "weird", "literally"],
            peakTime: "11pm",
            totalEntries: 47,
            totalWords: 12840,
            dominantMood: "Anxious",
            emotionalRange: "Wide",
            communicationStyle: "Casual & Expressive",
            thinkingStyle: "Creative Dreamer",
            topPerson: "Sarah",
            topTopic: "Work",
            maturityLevel: "Developing"
        ))
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
