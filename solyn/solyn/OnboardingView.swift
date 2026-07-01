//
//  OnboardingView.swift
//  solyn
//
//  Signature onboarding — "Speak your first star into being."
//  Three beats: invite → speak (live waveform, on-device) → your star is born.
//  The product's magic (voice → a private star that never leaves the phone)
//  is *experienced* in the first 30 seconds, not explained.
//

import SwiftUI

// MARK: - Palette

private enum OB {
    static let paper   = Color(red: 0.980, green: 0.972, blue: 0.961)
    static let paper2  = Color(red: 0.949, green: 0.929, blue: 0.910)
    static let card    = Color.white
    static let ink     = Color(red: 0.102, green: 0.102, blue: 0.180)
    static let inkDim  = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.62)
    static let inkMute = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.40)
    static let rule    = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.10)
    static let gold    = Color(red: 0.831, green: 0.647, blue: 0.278)
    static let sage    = Color(red: 0.357, green: 0.486, blue: 0.420)
    static let forest  = Color(red: 0.420, green: 0.620, blue: 0.482)
}

// MARK: - Container

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var screen = 0          // 0 invite, 1 speak, 2 claim
    @State private var starBorn = false
    @State private var transcript = ""

    private var demo: Bool { ProcessInfo.processInfo.arguments.contains("-OnboardingDemo") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [OB.paper, OB.paper2], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            LivingSky(bright: starBorn ? 1 : 0)

            Group {
                switch screen {
                case 0:
                    InviteScreen(demo: demo) { advance() }
                case 1:
                    SpeakScreen(demo: demo) { text in
                        transcript = text
                        withAnimation(.easeInOut(duration: 0.8)) { starBorn = true }
                        advance()
                    }
                default:
                    ClaimScreen(transcript: transcript, onEnter: complete)
                }
            }
            .transition(.opacity)
        }
    }

    private func advance() { withAnimation(.easeInOut(duration: 0.6)) { screen += 1 } }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.4)) { hasCompletedOnboarding = true }
    }
}

// MARK: - Beat 1: Invite

private struct InviteScreen: View {
    let demo: Bool
    let onBegin: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(OB.gold.opacity(appear ? 0.14 : 0)).frame(width: 140, height: 140)
                Circle().fill(OB.gold.opacity(appear ? 0.22 : 0)).frame(width: 84, height: 84)
                Image(systemName: "waveform")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(OB.gold)
            }
            .scaleEffect(appear ? 1 : 0.7)

            VStack(spacing: 14) {
                Text("Your sky starts\nwith your voice")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No forms, no sign-up. Just talk about\nyour day — and watch your voice become\nthe first star in a sky only you can see.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.top, 32)
            .padding(.horizontal, 30)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer()
            Spacer()

            PrimaryButton(title: "I'm ready", filled: true, action: onBegin)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { appear = true }
            if demo {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    onBegin()
                }
            }
        }
    }
}

// MARK: - Beat 2: Speak (the heart)

private struct SpeakScreen: View {
    let demo: Bool
    let onBorn: (String) -> Void

    @StateObject private var recorder = AudioRecorder()
    @State private var phase: Phase = .idle
    @State private var level: CGFloat = 0
    @State private var elapsed: Double = 0
    @State private var transcript = ""
    @State private var flare: CGFloat = 0

