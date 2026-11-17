//
//  EmptyStateView.swift
//  solyn
//
//  Beautiful empty states for the app
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: 160, height: 160)

                Image(systemName: icon)
                    .font(.dv(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.dv(.title2, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.dv(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 40)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.dv(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {
    static var noEntries: EmptyStateView {
        EmptyStateView(
            icon: "mic.circle",
            title: String(localized: "Start Your Journey", comment: "Empty state title, centred above a short line. About 25 characters. Shown when there are no entries yet."),
            subtitle: String(localized: "Tap the microphone below to record your first voice diary entry", comment: "Empty state line under the title, centred. About 70 characters. Under 'Start Your Journey'.")
        )
    }

    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: String(localized: "No Results", comment: "Empty state title, centred above a short line. About 25 characters. Shown when a search finds no entries."),
            subtitle: String(localized: "Try a different search term", comment: "Empty state line under the title, centred. About 70 characters. Under 'No Results'.")
        )
    }

    static var noStarredEntries: EmptyStateView {
        EmptyStateView(
            icon: "star",
            title: String(localized: "No Starred Entries", comment: "Empty state title, centred above a short line. About 25 characters. Shown when the Starred filter has nothing."),
            subtitle: String(localized: "Star your favorite entries to find them quickly", comment: "Empty state line under the title, centred. About 70 characters. Under 'No Starred Entries'.")
        )
    }

    static var noInsights: EmptyStateView {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: String(localized: "Insights Coming Soon", comment: "Empty state title, centred above a short line. About 25 characters. Shown when there is not enough writing for insights yet."),
            subtitle: String(localized: "Keep journaling to unlock personalized insights about your writing patterns", comment: "Empty state line under the title, centred. About 70 characters. Under 'Insights Coming Soon'.")
        )
    }
}

// MARK: - Welcome Card (for Today view)

struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 20) {
            // Privacy badge
            PrivacyBadge()

            VStack(spacing: 12) {
                Text("Your constellation begins here")
                    .font(.dv(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Speak your thoughts. Every word becomes a star in your inner sky. All AI runs on your device — private by design.")
                    .font(.dv(.subheadline, design: .rounded, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "mic.fill", color: DS.Palette.gold, text: String(localized: "Just 42 seconds — that's all it takes", comment: "Today tab, first-run welcome card: feature row next to a microphone icon. Keep the number 42 as it is: it is the app's ritual length and a soft target, not a cutoff or a minimum. Use the local word for seconds. About 40 characters."))
                FeatureRow(icon: "text.quote", color: DS.Palette.sage, text: String(localized: "Transcribed and understood on-device", comment: "Today tab, first-run welcome card: feature row next to a quote icon. The privacy claim must stay exact: speech is processed on the iPhone itself. About 40 characters."))
                FeatureRow(icon: "lock.fill", color: DS.Palette.forest, text: String(localized: "100% private, stored locally", comment: "Today tab, first-run welcome card: feature row next to a lock icon. The privacy claim must stay exact. About 40 characters."))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .dsShadowSoft()
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.dv(.subheadline))
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.dv(.subheadline))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        EmptyStateView.noEntries
        WelcomeCard()
            .padding()
    }
}
