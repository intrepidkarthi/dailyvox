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
            iconColor: Color(red: 0.831, green: 0.647, blue: 0.278),  // warm gold — the sun at the centre
            title: "Meet Your Digital Twin",
            subtitle: "The sun at the center of your sky",
            description: "Your Digital Twin orbits your inner world — learning your personality, emotional patterns, and the people in your life. Four planets emerge: Mind, Heart, Voice, and Graph.",
            gradient: [
                Color(red: 38/255, green: 30/255, blue: 22/255),    // deep warm espresso
                Color(red: 92/255, green: 68/255, blue: 38/255)     // warm amber-bronze
            ]
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: Color(red: 0.769, green: 0.584, blue: 0.416),
            title: "Insights That Matter",
            subtitle: "Patterns written in light",
            description: "Like an aurora forming in your night sky, insights emerge from your journal entries. Mood trends, streaks, and emotional patterns — visible only when you look up.",
            gradient: [
                Color(red: 50/255, green: 38/255, blue: 30/255),    // Deep brown
                Color(red: 120/255, green: 80/255, blue: 55/255)    // Warm amber
            ]
        ),
        OnboardingPage(
            icon: "lock.shield",
            iconColor: Color(red: 0.420, green: 0.620, blue: 0.482),
            title: "100% Private. Always.",
            subtitle: "A constellation no one else can see",
            description: "Your stars are protected by an unbreakable shield. All AI runs on your device. No servers. No accounts. No one watches your sky but you.",
            gradient: [
                Color(red: 25/255, green: 40/255, blue: 38/255),    // Deep teal-green
                Color(red: 50/255, green: 80/255, blue: 70/255)     // Forest green
            ]
        )
    ]

    private var backgroundGradient: [Color] {
        if currentPage == 0 {
            // Warm night sky for the welcome star (matches the app's warm theme)
            return [
                Color(red: 26/255, green: 21/255, blue: 18/255),   // warm espresso night
                Color(red: 42/255, green: 32/255, blue: 26/255)    // warm dusk
            ]
        } else if currentPage <= pages.count {
            // Feature pages (1-based index, so subtract 1 for array)
            return pages[currentPage - 1].gradient
        } else {
            // Intention check-in page — deep sage close (warm, on-brand)
            return [
                Color(red: 28/255, green: 38/255, blue: 32/255),    // deep sage night
                Color(red: 56/255, green: 78/255, blue: 64/255)     // warm sage
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
    @State private var breathe = false   // continuous glow pulse
    @State private var drift = false     // slow ambient-star rotation

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Constellation star animation
            ZStack {
                // Outer glow — gently breathing
                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(glowOpacity * 0.15))
                    .frame(width: 200, height: 200)
                    .scaleEffect(breathe ? 1.12 : 0.94)

                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(glowOpacity * 0.25))
                    .frame(width: 120, height: 120)
                    .scaleEffect(breathe ? 1.08 : 0.96)

                // Core star
                Circle()
                    .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.8))
                    .frame(width: 20, height: 20)
                    .scaleEffect(starScale * (breathe ? 1.08 : 1.0))
                    .shadow(color: Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.6), radius: 20)

                // White hot center
                Circle()
                    .fill(Color(red: 0.957, green: 0.933, blue: 0.878))
                    .frame(width: 8, height: 8)
                    .scaleEffect(starScale)

                // Ambient stars around core — slowly drifting as a ring
                ZStack {
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
                .rotationEffect(.degrees(drift ? 360 : 0))
                .animation(.linear(duration: 90).repeatForever(autoreverses: false), value: drift)
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
            // Ongoing living motion (so the welcome screen isn't static like before)
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.6)) {
                breathe = true
            }
            drift = true
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
    @State private var animate1 = false
    @State private var animate2 = false
    @State private var animate3 = false
    @State private var textOpacity: Double = 0

    private var isIPad: Bool { horizontalSizeClass == .regular }

    // Warm palette
    private let warmGold = Color(red: 0.831, green: 0.647, blue: 0.278)
    private let sageGreen = Color(red: 0.357, green: 0.486, blue: 0.420)
    private let softCoral = Color(red: 0.769, green: 0.451, blue: 0.420)
    private let forestGreen = Color(red: 0.420, green: 0.620, blue: 0.482)
    private let ivory = Color(red: 0.957, green: 0.933, blue: 0.878)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Each page gets a unique celestial visual
            Group {
                switch page.icon {
                case "person.crop.circle.fill":
                    twinPlanetSystem
                case "chart.bar.fill":
                    auroraInsights
                case "lock.shield":
                    shieldConstellation
                default:
                    twinPlanetSystem
                }
            }
            .frame(height: isIPad ? 280 : 220)
            .padding(.bottom, 24)

            // Text with staggered fade
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: isIPad ? 36 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: isIPad ? 17 : 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: isIPad ? 15 : 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, isIPad ? 60 : 28)
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .opacity(textOpacity)
            .offset(y: textOpacity > 0 ? 0 : 20)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate1 = true
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                animate2 = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
                animate3 = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                textOpacity = 1
            }
        }
        .onDisappear {
            animate1 = false
            animate2 = false
            animate3 = false
            textOpacity = 0
        }
    }

    // MARK: - Page 1: Digital Twin = Your Personal Star System
    // Central sun with 4 orbiting planets (Mind, Heart, Voice, Graph)

    private var twinPlanetSystem: some View {
        ZStack {
            // Outer orbit path
            Circle()
                .stroke(ivory.opacity(0.08), lineWidth: 1)
                .frame(width: isIPad ? 240 : 190, height: isIPad ? 240 : 190)

            // Middle orbit path
            Circle()
                .stroke(ivory.opacity(0.12), lineWidth: 1)
                .frame(width: isIPad ? 170 : 130, height: isIPad ? 170 : 130)

            // Inner orbit path
            Circle()
                .stroke(ivory.opacity(0.06), lineWidth: 0.5)
                .frame(width: isIPad ? 260 : 210, height: isIPad ? 260 : 210)

            // Planet: Mind (outer orbit, top)
            planetDot(color: page.iconColor, size: 10, label: "Mind")
                .offset(x: 0, y: isIPad ? -120 : -95)
                .rotationEffect(.degrees(animate2 ? 360 : 0))
                .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: animate2)

            // Planet: Heart (middle orbit, right)
            planetDot(color: softCoral, size: 8, label: "Heart")
                .offset(x: isIPad ? 85 : 65, y: 0)
                .rotationEffect(.degrees(animate2 ? -360 : 0))
                .animation(.linear(duration: 28).repeatForever(autoreverses: false), value: animate2)

            // Planet: Voice (middle orbit, left)
            planetDot(color: forestGreen, size: 9, label: "Voice")
                .offset(x: isIPad ? -85 : -65, y: isIPad ? 30 : 20)
                .rotationEffect(.degrees(animate2 ? 360 : 0))
                .animation(.linear(duration: 34).repeatForever(autoreverses: false), value: animate2)

            // Planet: Graph (outer orbit, bottom-right)
            planetDot(color: warmGold, size: 7, label: "Graph")
                .offset(x: isIPad ? 70 : 55, y: isIPad ? 90 : 70)
                .rotationEffect(.degrees(animate2 ? -360 : 0))
                .animation(.linear(duration: 50).repeatForever(autoreverses: false), value: animate2)

            // Central sun (your Twin)
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(animate1 ? 0.15 : 0))
                    .frame(width: isIPad ? 100 : 80, height: isIPad ? 100 : 80)

                Circle()
                    .fill(page.iconColor.opacity(animate1 ? 0.3 : 0))
                    .frame(width: isIPad ? 60 : 48, height: isIPad ? 60 : 48)
                    .shadow(color: page.iconColor.opacity(0.5), radius: 16)

                Circle()
                    .fill(page.iconColor.opacity(0.7))
                    .frame(width: isIPad ? 32 : 24, height: isIPad ? 32 : 24)

                Circle()
                    .fill(ivory.opacity(0.8))
                    .frame(width: isIPad ? 14 : 10, height: isIPad ? 14 : 10)
            }
            .scaleEffect(animate1 ? 1.0 : 0.5)
        }
    }

    // MARK: - Page 2: Insights = Aurora / Nebula Waves

    private var auroraColors: [Color] {
        [warmGold, page.iconColor, sageGreen, softCoral, forestGreen]
    }

    private var auroraOffsets: [CGFloat] { [-15, 10, -8, 12, -5] }

    private var auroraInsights: some View {
        ZStack {
            // Aurora bands
            ForEach(0..<5, id: \.self) { i in
                let bandColor = auroraColors[i]
                let bandWidth: CGFloat = isIPad ? CGFloat(220 - i * 25) : CGFloat(180 - i * 20)
                let bandHeight: CGFloat = isIPad ? 6 : 4
                let xOffset: CGFloat = animate2 ? auroraOffsets[i] : 0
                let yOffset: CGFloat = CGFloat(i * (isIPad ? 28 : 22) - 50)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [bandColor.opacity(0.3), bandColor.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: bandWidth, height: bandHeight)
                    .offset(x: xOffset, y: yOffset)
                    .scaleEffect(x: animate1 ? 1.0 : 0.3, anchor: .center)
                    .opacity(animate1 ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 3.0 + Double(i) * 0.5)
                        .repeatForever(autoreverses: true),
                        value: animate2
                    )
            }

            // Data point stars emerging from aurora
            auroraDataPoints

            // Central insight orb
            auroraOrb
        }
    }

    private var auroraDataPoints: some View {
        ForEach(0..<8, id: \.self) { i in
            let angle = Double(i) * (.pi * 2 / 8) + 0.3
            let radius: CGFloat = isIPad ? 80 : 65
            let dotSize: CGFloat = CGFloat(2 + i % 3)
            Circle()
                .fill(ivory.opacity(animate3 ? 0.6 : 0))
                .frame(width: dotSize, height: dotSize)
                .offset(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius * 0.5
                )
                .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.1), value: animate3)
        }
    }

    private var auroraOrb: some View {
        ZStack {
            Circle()
                .fill(page.iconColor.opacity(animate1 ? 0.12 : 0))
                .frame(width: isIPad ? 80 : 64, height: isIPad ? 80 : 64)

            Circle()
                .fill(page.iconColor.opacity(0.4))
                .frame(width: isIPad ? 36 : 28, height: isIPad ? 36 : 28)
                .shadow(color: page.iconColor.opacity(0.6), radius: 12)

            Image(systemName: "sparkle")
                .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                .foregroundColor(ivory)
        }
        .scaleEffect(animate1 ? 1.0 : 0.6)
    }

    // MARK: - Page 3: Privacy = Protective Star Shield

    private var shieldConstellation: some View {
        ZStack {
            // Outer protective ring of stars
            shieldStarRing

            // Connection lines forming the shield
            shieldConnectionLines

            // Pulsing protection rings
            shieldPulsingRings

            // Central shield
            shieldCenter
        }
    }

    private var shieldStarRing: some View {
        ForEach(0..<12, id: \.self) { i in
            let angle = Double(i) * (.pi * 2 / 12)
            let radius: CGFloat = isIPad ? 100 : 80
            Circle()
                .fill(forestGreen.opacity(animate1 ? 0.7 : 0))
                .frame(width: 4, height: 4)
                .offset(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius
                )
                .shadow(color: forestGreen.opacity(0.4), radius: 4)
                .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.05), value: animate1)
        }
    }

    private var shieldConnectionLines: some View {
        let r: CGFloat = isIPad ? 100 : 80
        let frameSize: CGFloat = (r + 10) * 2
        return ForEach(0..<12, id: \.self) { i in
            let angle1 = Double(i) * (.pi * 2 / 12)
            let angle2 = Double((i + 1) % 12) * (.pi * 2 / 12)
            let startX = cos(angle1) * r + r + 10
            let startY = sin(angle1) * r + r + 10
            let endX = cos(angle2) * r + r + 10
            let endY = sin(angle2) * r + r + 10
            Path { path in
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(forestGreen.opacity(animate2 ? 0.2 : 0), lineWidth: 0.8)
            .frame(width: frameSize, height: frameSize)
            .offset(x: -(r + 10), y: -(r + 10))
            .animation(.easeOut(duration: 0.8).delay(0.6 + Double(i) * 0.04), value: animate2)
        }
    }

    private var shieldPulsingRings: some View {
        ForEach(0..<3, id: \.self) { i in
            let ringSize: CGFloat = isIPad ? CGFloat(110 + i * 30) : CGFloat(90 + i * 24)
            Circle()
                .stroke(forestGreen.opacity(animate3 ? 0 : 0.2), lineWidth: 1)
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(animate3 ? 1.4 : 1.0)
                .animation(
                    .easeOut(duration: 2.5)
                    .repeatForever(autoreverses: false)
                    .delay(Double(i) * 0.8),
                    value: animate3
                )
        }
    }

    private var shieldCenter: some View {
        ZStack {
            Circle()
                .fill(forestGreen.opacity(animate1 ? 0.15 : 0))
                .frame(width: isIPad ? 70 : 56, height: isIPad ? 70 : 56)

            Circle()
                .fill(forestGreen.opacity(0.35))
                .frame(width: isIPad ? 44 : 34, height: isIPad ? 44 : 34)
                .shadow(color: forestGreen.opacity(0.5), radius: 12)

            Image(systemName: "lock.fill")
                .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                .foregroundColor(ivory)
        }
        .scaleEffect(animate1 ? 1.0 : 0.5)
    }

    // MARK: - Planet Dot Helper

    private func planetDot(color: Color, size: CGFloat, label: String) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size + 8, height: size + 8)
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.6), radius: 4)
            }
            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(ivory.opacity(0.4))
        }
        .opacity(animate1 ? 1 : 0)
    }
}

// MARK: - Intention Check-In Page

struct IntentionCheckInView: View {
    @Binding var selectedIntentions: Set<String>
    var isIPad: Bool

    private let intentions: [(title: String, icon: String, planet: String)] = [
        ("Track my thoughts", "brain.head.profile", "Mercury"),
        ("Understand my emotions", "heart.text.square", "Venus"),
        ("Build a daily habit", "calendar.badge.clock", "Mars"),
        ("Remember my life", "book.pages", "Jupiter"),
        ("Create my Digital Twin", "person.crop.circle.badge.plus", "Saturn")
    ]

    var body: some View {
        VStack(spacing: isIPad ? 32 : 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("Name your planets")
                    .font(.system(size: isIPad ? 40 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Each intention becomes a planet in your constellation. Pick the ones that matter.")
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
                        planet: intention.planet,
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
    let planet: String
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

                Text(planet)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(isSelected ? Color(red: 0.831, green: 0.647, blue: 0.278) : .white.opacity(0.25))

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
