//
//  OnboardingView.swift
//  solyn
//
//  Warm, ivory-light onboarding — constellation / "inner sky" language.
//  Flow: Welcome → Name yourself (optional) → Your Twin → Private →
//  Name your planets → Ready to record.
//

import SwiftUI

// MARK: - Palette (warm ivory, matches the app theme)

private enum OB {
    static let paper   = Color(red: 0.980, green: 0.972, blue: 0.961)  // #FAF8F5
    static let paper2  = Color(red: 0.949, green: 0.929, blue: 0.910)  // warm dusk paper
    static let card    = Color.white
    static let ink     = Color(red: 0.102, green: 0.102, blue: 0.180)  // #1A1A2E
    static let inkDim  = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.62)
    static let inkMute = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.40)
    static let rule    = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.10)
    static let gold    = Color(red: 0.831, green: 0.647, blue: 0.278)
    static let sage    = Color(red: 0.357, green: 0.486, blue: 0.420)
    static let forest  = Color(red: 0.420, green: 0.620, blue: 0.482)
    static let coral   = Color(red: 0.769, green: 0.451, blue: 0.420)
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentPage = 0
    @State private var userName = ""
    @State private var selectedIntentions: Set<String> = []
    @FocusState private var nameFocused: Bool

    private var isIPad: Bool { horizontalSizeClass == .regular }

    // Ordered steps
    private enum Step: Int, CaseIterable {
        case welcome, name, twin, privacy, intention, ready
    }
    private var totalSteps: Int { Step.allCases.count }
    private var isLast: Bool { currentPage == totalSteps - 1 }

    var body: some View {
        ZStack {
            // Warm ivory background
            LinearGradient(
                colors: [OB.paper, OB.paper2],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            IvorySky()

            VStack(spacing: 0) {
                // Top bar — Skip (hidden on the final page)
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Skip") {
                            nameFocused = false
                            withAnimation(.spring(response: 0.4)) {
                                currentPage = totalSteps - 1
                            }
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(OB.inkMute)
                        .padding()
                    }
                }

                // Pages
                TabView(selection: $currentPage) {
                    WelcomeStep(isIPad: isIPad).tag(Step.welcome.rawValue)
                    NameStep(userName: $userName, focused: $nameFocused, isIPad: isIPad)
                        .tag(Step.name.rawValue)
                    MessageStep(
                        symbol: "mic.fill", tint: OB.gold,
                        title: "Your voice builds a\nDigital Twin",
                        message: "Speak about 42 seconds a day. Your Twin learns your personality, moods, and the people in your life — all on your phone.",
                        isIPad: isIPad
                    ).tag(Step.twin.rawValue)
                    MessageStep(
                        symbol: "lock.shield.fill", tint: OB.sage,
                        title: "A sky no one else\ncan see",
                        message: "Everything runs on your device. No account, no cloud, no one watching. Apple's privacy label: Data Not Collected.",
                        isIPad: isIPad
                    ).tag(Step.privacy.rawValue)
                    IntentionCheckInView(selectedIntentions: $selectedIntentions, isIPad: isIPad)
                        .tag(Step.intention.rawValue)
                    ReadyStep(name: trimmedName, isIPad: isIPad).tag(Step.ready.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4), value: currentPage)

                // Constellation progress dots
                HStack(spacing: 12) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Image(systemName: index <= currentPage ? "star.fill" : "star")
                            .font(.system(size: index == currentPage ? 10 : 8))
                            .foregroundColor(index <= currentPage ? OB.gold : OB.inkMute.opacity(0.5))
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Primary action
                Button(action: advance) {
                    HStack(spacing: 8) {
                        if isLast {
                            Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold))
                        }
                        Text(primaryTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        if !isLast {
                            Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(colors: [OB.sage, OB.sage.opacity(0.85)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: OB.sage.opacity(0.28), radius: 12, y: 6)
                }
                .frame(maxWidth: isIPad ? 500 : .infinity)
                .padding(.horizontal, isIPad ? 60 : 28)
                .padding(.bottom, 44)
            }
        }
    }

    private var trimmedName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var primaryTitle: String {
        switch Step(rawValue: currentPage) {
        case .name: return trimmedName.isEmpty ? "Skip for now" : "Continue"
        case .ready: return "Record my first star"
        default: return "Next"
        }
    }

    private func advance() {
        nameFocused = false
        if isLast {
            completeOnboarding()
        } else {
            withAnimation(.spring(response: 0.4)) { currentPage += 1 }
        }
    }

    private func completeOnboarding() {
        if !trimmedName.isEmpty {
            UserDefaults.standard.set(trimmedName, forKey: "userName")
        }
        UserDefaults.standard.set(Array(selectedIntentions), forKey: "onboardingIntentions")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Welcome (breathing gold star on ivory)

private struct WelcomeStep: View {
    let isIPad: Bool
    @State private var starScale: CGFloat = 0.3
    @State private var glow: Double = 0
    @State private var textOpacity: Double = 0
    @State private var breathe = false
    @State private var drift = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(OB.gold.opacity(glow * 0.18))
                    .frame(width: 200, height: 200)
                    .scaleEffect(breathe ? 1.12 : 0.94)
                Circle()
                    .fill(OB.gold.opacity(glow * 0.28))
                    .frame(width: 118, height: 118)
                    .scaleEffect(breathe ? 1.08 : 0.96)
                Circle()
                    .fill(OB.gold)
                    .frame(width: 22, height: 22)
                    .scaleEffect(starScale * (breathe ? 1.08 : 1.0))
                    .shadow(color: OB.gold.opacity(0.6), radius: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .scaleEffect(starScale)

                // Ambient drifting stars
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * (.pi * 2 / 8)
                    let radius: CGFloat = 85 + CGFloat(i % 3) * 20
                    Circle()
                        .fill(OB.sage.opacity(glow * (0.30 + Double(i % 3) * 0.10)))
                        .frame(width: CGFloat(3 + i % 2), height: CGFloat(3 + i % 2))
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
                .rotationEffect(.degrees(drift ? 360 : 0))
                .animation(.linear(duration: 90).repeatForever(autoreverses: false), value: drift)
            }

            Spacer().frame(height: 56)

            VStack(spacing: 14) {
                Text("Your inner sky\nis waiting")
                    .font(.system(size: isIPad ? 44 : 38, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                Text("Every thought you speak becomes a star.\nOver time, constellations form — patterns\nonly you can see.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 30)
            .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) { starScale = 1.0; glow = 1.0 }
            withAnimation(.easeOut(duration: 1.0).delay(0.7)) { textOpacity = 1.0 }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.5)) { breathe = true }
            drift = true
        }
    }
}

// MARK: - Name yourself (optional, sage focus ring)

private struct NameStep: View {
    @Binding var userName: String
    var focused: FocusState<Bool>.Binding
    let isIPad: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            IconBadge(symbol: "sparkle", tint: OB.gold)

            VStack(spacing: 12) {
                Text("Let's get to know you")
                    .font(.system(size: isIPad ? 34 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                Text("DailyVox becomes more yours with every word.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)

            TextField("Your name", text: $userName)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused(focused)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(OB.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(focused.wrappedValue ? OB.sage : OB.rule,
                                lineWidth: focused.wrappedValue ? 2 : 1)
                )
                .shadow(color: OB.ink.opacity(0.04), radius: 6, y: 3)
                .padding(.top, 28)
                .padding(.horizontal, 32)
                .frame(maxWidth: isIPad ? 460 : .infinity)
                .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)

            Text("Optional — stored only on your phone.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(OB.inkMute)
                .padding(.top, 12)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Message step (icon + title + body)

private struct MessageStep: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let isIPad: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            IconBadge(symbol: symbol, tint: tint)
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: isIPad ? 36 : 30, weight: .bold, design: .rounded))
                    .tracking(-0.4)
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 28)
            .padding(.horizontal, isIPad ? 60 : 30)
            .frame(maxWidth: isIPad ? 600 : .infinity)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Ready to record (personalised)

private struct ReadyStep: View {
    let name: String
    let isIPad: Bool
    @State private var pop = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(OB.sage.opacity(0.12)).frame(width: 128, height: 128)
                Circle().fill(OB.sage).frame(width: 76, height: 76)
                    .shadow(color: OB.sage.opacity(0.4), radius: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(pop ? 1.0 : 0.6)
            .opacity(pop ? 1 : 0)

            VStack(spacing: 14) {
                Text(name.isEmpty ? "Ready to be heard" : "Ready when you are,\n\(name).")
                    .font(.system(size: isIPad ? 36 : 30, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                Text("Your inner sky is ready. Speak your first star — 42 seconds is all it takes.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 28)
            .padding(.horizontal, isIPad ? 60 : 30)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { pop = true }
        }
    }
}

// MARK: - Shared icon badge

private struct IconBadge: View {
    let symbol: String
    let tint: Color
    @State private var appear = false

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.12)).frame(width: 104, height: 104)
            Circle().fill(tint.opacity(0.20)).frame(width: 74, height: 74)
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(tint)
        }
        .scaleEffect(appear ? 1.0 : 0.6)
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appear = true } }
    }
}

