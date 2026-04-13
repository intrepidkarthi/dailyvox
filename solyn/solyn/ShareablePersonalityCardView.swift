//
//  ShareablePersonalityCardView.swift
//  solyn
//
//  Social-media-optimized personality card for sharing your Digital Twin.
//  Supports Instagram Stories (1080x1920) and Twitter/X (1200x675) formats.
//  Follows the same pattern as ShareableInsightCardView + InsightCardRenderer.
//

import SwiftUI

// MARK: - Card Format

enum PersonalityCardFormat {
    case story      // Instagram Stories / TikTok — 1080x1920
    case landscape  // Twitter/X — 1200x675

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .landscape: return CGSize(width: 1200, height: 675)
        }
    }

    /// Logical size for SwiftUI layout (rendered at 3x scale)
    var layoutSize: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)
        case .landscape: return CGSize(width: 400, height: 225)
        }
    }
}

// MARK: - Card Renderer

struct PersonalityCardRenderer {

    /// Renders the personality card as a UIImage for sharing
    @MainActor
    static func renderCard(profile: TwinProfile, format: PersonalityCardFormat = .story) -> UIImage? {
        let cardView = ShareablePersonalityCardExport(profile: profile, format: format)
            .frame(width: format.layoutSize.width, height: format.layoutSize.height)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Share text to include alongside the image
    static let shareText = "My Digital Twin personality from DailyVox \u{2014} free AI voice journal. getdailyvox.com"
}

// MARK: - Story Format Export (1080x1920 at 3x)

private struct ShareablePersonalityCardExport: View {
    let profile: TwinProfile
    let format: PersonalityCardFormat

    var body: some View {
        switch format {
        case .story:
            storyLayout
        case .landscape:
            landscapeLayout
        }
    }

    // MARK: - Story Layout (vertical, full detail)

    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top branding
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.teal)
                Text("DailyVox")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 20)

            // Header
            Text("MY DIGITAL TWIN")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundColor(.teal.opacity(0.9))
                .padding(.bottom, 6)

            Text(profile.maturityLevel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 20)

            // Style badges
            HStack(spacing: 10) {
                exportBadge(profile.communicationStyle, color: .teal)
                exportBadge(profile.thinkingStyle, color: .purple)
            }
            .padding(.bottom, 20)

            // Trait bars (top 5)
            VStack(spacing: 10) {
                ForEach(Array(profile.traits.prefix(5).enumerated()), id: \.offset) { _, trait in
                    storyTraitRow(trait)
                }
            }
            .padding(.bottom, 20)

            // Dominant mood
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.teal)
                    .frame(width: 8, height: 8)
                Text("Dominant Mood")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                Text(profile.dominantMood)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 14)

            // Communication style
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                Text("Communication")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                Text(profile.communicationStyle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 20)

            // Signature words
            if !profile.signatureWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SIGNATURE WORDS")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.35))

                    HStack(spacing: 8) {
                        ForEach(Array(profile.signatureWords.prefix(3)), id: \.self) { word in
                            Text(word)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.teal.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.teal.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 16)
            }

            Spacer()

            // Entry count
            Text("Built from \(profile.totalEntries) journal entries")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
                .padding(.bottom, 8)

            // Bottom branding
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DailyVox")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    Text("AI Voice Journal")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.18))
                }
                Spacer()
                Text("getdailyvox.com")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.18))
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.09),
                            Color(red: 0.08, green: 0.06, blue: 0.13),
                            Color(red: 0.06, green: 0.06, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.teal.opacity(0.25), .purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Landscape Layout (Twitter/X, compact)

    private var landscapeLayout: some View {
        HStack(spacing: 20) {
            // Left column: identity
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.teal)
                    Text("DailyVox")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }

                Text("MY DIGITAL TWIN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2.0)
                    .foregroundColor(.teal.opacity(0.9))

                HStack(spacing: 6) {
                    exportBadge(profile.communicationStyle, color: .teal, compact: true)
                    exportBadge(profile.thinkingStyle, color: .purple, compact: true)
                }

                Spacer()

                if !profile.signatureWords.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(profile.signatureWords.prefix(3)), id: \.self) { word in
                            Text(word)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.teal.opacity(0.8))
                        }
                    }
                }

                Text("Built from \(profile.totalEntries) entries")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column: trait bars
            VStack(spacing: 6) {
                ForEach(Array(profile.traits.prefix(4).enumerated()), id: \.offset) { _, trait in
                    landscapeTraitRow(trait)
                }

                Spacer()

                HStack {
                    Text(profile.dominantMood)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("getdailyvox.com")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.18))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.09),
                            Color(red: 0.08, green: 0.06, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.teal.opacity(0.2), .purple.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Components

    private func exportBadge(_ text: String, color: Color, compact: Bool = false) -> some View {
        Text(text)
            .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 4 : 6)
            .background(color.opacity(0.15))
            .cornerRadius(compact ? 6 : 10)
    }

    private func storyTraitRow(_ trait: TwinProfile.Trait) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(trait.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                Text(trait.displayLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.teal, .purple],
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
                    .foregroundColor(.white.opacity(0.2))
                Spacer()
                Text(trait.highLabel)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
    }

    private func landscapeTraitRow(_ trait: TwinProfile.Trait) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(trait.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(trait.displayLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.teal, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0.05, min(1, trait.value)))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Preview

#Preview("Story Format") {
    ShareablePersonalityCardExport(
        profile: TwinProfile(
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
        ),
        format: .story
    )
    .frame(width: 360, height: 640)
    .padding()
    .background(Color.black)
}

#Preview("Landscape Format") {
    ShareablePersonalityCardExport(
        profile: TwinProfile(
            traits: [
                .init(label: "Expression", value: 0.7, lowLabel: "Reserved", highLabel: "Expressive", displayLabel: "Expressive"),
                .init(label: "Directness", value: 0.8, lowLabel: "Nuanced", highLabel: "Direct", displayLabel: "Direct"),
                .init(label: "Thinking", value: 0.3, lowLabel: "Intuitive", highLabel: "Analytical", displayLabel: "Intuitive"),
                .init(label: "Time Focus", value: 0.6, lowLabel: "Past", highLabel: "Future", displayLabel: "Future-focused"),
                .init(label: "Mindset", value: 0.75, lowLabel: "Fixed", highLabel: "Growth", displayLabel: "Growth"),
            ],
            signatureWords: ["maybe", "honestly", "actually"],
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
        ),
        format: .landscape
    )
    .frame(width: 400, height: 225)
    .padding()
    .background(Color.black)
}
