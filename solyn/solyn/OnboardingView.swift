//
//  OnboardingView.swift
//  solyn
//
//  Privacy-focused onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var currentPage = 0
    @State private var selectedIntentions: Set<String> = []

    private var isIPad: Bool { horizontalSizeClass == .regular }
    private var totalPageCount: Int { pages.count + 1 }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            iconColor: .teal,
            title: "Meet DailyVox Diary",
            subtitle: "The only AI that truly knows you",
            description: "Not just another diary. DailyVox Diary remembers your life — your dreams, struggles, the people you love, and what makes you, you.",
            gradient: [
                Color(red: 5/255, green: 8/255, blue: 22/255),
                Color(red: 34/255, green: 27/255, blue: 72/255)
            ]
        ),
        OnboardingPage(
            icon: "person.crop.circle.fill",
            iconColor: .pink,
            title: "Meet Your Digital Twin",
            subtitle: "A mirror of your inner world",
            description: "Your Digital Twin learns your personality, emotional patterns, and the people and topics in your life. Watch it grow as you journal.",
            gradient: [
                Color(red: 20/255, green: 12/255, blue: 48/255),
                Color(red: 76/255, green: 36/255, blue: 90/255)
            ]
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: .orange,
            title: "Insights That Matter",
            subtitle: "Understand yourself better",
            description: "Track mood trends, writing streaks, and emotional patterns. See your personal knowledge graph grow with the people, places, and topics in your life.",
            gradient: [
                Color(red: 43/255, green: 25/255, blue: 33/255),
                Color(red: 92/255, green: 51/255, blue: 63/255)
            ]
        ),
        OnboardingPage(
            icon: "lock.shield",
            iconColor: .mint,
            title: "100% Private. Always.",
            subtitle: "Your innermost thoughts stay yours",
            description: "All AI runs on YOUR device. No third-party servers. No accounts. Optionally sync via your personal iCloud. Your mind belongs only to you.",
            gradient: [
                Color(red: 8/255, green: 10/255, blue: 24/255),
                Color(red: 20/255, green: 40/255, blue: 60/255)
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: currentPage < pages.count ? pages[currentPage].gradient : [
                    Color(red: 15/255, green: 10/255, blue: 35/255),
                    Color(red: 50/255, green: 30/255, blue: 80/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < totalPageCount - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = totalPageCount - 1
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }

                    IntentionCheckInView(selectedIntentions: $selectedIntentions, isIPad: isIPad)
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPageCount, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 30)

                // Action button
                Button(action: {
                    if currentPage < totalPageCount - 1 {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    HStack {
                        Text(currentPage == totalPageCount - 1 ? "Get Started" : "Continue")
                            .font(.headline)
                        if currentPage == totalPageCount - 1 {
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: currentPage < pages.count
                                ? [pages[currentPage].iconColor, pages[currentPage].iconColor.opacity(0.8)]
                                : [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: (currentPage < pages.count ? pages[currentPage].iconColor : Color.purple).opacity(0.3), radius: 10, y: 5)
                }
                .frame(maxWidth: isIPad ? 500 : .infinity)
                .padding(.horizontal, isIPad ? 60 : 30)
                .padding(.bottom, 50)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(Array(selectedIntentions), forKey: "onboardingIntentions")
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    let gradient: [Color]
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: isIPad ? 40 : 30) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: isIPad ? 180 : 140, height: isIPad ? 180 : 140)

                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: isIPad ? 220 : 180, height: isIPad ? 220 : 180)

                Image(systemName: page.icon)
                    .font(.system(size: isIPad ? 80 : 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.iconColor, page.iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 20)

            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: isIPad ? 40 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(isIPad ? .title2.weight(.medium) : .title3.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, isIPad ? 80 : 30)
            .frame(maxWidth: isIPad ? 600 : .infinity)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Intention Check-In Page

struct IntentionCheckInView: View {
    @Binding var selectedIntentions: Set<String>
    var isIPad: Bool

    private let intentions: [(title: String, icon: String)] = [
        ("Track my thoughts", "brain.head.profile"),
        ("Understand my emotions", "heart.text.square"),
        ("Build a daily habit", "calendar.badge.clock"),
        ("Remember my life", "book.pages"),
        ("Create my Digital Twin", "person.crop.circle.badge.plus")
    ]

    var body: some View {
        VStack(spacing: isIPad ? 32 : 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("What brings you here?")
                    .font(.system(size: isIPad ? 40 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Pick any that resonate. This helps DailyVox meet you where you are.")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, isIPad ? 80 : 30)

            VStack(spacing: 12) {
                ForEach(intentions, id: \.title) { intention in
                    IntentionCard(
                        title: intention.title,
                        icon: intention.icon,
                        isSelected: selectedIntentions.contains(intention.title),
                        isIPad: isIPad
                    ) {
                        if selectedIntentions.contains(intention.title) {
                            selectedIntentions.remove(intention.title)
                        } else {
                            selectedIntentions.insert(intention.title)
                        }
                    }
                }
            }
            .padding(.horizontal, isIPad ? 80 : 30)
            .frame(maxWidth: isIPad ? 600 : .infinity)

            Spacer()
            Spacer()
        }
    }
}

struct IntentionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isIPad: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: isIPad ? 24 : 20))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .frame(width: 32)

                Text(title)
                    .font(isIPad ? .title3.weight(.medium) : .body.weight(.medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.purple.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Privacy Badge Component

struct PrivacyBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(compact ? .caption : .subheadline)
                .foregroundColor(.green)

            if !compact {
                Text("100% Private")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Offline Indicator

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("Offline")
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
