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
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
                Text("Welcome to Your Private Diary")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Speak your thoughts freely. All AI runs on your device — private by design, with optional iCloud sync.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "mic.fill", color: .blue, text: "Tap to record your voice")
                FeatureRow(icon: "text.quote", color: .purple, text: "Automatically transcribed to text")
                FeatureRow(icon: "lock.fill", color: .green, text: "100% private, stored locally")
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