// MARK: - Intention Check-In ("Name your planets")

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
        VStack(spacing: isIPad ? 28 : 22) {
            Spacer()

            VStack(spacing: 10) {
                Text("Name your planets")
                    .font(.system(size: isIPad ? 38 : 30, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                Text("Each intention becomes a planet in your sky. Pick the ones that matter.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, isIPad ? 80 : 28)

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
            .padding(.horizontal, isIPad ? 80 : 28)
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
                    .font(.system(size: isIPad ? 22 : 19))
                    .foregroundColor(isSelected ? OB.sage : OB.inkMute)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: isIPad ? 18 : 16, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? OB.ink : OB.inkDim)

                Spacer()

                Text(planet.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(isSelected ? OB.gold : OB.inkMute.opacity(0.6))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OB.forest)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? OB.sage.opacity(0.10) : OB.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? OB.sage.opacity(0.7) : OB.rule, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: OB.ink.opacity(isSelected ? 0 : 0.03), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Ivory constellation field (soft sage/gold dots on light)

private struct IvorySky: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<44 {
                let seed = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
                let x = Double((seed >> 16) % 10000) / 10000.0 * size.width
                let y = Double((seed >> 32) % 10000) / 10000.0 * size.height
                let r = Double((seed >> 48) % 100) / 100.0 * 1.6 + 0.4
                let useGold = (seed >> 4) % 5 == 0
                let opacity = Double((seed >> 8) % 100) / 100.0 * 0.14 + 0.05
                let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                context.fill(dot, with: .color((useGold ? OB.gold : OB.sage).opacity(opacity)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Shared components used elsewhere in the app (unchanged)

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

/// Ambient star field used by empty states / recording screens (white on dark).
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
