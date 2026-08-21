//
//  ShareableInsightCardView.swift
//  solyn
//
//  Renders a clean, shareable insight card designed for social media.
//  Dark background, bold typography, subtle branding.
//  Optimized for Instagram Stories, TikTok, and Twitter.
//

import SwiftUI

// MARK: - Shareable Card View

struct ShareableInsightCardView: View {
    let insight: ShareableInsight
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            cardContent
                .padding(.bottom, 12)

            // Share button
            Button(action: onShare) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.dv(size: 14, weight: .semibold))
                    Text("Share")
                        .font(.dv(size: 14, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.15)))
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Category badge
            HStack(spacing: 6) {
                Image(systemName: insight.category.icon)
                    .font(.dv(size: 11, weight: .semibold))
                Text("Weekly Insight")
                    .font(.dv(size: 11, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            .foregroundColor(categoryColor.opacity(0.9))

            // Headline
            Text(insight.headline)
                .font(.dv(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Subtext
            Text(insight.subtext)
                .font(.dv(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)

            // Data point badge (if available)
            if let dataPoint = insight.dataPoint {
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 6, height: 6)
                    Text(dataPoint)
                        .font(.dv(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer().frame(height: 4)

            // Branding
            HStack {
                Spacer()
                Text("DailyVox")
                    .font(.dv(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ShareCardTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(categoryColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var categoryColor: Color {
        switch insight.category {
        case .emotion: return ShareCardTheme.coral
        case .pattern: return ShareCardTheme.terracotta
        case .people: return ShareCardTheme.gold
        case .language: return ShareCardTheme.sage
        case .growth: return ShareCardTheme.forest
        case .time: return ShareCardTheme.amber
        }
    }
}

// MARK: - Card Renderer (for sharing as image)

struct InsightCardRenderer {
    /// Renders the insight card as a UIImage for sharing
    @MainActor
    static func renderCard(insight: ShareableInsight) -> UIImage? {
        let cardView = ShareableCardForExport(insight: insight)
            .frame(width: 380, height: 420)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // High resolution
        return renderer.uiImage
    }
}

/// Standalone card view for image export (no share button, includes extra branding)
private struct ShareableCardForExport: View {
    let insight: ShareableInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Category badge
            HStack(spacing: 6) {
                Image(systemName: insight.category.icon)
                    .font(.dv(size: 12, weight: .semibold))
                Text("Weekly Insight")
                    .font(.dv(size: 12, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            .foregroundColor(categoryColor.opacity(0.9))

            Spacer()

            // Headline
            Text(insight.headline)
                .font(.dv(size: 26, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(6)

            // Subtext
            Text(insight.subtext)
                .font(.dv(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(3)

            // Data point
            if let dataPoint = insight.dataPoint {
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 6, height: 6)
                    Text(dataPoint)
                        .font(.dv(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Branding footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DailyVox")
                        .font(.dv(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("AI Voice Diary")
                        .font(.dv(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.2))
                }
                Spacer()
                Text("getdailyvox.com")
                    .font(.dv(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ShareCardTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var categoryColor: Color {
        switch insight.category {
        case .emotion: return ShareCardTheme.coral
        case .pattern: return ShareCardTheme.terracotta
        case .people: return ShareCardTheme.gold
        case .language: return ShareCardTheme.sage
        case .growth: return ShareCardTheme.forest
        case .time: return ShareCardTheme.amber
        }
    }
}

// MARK: - Insights Section (for StatsView integration)

struct WeeklyInsightsSection: View {
    let entries: [DiaryEntry]
    @State private var insights: [ShareableInsight] = []
    @State private var currentIndex = 0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        Group {
            if !insights.isEmpty {
                insightsContent
            }
        }
        .onAppear { generateInsights() }
    }

    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(ShareCardTheme.gold)
                Text("Your Week, Decoded")
                    .font(.dv(.headline))
                Spacer()
                if insights.count > 1 {
                    Text("\(currentIndex + 1)/\(insights.count)")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                }
            }

            // Card carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    ShareableInsightCardView(insight: insight) {
                        shareInsight(insight)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showShareSheet, onDismiss: { ReviewManager.shared.recordPositiveMoment() }) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }

    private func generateInsights() {
        insights = ShareableInsightGenerator.generateWeeklyInsights(from: entries)
    }

    private func shareInsight(_ insight: ShareableInsight) {
        Task { @MainActor in
            if let image = InsightCardRenderer.renderCard(insight: insight) {
                shareImage = image
                showShareSheet = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ShareableInsightCardView(
                insight: ShareableInsight(
                    headline: "You said \"should\" 14 times this week.\n\"Want\"? Only 2.",
                    subtext: "You're living by obligation, not desire.",
                    category: .language,
                    dataPoint: "should: 14 vs want: 2",
                    generatedAt: Date()
                )
            ) {}

            ShareableInsightCardView(
                insight: ShareableInsight(
                    headline: "You mentioned Sarah 8 times this week.",
                    subtext: "Your mood drops when you do.",
                    category: .people,
                    dataPoint: "8x",
                    generatedAt: Date()
                )
            ) {}

            ShareableInsightCardView(
                insight: ShareableInsight(
                    headline: "Most anxious on Sundays.\nMost calm on Wednesdays.",
                    subtext: "Your week has a pattern. Do you see it?",
                    category: .time,
                    dataPoint: nil,
                    generatedAt: Date()
                )
            ) {}
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