    enum Phase { case idle, recording, processing, born }
    private let softTarget: Double = 42

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text(headline)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subhead)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [OB.gold.opacity(0.16), .clear],
                                         center: .center, startRadius: 6, endRadius: 130))
                    .frame(width: 260, height: 260)

                if phase == .born {
                    BornStar(flare: flare)
                } else {
                    WaveOrb(level: level, active: phase == .recording)
                }
            }
            .frame(height: 260)

            Spacer().frame(height: 36)

            control
                .frame(height: 96)

            Spacer()
        }
        .onReceive(recorder.$level) { l in
            withAnimation(.easeOut(duration: 0.08)) { level = CGFloat(l) }
        }
        .onReceive(recorder.$currentTime) { t in
            elapsed = t
            if t >= softTarget { finish() }
        }
        .onAppear(perform: autoDemo)
    }

    private var headline: String {
        switch phase {
        case .born: return "A star is born."
        case .processing: return "Finding your words…"
        default: return "How was your day,\nreally?"
        }
    }
    private var subhead: String {
        switch phase {
        case .idle: return "Speak, don't type. DailyVox turns it into your private journal — kept on your phone."
        case .recording: return "Listening… speak as long as you like."
        case .processing: return "On-device. Nothing left your phone."
        case .born: return "Your voice, now a light in your sky."
        }
    }

    @ViewBuilder private var control: some View {
        switch phase {
        case .idle:
            VStack(spacing: 12) {
                Button(action: start) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [OB.sage, OB.sage.opacity(0.85)],
                                                     startPoint: .top, endPoint: .bottom))
                            .frame(width: 76, height: 76)
                            .shadow(color: OB.sage.opacity(0.35), radius: 14, y: 6)
                        Image(systemName: "mic.fill").font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                Text("Tap to speak").font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(OB.inkMute)
            }
        case .recording:
            Button(action: finish) {
                HStack(spacing: 8) {
                    Circle().fill(OB.forest).frame(width: 8, height: 8)
                    Text("Done · \(Int(elapsed))s")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.vertical, 15).padding(.horizontal, 34)
                .background(Capsule().fill(OB.ink))
            }
        case .processing:
            HStack(spacing: 10) {
                ProgressView().tint(OB.sage)
                Text("finding your words…").font(.system(size: 14, design: .rounded))
                    .foregroundColor(OB.inkMute)
            }
        case .born:
            Color.clear
        }
    }

    // MARK: Actions

    private func start() {
        withAnimation(.easeInOut(duration: 0.3)) { phase = .recording }
        guard !demo else { return }
        do { try recorder.startRecording() } catch { finish() }
    }

    private func finish() {
        guard phase == .recording else { return }
        if demo {
            transcript = "Today felt lighter than yesterday. I paused for a minute and just breathed."
            born(); return
        }
        withAnimation(.easeInOut(duration: 0.3)) { phase = .processing }
        guard let res = recorder.stopRecording() else { transcript = ""; born(); return }
        SpeechTranscriber.shared.transcribe(from: res.url) { result in
            DispatchQueue.main.async {
                if case .success(let t) = result { transcript = t }
                born()
            }
        }
    }

    private func born() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.58)) { phase = .born }
        withAnimation(.easeOut(duration: 0.8)) { flare = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onBorn(transcript) }
    }

    private func autoDemo() {
        guard demo else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { phase = .recording }
            let began = Date()
            while phase == .recording && Date().timeIntervalSince(began) < 5.2 {
                let e = Date().timeIntervalSince(began)
                let env = 0.55 + 0.45 * sin(e * 2.1)
                level = CGFloat(max(0.06, abs(sin(e * 7.5)) * env))
                elapsed = e
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            finish()
        }
    }
}

// MARK: - Live waveform orb (bars radiating; amplitude follows the mic level)

private struct WaveOrb: View {
    let level: CGFloat
    let active: Bool
    private let bars = 40

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            let t: Double = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(OB.card)
                    .frame(width: 96, height: 96)
                    .shadow(color: OB.ink.opacity(0.05), radius: 8, y: 3)
                Circle()
                    .fill(OB.gold.opacity(0.9))
                    .frame(width: 14, height: 14)
                    .scaleEffect(1 + (active ? level * 0.8 : 0))

