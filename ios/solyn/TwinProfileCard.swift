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
            label: String(localized: "Expression", comment: "Personality card (Twin tab and the shared image): trait name at the left of a bar. One word, about 12 characters."),
            value: expr,
            lowLabel: String(localized: "Reserved", comment: "Personality card (Twin tab and the shared image): the low (left) end of the 'Expression' bar. One word, about 12 characters."),
            highLabel: String(localized: "Expressive", comment: "Personality card (Twin tab and the shared image): the high (right) end of the 'Expression' bar. One word, about 12 characters."),
            displayLabel: expr > 0.6 ? String(localized: "Expressive", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Expression', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : expr < 0.4 ? String(localized: "Reserved", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Expression', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : String(localized: "Balanced", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Expression', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.")
        ))

        let direct = twin.communicationStyle.directness
        traits.append(.init(
            label: String(localized: "Directness", comment: "Personality card (Twin tab and the shared image): trait name at the left of a bar. One word, about 12 characters."),
            value: direct,
            lowLabel: String(localized: "Nuanced", comment: "Personality card (Twin tab and the shared image): the low (left) end of the 'Directness' bar. One word, about 12 characters."),
            highLabel: String(localized: "Direct", comment: "Personality card (Twin tab and the shared image): the high (right) end of the 'Directness' bar. One word, about 12 characters."),
            displayLabel: direct > 0.6 ? String(localized: "Direct", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Directness', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : direct < 0.4 ? String(localized: "Nuanced", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Directness', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : String(localized: "Measured", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Directness', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.")
        ))

        let analytical = twin.thoughtPatterns.analyticalScore
        traits.append(.init(
            label: String(localized: "Thinking", comment: "Personality card (Twin tab and the shared image): trait name at the left of a bar. One word, about 12 characters."),
            value: analytical,
            lowLabel: String(localized: "Intuitive", comment: "Personality card (Twin tab and the shared image): the low (left) end of the 'Thinking' bar. One word, about 12 characters."),
            highLabel: String(localized: "Analytical", comment: "Personality card (Twin tab and the shared image): the high (right) end of the 'Thinking' bar. One word, about 12 characters."),
            displayLabel: analytical > 0.6 ? String(localized: "Analytical", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Thinking', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : analytical < 0.4 ? String(localized: "Intuitive", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Thinking', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : String(localized: "Balanced", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Thinking', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.")
        ))

        let timeFocus = twin.thoughtPatterns.futureOriented
        traits.append(.init(
            label: String(localized: "Time Focus", comment: "Personality card (Twin tab and the shared image): trait name at the left of a bar. One word, about 12 characters."),
            value: timeFocus,
            lowLabel: String(localized: "Past", comment: "Personality card (Twin tab and the shared image): the low (left) end of the 'Time Focus' bar. One word, about 12 characters."),
            highLabel: String(localized: "Future", comment: "Personality card (Twin tab and the shared image): the high (right) end of the 'Time Focus' bar. One word, about 12 characters."),
            displayLabel: timeFocus > 0.6 ? String(localized: "Future-focused", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Time Focus', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : timeFocus < 0.4 ? String(localized: "Reflective", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Time Focus', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : String(localized: "Present", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Time Focus', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.")
        ))

        let growth = twin.thoughtPatterns.growthMindsetScore
        traits.append(.init(
            label: String(localized: "Mindset", comment: "Personality card (Twin tab and the shared image): trait name at the left of a bar. One word, about 12 characters."),
            value: growth,
            lowLabel: String(localized: "Fixed", comment: "Personality card (Twin tab and the shared image): the low (left) end of the 'Mindset' bar. One word, about 12 characters."),
            highLabel: String(localized: "Growth", comment: "Personality card (Twin tab and the shared image): the high (right) end of the 'Mindset' bar. One word, about 12 characters."),
            displayLabel: growth > 0.6 ? String(localized: "Growth", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Mindset', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : growth < 0.4 ? String(localized: "Fixed", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Mindset', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.") : String(localized: "Evolving", comment: "Personality card (Twin tab and the shared image): which way the user leans on 'Mindset', at the right of the bar. Describes the user: keep it gender-neutral. About 14 characters.")
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
            dominantMood = Mood(rawValue: topMood.lowercased())?.displayName ?? topMood.capitalized
        } else {
            dominantMood = String(localized: "Neutral", comment: "Personality card (Twin tab and the shared image): the dominant mood when no mood has been recorded. One word, about 10 characters.")
        }

        // Emotional range
        let range = twin.emotionalSignature.emotionalRange
        let emotionalRange = range > 0.6
            ? String(localized: "Wide", comment: "Personality card (Twin tab and the shared image): how much the user's moods vary, the value above 'Emotional Range'. One word, about 10 characters.")
            : range < 0.3
                ? String(localized: "Steady", comment: "Personality card (Twin tab and the shared image): how much the user's moods vary, the value above 'Emotional Range'. One word, about 10 characters.")
                : String(localized: "Moderate", comment: "Personality card (Twin tab and the shared image): how much the user's moods vary, the value above 'Emotional Range'. One word, about 10 characters.")

        // Communication style summary
        let formality = twin.communicationStyle.formalityLevel
        let communicationStyle: String
        if formality > 0.6 && direct > 0.6 {
            communicationStyle = String(localized: "Clear & Professional", comment: "Personality card (Twin tab and the shared image): the communication-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if formality < 0.4 && expr > 0.6 {
            communicationStyle = String(localized: "Casual & Expressive", comment: "Personality card (Twin tab and the shared image): the communication-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if direct > 0.6 && expr < 0.4 {
            communicationStyle = String(localized: "Blunt & Reserved", comment: "Personality card (Twin tab and the shared image): the communication-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if formality < 0.4 && direct < 0.4 {
            communicationStyle = String(localized: "Soft & Indirect", comment: "Personality card (Twin tab and the shared image): the communication-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else {
            communicationStyle = String(localized: "Adaptive", comment: "Personality card (Twin tab and the shared image): the communication-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        }

        // Thinking style summary
        let abstract = twin.thoughtPatterns.abstractScore
        let thinkingStyle: String
        if analytical > 0.6 && abstract > 0.6 {
            thinkingStyle = String(localized: "Conceptual Thinker", comment: "Personality card (Twin tab and the shared image): the thinking-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if analytical > 0.6 && abstract < 0.4 {
            thinkingStyle = String(localized: "Practical Analyst", comment: "Personality card (Twin tab and the shared image): the thinking-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if analytical < 0.4 && abstract > 0.6 {
            thinkingStyle = String(localized: "Creative Dreamer", comment: "Personality card (Twin tab and the shared image): the thinking-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else if analytical < 0.4 && abstract < 0.4 {
            thinkingStyle = String(localized: "Grounded Feeler", comment: "Personality card (Twin tab and the shared image): the thinking-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
        } else {
            thinkingStyle = String(localized: "Flexible Thinker", comment: "Personality card (Twin tab and the shared image): the thinking-style badge. Describes the user: keep it gender-neutral. About 22 characters.")
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
            maturityLevel: twin.summary.maturityLevel.displayName
        )
    }

    private static func formatHour(_ hour: Int) -> String {
        if hour == 0 { return String(localized: "midnight", comment: "Personality card (Twin tab and the shared image): peak writing time at hour 0, the value above 'Peak Time'. About 8 characters.") }
        if hour == 12 { return String(localized: "noon", comment: "Personality card (Twin tab and the shared image): peak writing time at hour 12, the value above 'Peak Time'. About 8 characters.") }
        return hour < 12
            ? String(localized: "\(hour)am", comment: "Twin tab > When You Write: a morning hour, inside 'Peak writing time: 9am'. The placeholder is the hour 1-11. A 24-hour language writes it as is (9 Uhr). About 6 characters.")
            : String(localized: "\(hour - 12)pm", comment: "Twin tab > When You Write: an afternoon or evening hour, inside 'Peak writing time: 9pm'. The placeholder is the hour on a 12-hour clock, 1-11. About 6 characters.")
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
                            .font(.dv(.headline))
                        Spacer()
                        Button {
                            shareProfile(profile, format: .story)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.dv(.caption, weight: .semibold))
                            .foregroundColor(DS.Palette.gold)
                        }
                    }

                    TwinProfileCardContent(profile: profile)
                }
                .sheet(isPresented: $showShareSheet, onDismiss: { ReviewManager.shared.recordPositiveMoment() }) {
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
                        .font(.dv(.caption2, design: .rounded, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(profile.signatureWords, id: \.self) { word in
                            Text(word)
                                .font(.dv(.caption, design: .monospaced, weight: .medium))
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
                miniStat(value: profile.peakTime, label: String(localized: "Peak Time", comment: "Personality card (Twin tab and the shared image): label under the hour the user most often writes. About 12 characters."))
                miniStat(value: profile.dominantMood, label: String(localized: "Dominant Mood", comment: "Personality card (Twin tab and the shared image), in-app: label under the most frequent mood. About 14 characters."))
                miniStat(value: profile.emotionalRange, label: String(localized: "Emotional Range", comment: "Personality card (Twin tab and the shared image), in-app: label under Wide / Moderate / Steady. About 14 characters."))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Palette.navy,
                            DS.Palette.navy
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
            .font(.dv(.caption2, design: .rounded, weight: .semibold))
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
                    .font(.dv(.caption2, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(trait.displayLabel)
                    .font(.dv(.caption2, weight: .semibold))
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
                    .font(.dv(.caption2))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
                Text(trait.highLabel)
                    .font(.dv(.caption2))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.dv(.footnote, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.dv(.caption2))
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
                    .font(.dv(.caption, weight: .semibold))
                Text("My Personality Profile")
                    .font(.dv(.caption, design: .rounded, weight: .semibold))
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
                        .font(.dv(.caption2, design: .rounded, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.4))

                    HStack(spacing: 8) {
                        ForEach(profile.signatureWords, id: \.self) { word in
                            Text(word)
                                .font(.dv(.caption, design: .monospaced, weight: .medium))
                                .foregroundColor(DS.Palette.gold.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 0) {
                exportStat(value: profile.peakTime, label: String(localized: "Peak Time", comment: "Personality card (Twin tab and the shared image): label under the hour the user most often writes. About 12 characters."))
                exportStat(value: profile.dominantMood, label: String(localized: "Top Mood", comment: "Personality card (Twin tab and the shared image), shared image: label under the most frequent mood. Four columns share the row; about 10 characters."))
                exportStat(value: profile.emotionalRange, label: String(localized: "Range", comment: "Personality card (Twin tab and the shared image), shared image: label under Wide / Moderate / Steady. Four columns share the row; about 10 characters."))
                exportStat(value: "\(profile.totalEntries)", label: String(localized: "Entries", comment: "Personality card (Twin tab and the shared image), shared image: label under the number of entries. Four columns share the row; about 10 characters."))
            }

            // Branding
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DailyVox")
                        .font(.dv(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    Text("AI Voice Diary")
                        .font(.dv(.caption2, weight: .regular))
                        .foregroundColor(.white.opacity(0.2))
                }
                Spacer()
                Text("getdailyvox.com")
                    .font(.dv(.caption2, design: .monospaced, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Palette.navy,
                            DS.Palette.navy
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
            .font(.dv(.caption, design: .rounded, weight: .semibold))
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
                    .font(.dv(.caption2, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(trait.displayLabel)
                    .font(.dv(.caption2, weight: .bold))
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
                .font(.dv(.subheadline, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text(label)
                .font(.dv(.caption2))
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
