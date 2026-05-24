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
    private var totalPageCount: Int { pages.count + 2 } // welcome + feature pages + intention

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "person.crop.circle.fill",
            iconColor: .pink,
            title: "Meet Your Digital Twin",
            subtitle: "A mirror of your inner world",
            description: "Your Digital Twin learns your personality, emotional patterns, and the people and topics in your life. Watch it grow as you journal.",
            gradient: [
                Color(red: 45/255, green: 35/255, blue: 55/255),    // Deep purple-brown
                Color(red: 90/255, green: 65/255, blue: 80/255)     // Warm mauve
            ]
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: Color(red: 0.769, green: 0.584, blue: 0.416),
            title: "Insights That Matter",
            subtitle: "Understand yourself better",
            description: "Track mood trends, writing streaks, and emotional patterns. See your personal knowledge graph grow with the people, places, and topics in your life.",
            gradient: [
                Color(red: 50/255, green: 38/255, blue: 30/255),    // Deep brown
                Color(red: 120/255, green: 80/255, blue: 55/255)    // Warm amber
            ]
        ),
        OnboardingPage(
            icon: "lock.shield",
            iconColor: Color(red: 0.420, green: 0.620, blue: 0.482),
            title: "100% Private. Always.",
            subtitle: "Your innermost thoughts stay yours",
            description: "All AI runs on YOUR device. No third-party servers. No accounts. Optionally sync via your personal iCloud. Your mind belongs only to you.",
            gradient: [
                Color(red: 25/255, green: 40/255, blue: 38/255),    // Deep teal-green
                Color(red: 50/255, green: 80/255, blue: 70/255)     // Forest green
            ]
        )
    ]

    private var backgroundGradient: [Color] {
        if currentPage == 0 {
            // Celestial gradient for welcome star
            return [
                Color(red: 12/255, green: 12/255, blue: 28/255),   // Deep night
                Color(red: 20/255, green: 18/255, blue: 40/255)    // Warm night
            ]
        } else if currentPage <= pages.count {
            // Feature pages (1-based index, so subtract 1 for array)
            return pages[currentPage - 1].gradient
        } else {
            // Intention check-in page
            return [
                Color(red: 40/255, green: 35/255, blue: 50/255),    // Deep warm purple
                Color(red: 85/255, green: 60/255, blue: 75/255)     // Warm plum
            ]
        }
    }

    private var buttonGradientColors: [Color] {
        if currentPage == 0 {
            return [Color(red: 0.831, green: 0.647, blue: 0.278), Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.8)]
        } else if currentPage <= pages.count {
            let page = pages[currentPage - 1]
            return [page.iconColor, page.iconColor.opacity(0.8)]
        } else {
            // Last page: sage green
            return [Color(red: 0.357, green: 0.486, blue: 0.420), Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.8)]
        }
    }

    private var buttonShadowColor: Color {
        if currentPage == 0 {
            return Color(red: 0.831, green: 0.647, blue: 0.278)
        } else if currentPage <= pages.count {
            return pages[currentPage - 1].iconColor
        } else {
            return Color(red: 0.357, green: 0.486, blue: 0.420)
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            StarFieldView(count: 60)

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
                    // Page 0: Welcome star moment
                    OnboardingWelcomeView()
                        .tag(0)

                    // Pages 1-3: Feature pages
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index + 1)
                    }

                    // Last page: Intention check-in
                    IntentionCheckInView(selectedIntentions: $selectedIntentions, isIPad: isIPad)
                        .tag(pages.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Constellation-themed progress indicator
                HStack(spacing: 12) {
                    ForEach(0..<totalPageCount, id: \.self) { index in
                        Image(systemName: index <= currentPage ? "star.fill" : "star")
                            .font(.system(size: index == currentPage ? 10 : 8))
                            .foregroundColor(index <= currentPage ? Color(red: 0.831, green: 0.647, blue: 0.278) : .white.opacity(0.25))
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
                        Text(currentPage == totalPageCount - 1 ? "Begin my journey" : "Next")
                            .font(.headline)
                        if currentPage == totalPageCount - 1 {
                            Image(systemName: "sparkles")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: buttonGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: buttonShadowColor.opacity(0.3), radius: 10, y: 5)
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

// MARK: - Welcome Star Moment

struct OnboardingWelcomeView: View {
    @State private var starScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Constellation star animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(glowOpacity * 0.15))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(glowOpacity * 0.25))
                    .frame(width: 120, height: 120)

                // Core star
                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.8))
                    .frame(width: 20, height: 20)
                    .scaleEffect(starScale)
                    .shadow(color: Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.6), radius: 20)

                // White hot center
                Circle()
                    .fill(Color(red: 0.957, green: 0.933, blue: 0.878))
                    .frame(width: 8, height: 8)
                    .scaleEffect(starScale)

                // Ambient stars around core
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * (.pi * 2 / 8)
                    let radius: CGFloat = 85 + CGFloat(i % 3) * 20
                    Circle()
                        .fill(Color.white.opacity(glowOpacity * (0.15 + Double(i % 3) * 0.1)))
                        .frame(width: CGFloat(2 + i % 3), height: CGFloat(2 + i % 3))
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                }
            }

            Spacer()
                .frame(height: 60)

            VStack(spacing: 16) {
                Text("Your inner sky\nis waiting")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)

                Text("Every thought you speak becomes a star.\nOver time, constellations form — patterns\nonly you can see.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(textOpacity)
            }
            .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                starScale = 1.0
                glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
                textOpacity = 1.0
            }
        }
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
    @State private var iconVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var descVisible = false
    @State private var decorVisible = false

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: isIPad ? 36 : 28) {
            Spacer()

            // Unique visual per page (not just a circle with an icon)
            pageVisual
                .opacity(iconVisible ? 1 : 0)
                .scaleEffect(iconVisible ? 1 : 0.8)
                .padding(.bottom, 16)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: isIPad ? 38 : 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 16)

                Text(page.subtitle)
                    .font(.system(size: isIPad ? 18 : 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .opacity(subtitleVisible ? 1 : 0)
                    .offset(y: subtitleVisible ? 0 : 12)

                Text(page.description)
                    .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 10)
                    .opacity(descVisible ? 1 : 0)
                    .offset(y: descVisible ? 0 : 8)
            }
            .padding(.horizontal, isIPad ? 60 : 28)
            .frame(maxWidth: isIPad ? 600 : .infinity)

            Spacer()
            Spacer()
        }
        .onAppear { animateIn() }
        .onDisappear { resetAnimation() }
    }

    @ViewBuilder
    private var pageVisual: some View {
        switch page.icon {
        case "person.crop.circle.fill":
            // Digital Twin: Mini constellation with orbiting dots
            twinConstellation
        case "chart.bar.fill":
            // Insights: Animated rising bars
            insightsBars
        case "lock.shield":
            // Privacy: Shield with pulsing rings
            privacyShield
        default:
            genericIcon
        }
    }

    // --- Digital Twin: Mini constellation ---
    private var twinConstellation: some View {
        ZStack {
            // Outer orbit ring
            Circle()
                .stroke(page.iconColor.opacity(0.15), lineWidth: 1)
                .frame(width: isIPad ? 200 : 160, height: isIPad ? 200 : 160)
                .rotationEffect(.degrees(decorVisible ? 360 : 0))
                .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: decorVisible)

            // Middle orbit ring
            Circle()
                .stroke(page.iconColor.opacity(0.2), lineWidth: 1)
                .frame(width: isIPad ? 140 : 110, height: isIPad ? 140 : 110)

            // Orbiting dots
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? Color(red: 0.831, green: 0.647, blue: 0.278) : page.iconColor)
                    .frame(width: 6, height: 6)
                    .offset(x: CGFloat(isIPad ? 70 : 55))
                    .rotationEffect(.degrees(Double(i) * 72 + (decorVisible ? 360 : 0)))
                    .animation(.linear(duration: 20 + Double(i) * 4).repeatForever(autoreverses: false), value: decorVisible)
                    .shadow(color: page.iconColor.opacity(0.5), radius: 4)
            }

            // Core glow
            Circle()
                .fill(page.iconColor.opacity(0.2))
                .frame(width: isIPad ? 80 : 64, height: isIPad ? 80 : 64)

            Circle()
                .fill(page.iconColor.opacity(0.4))
                .frame(width: isIPad ? 48 : 36, height: isIPad ? 48 : 36)
                .shadow(color: page.iconColor.opacity(0.6), radius: 16)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: isIPad ? 28 : 22))
                .foregroundStyle(.white)
        }
    }

    // --- Insights: Animated bars ---
    private var insightsBars: some View {
        ZStack {
            Circle()
                .fill(page.iconColor.opacity(0.1))
                .frame(width: isIPad ? 180 : 140, height: isIPad ? 180 : 140)

            HStack(alignment: .bottom, spacing: isIPad ? 8 : 6) {
                ForEach(0..<7, id: \.self) { i in
                    let heights: [CGFloat] = [0.4, 0.65, 0.5, 0.85, 0.6, 0.75, 0.55]
                    let maxH: CGFloat = isIPad ? 80 : 60
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [page.iconColor, page.iconColor.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isIPad ? 12 : 9, height: decorVisible ? maxH * heights[i] : 4)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(i) * 0.08), value: decorVisible)
                }
            }
        }
    }

    // --- Privacy: Shield with rings ---
    private var privacyShield: some View {
        ZStack {
            // Pulsing rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(page.iconColor.opacity(decorVisible ? 0 : 0.3), lineWidth: 1.5)
                    .frame(width: CGFloat(isIPad ? 100 : 80) + CGFloat(i) * 40,
                           height: CGFloat(isIPad ? 100 : 80) + CGFloat(i) * 40)
                    .scaleEffect(decorVisible ? 1.3 : 1.0)
                    .animation(
                        .easeOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.6),
                        value: decorVisible
                    )
            }

            Circle()
                .fill(page.iconColor.opacity(0.15))
                .frame(width: isIPad ? 100 : 80, height: isIPad ? 100 : 80)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: isIPad ? 40 : 32))
                .foregroundStyle(.white)
                .shadow(color: page.iconColor.opacity(0.5), radius: 12)
        }
    }

    // --- Fallback ---
    private var genericIcon: some View {
        ZStack {
            Circle()
                .fill(page.iconColor.opacity(0.15))
                .frame(width: isIPad ? 140 : 110, height: isIPad ? 140 : 110)
            Image(systemName: page.icon)
                .font(.system(size: isIPad ? 50 : 40))
                .foregroundColor(page.iconColor)
        }
    }

    private func animateIn() {
        // Staggered entrance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            iconVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
            titleVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
            subtitleVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45)) {
            descVisible = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            decorVisible = true
        }
    }

    private func resetAnimation() {
        iconVisible = false
        titleVisible = false
        subtitleVisible = false
        descVisible = false
        decorVisible = false
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
                        .foregroundColor(Color(red: 0.420, green: 0.620, blue: 0.482))
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
                    .stroke(isSelected ? Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.5)
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
                .foregroundColor(Color(red: 0.420, green: 0.620, blue: 0.482))

            if !compact {
                Text("100% Private")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(Color(red: 0.420, green: 0.620, blue: 0.482).opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Offline Indicator

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(red: 0.420, green: 0.620, blue: 0.482))
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

// MARK: - Star Field Background

struct StarFieldView: View {
    let count: Int

    var body: some View {
        Canvas { context, size in
            for i in 0..<count {
                let seed = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
                let x = Double((seed >> 16) % 10000) / 10000.0 * size.width
                let y = Double((seed >> 32) % 10000) / 10000.0 * size.height
                let r = Double((seed >> 48) % 100) / 100.0 * 1.5 + 0.3
                let opacity = Double((seed >> 8) % 100) / 100.0 * 0.4 + 0.1

                let star = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                context.fill(star, with: .color(Color.white.opacity(opacity)))
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