                ForEach(0..<bars, id: \.self) { i in
                    bar(i: i, t: t)
                }
            }
        }
    }

    private func bar(i: Int, t: Double) -> some View {
        let angle: Double = Double(i) / Double(bars) * 360.0
        let wobble: Double = 0.5 + 0.5 * sin(t * 3.0 + Double(i) * 0.7)
        let amp: CGFloat = active ? level * CGFloat(wobble) : 0.04
        let h: CGFloat = 10 + amp * 64
        return Capsule()
            .fill(LinearGradient(colors: [OB.gold, OB.sage], startPoint: .top, endPoint: .bottom))
            .frame(width: 3.2, height: h)
            .offset(y: -70)
            .rotationEffect(.degrees(angle))
            .opacity(active ? 0.9 : 0.35)
    }
}

// MARK: - The born star (flare + rays)

private struct BornStar: View {
    let flare: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(OB.gold.opacity(0.18 * Double(flare))).frame(width: 200, height: 200)
                .scaleEffect(0.6 + flare * 0.6)
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(OB.gold.opacity(0.5 * Double(flare)))
                    .frame(width: 2, height: 60)
                    .offset(y: -46)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
                    .scaleEffect(y: flare)
            }
            Circle().fill(OB.gold).frame(width: 26, height: 26)
                .shadow(color: OB.gold.opacity(0.7), radius: 16)
                .scaleEffect(0.4 + flare * 0.9)
            Circle().fill(.white).frame(width: 10, height: 10)
                .scaleEffect(flare)
        }
    }
}

// MARK: - Beat 3: Claim

private struct ClaimScreen: View {
    let transcript: String
    let onEnter: () -> Void
    @State private var appear = false

    private var words: String {
        let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "your first words" : t
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(OB.gold.opacity(0.14)).frame(width: 120, height: 120)
                Circle().fill(OB.gold).frame(width: 24, height: 24)
                    .shadow(color: OB.gold.opacity(0.6), radius: 14)
                Circle().fill(.white).frame(width: 8, height: 8)
            }
            .scaleEffect(appear ? 1 : 0.6).opacity(appear ? 1 : 0)

            VStack(spacing: 16) {
                Text("That star is yours.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)

                Text("“\(words)”")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .italic()
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.card))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OB.rule, lineWidth: 1))
                    .padding(.horizontal, 26)

                Text("It lives on your phone — nowhere else.\nSpeak again tomorrow, and your sky grows.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer()
            Spacer()

            PrimaryButton(title: "Enter my sky", filled: true, action: onEnter)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) { appear = true } }
    }
}

// MARK: - Primary button

private struct PrimaryButton: View {
    let title: String
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(LinearGradient(colors: [OB.sage, OB.sage.opacity(0.85)],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: OB.sage.opacity(0.28), radius: 12, y: 6)
        }
    }
}

// MARK: - Living sky

private struct LivingSky: View {
    let bright: Int   // number of hero stars lit (after the first is born)

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t: Double = tl.date.timeIntervalSinceReferenceDate
                let w: Double = size.width
                let h: Double = size.height
                for i in 0..<64 {
                    let seed: UInt64 = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
                    let x: Double = Double((seed >> 16) % 10000) / 10000.0 * w
                    let y: Double = Double((seed >> 32) % 10000) / 10000.0 * h
                    let r: Double = Double((seed >> 48) % 100) / 100.0 * 1.5 + 0.4
                    let phase: Double = Double((seed >> 8) % 628) / 100.0
                    let tw: Double = 0.55 + 0.45 * sin(t * 1.1 + phase)
                    let isGold: Bool = (seed >> 4) % 6 == 0
                    let base: Double = Double((seed >> 12) % 100) / 100.0 * 0.10 + 0.04
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let col: Color = (isGold ? OB.gold : OB.sage).opacity(base * tw)
                    ctx.fill(Path(ellipseIn: rect), with: .color(col))
                }
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
                Text("100% Private").font(.caption.weight(.medium)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 4 : 6)
        .background(Color(red: 0.420, green: 0.620, blue: 0.482).opacity(0.1))
        .clipShape(Capsule())
    }
}

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(red: 0.420, green: 0.620, blue: 0.482)).frame(width: 6, height: 6)
            Text("Offline").font(.caption2.weight(.medium)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground)).clipShape(Capsule())
    }
}

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
