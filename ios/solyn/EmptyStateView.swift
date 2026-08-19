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
                    .font(.system(size: 48))
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
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 40)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
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
            title: "Start Your Journey",
            subtitle: "Tap the microphone below to record your first voice diary entry"
        )
    }

    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            subtitle: "Try a different search term"
        )
    }

    static var noStarredEntries: EmptyStateView {
        EmptyStateView(
            icon: "star",
            title: "No Starred Entries",
            subtitle: "Star your favorite entries to find them quickly"
        )
    }

    static var noInsights: EmptyStateView {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: "Insights Coming Soon",
            subtitle: "Keep journaling to unlock personalized insights about your writing patterns"
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Speak your thoughts. Every word becomes a star in your inner sky. All AI runs on your device — private by design.")
                    .font(.system(.subheadline, design: .rounded).weight(.regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "mic.fill", color: DS.Palette.gold, text: "Just 42 seconds — that's all it takes")
                FeatureRow(icon: "text.quote", color: DS.Palette.sage, text: "Transcribed and understood on-device")
                FeatureRow(icon: "lock.fill", color: DS.Palette.forest, text: "100% private, stored locally")
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
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
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
