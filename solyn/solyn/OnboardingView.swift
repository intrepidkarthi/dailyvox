//
//  OnboardingView.swift
//  solyn
//
//  Premium, conversational onboarding — a living "inner sky" that grows a
//  star with every answer. Ivory-light, constellation language, springy
//  transitions. No mascot: the delight is the sky itself.
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

    @State private var step = 0
    @State private var answers: [Int: String] = [:]
    @State private var userName = ""
    @FocusState private var nameFocused: Bool

    private let questions: [Question] = [
        Question(prompt: "What brings you here?",
                 options: [Opt("🌙", "Track my thoughts"), Opt("💭", "Understand my emotions"),
                           Opt("🔥", "Build a daily habit"), Opt("📖", "Remember my life")]),
        Question(prompt: "How do you process your day?",
                 options: [Opt("🗣️", "I talk it out"), Opt("🌀", "I overthink it"),
                           Opt("🤐", "I keep it in"), Opt("✍️", "I already journal")]),
        Question(prompt: "When will you reflect?",
                 options: [Opt("🌅", "Morning"), Opt("☀️", "Midday"),
                           Opt("🌆", "Evening"), Opt("🌌", "Late night")])
    ]

    // Flow: 0 welcome, 1...3 questions, 4 name, 5 reveal
    private var lastStep: Int { questions.count + 2 }
    private var isQuestion: Bool { step >= 1 && step <= questions.count }
    private var questionIndex: Int { step - 1 }
    private var starsEarned: Int { min(step, questions.count) }   // grows through the quiz
    private var progress: CGFloat { CGFloat(step) / CGFloat(lastStep) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [OB.paper, OB.paper2], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            LivingSky(stars: starsEarned)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)

                ZStack {
                    current
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .frame(maxHeight: .infinity)

                Spacer(minLength: 0)
                primaryButton
            }
        }
        .onAppear(perform: runDemoIfNeeded)
    }

    // MARK: Steps

    @ViewBuilder private var current: some View {
        switch step {
        case 0:
            IntroStep()
        case let s where s >= 1 && s <= questions.count:
            QuestionStep(question: questions[s - 1],
                         selected: answers[s],
                         onSelect: { answers[s] = $0 })
        case questions.count + 1:
            NameStep(userName: $userName, focused: $nameFocused)
        default:
            RevealStep(name: trimmedName, stars: questions.count)
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            if step > 0 {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OB.inkDim)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(OB.card))
                        .overlay(Circle().stroke(OB.rule, lineWidth: 1))
                }
                .transition(.opacity)
            }
            ProgressRail(progress: progress)
            if step < lastStep {
                Button("Skip") { nameFocused = false; go(to: lastStep) }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(OB.inkMute)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .animation(.spring(response: 0.4), value: step)
    }

    private var primaryButton: some View {
        Button(action: advance) {
            HStack(spacing: 8) {
                if step == lastStep { Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold)) }
                Text(primaryTitle).font(.system(size: 17, weight: .semibold, design: .rounded))
                if step != lastStep { Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold)) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: primaryEnabled ? [OB.sage, OB.sage.opacity(0.85)] : [OB.inkMute, OB.inkMute],
                               startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: OB.sage.opacity(primaryEnabled ? 0.28 : 0), radius: 12, y: 6)
        }
        .disabled(!primaryEnabled)
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .animation(.easeInOut(duration: 0.2), value: primaryEnabled)
    }

    private var primaryEnabled: Bool {
        if isQuestion { return answers[step] != nil }
        return true
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Begin"
        case lastStep: return "Record my first star"
        case questions.count + 1: return trimmedName.isEmpty ? "Skip for now" : "Continue"
        default: return "Continue"
        }
    }

    private var trimmedName: String { userName.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Navigation

    private func advance() {
        nameFocused = false
        if step == lastStep { complete() } else { go(to: step + 1) }
    }
    private func back() { nameFocused = false; go(to: max(0, step - 1)) }
    private func go(to target: Int) { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { step = target } }

    private func complete() {
        if !trimmedName.isEmpty { UserDefaults.standard.set(trimmedName, forKey: "userName") }
        let picked = answers.filter { $0.key >= 1 && $0.key <= questions.count }.map { $0.value }
        UserDefaults.standard.set(picked, forKey: "onboardingIntentions")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.3)) { hasCompletedOnboarding = true }
    }

    // MARK: Demo autoplay (-OnboardingDemo) for recording

    private func runDemoIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-OnboardingDemo") else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            go(to: 1)                                   // welcome -> Q1
            for q in 1...questions.count {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                answers[q] = questions[q - 1].options[q % 4].text   // pick an answer
                try? await Task.sleep(nanoseconds: 900_000_000)
                go(to: q + 1)                            // -> next question / name
            }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            go(to: lastStep)                             // name -> reveal
        }
    }
}

// MARK: - Models

private struct Opt: Identifiable { let emoji: String; let text: String; var id: String { text }
    init(_ e: String, _ t: String) { emoji = e; text = t } }
private struct Question { let prompt: String; let options: [Opt] }

// MARK: - Living sky (twinkling field + constellation that grows)

private struct LivingSky: View {
    let stars: Int   // number of bright constellation stars lit

    // Fixed constellation anchor points (normalised), lit progressively.
    private let anchors: [CGPoint] = [
        CGPoint(x: 0.22, y: 0.20), CGPoint(x: 0.44, y: 0.13), CGPoint(x: 0.68, y: 0.22),
        CGPoint(x: 0.80, y: 0.40), CGPoint(x: 0.58, y: 0.30), CGPoint(x: 0.34, y: 0.34)
    ]

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t: Double = tl.date.timeIntervalSinceReferenceDate
                let w: Double = size.width
                let h: Double = size.height

                // Ambient twinkling field
                for i in 0..<70 {
                    let seed: UInt64 = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
                    let x: Double = Double((seed >> 16) % 10000) / 10000.0 * w
                    let y: Double = Double((seed >> 32) % 10000) / 10000.0 * h
                    let r: Double = Double((seed >> 48) % 100) / 100.0 * 1.6 + 0.4
                    let phase: Double = Double((seed >> 8) % 628) / 100.0
                    let twinkle: Double = 0.55 + 0.45 * sin(t * 1.1 + phase)
                    let isGold: Bool = (seed >> 4) % 6 == 0
                    let base: Double = Double((seed >> 12) % 100) / 100.0 * 0.10 + 0.04
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let col: Color = (isGold ? OB.gold : OB.sage).opacity(base * twinkle)
                    ctx.fill(Path(ellipseIn: rect), with: .color(col))
                }

                // Constellation: connect lit anchors with faint lines, glow the stars
                let lit: Int = min(stars, anchors.count)
                if lit >= 2 {
                    var line = Path()
                    for j in 0..<lit {
                        let p = CGPoint(x: Double(anchors[j].x) * w, y: Double(anchors[j].y) * h)
                        if j == 0 { line.move(to: p) } else { line.addLine(to: p) }
                    }
                    ctx.stroke(line, with: .color(OB.sage.opacity(0.28)), lineWidth: 1)
                }
                for j in 0..<lit {
                    let px: Double = Double(anchors[j].x) * w
                    let py: Double = Double(anchors[j].y) * h
                    let pulse: Double = 0.7 + 0.3 * sin(t * 1.6 + Double(j))
                    let halo = CGRect(x: px - 7, y: py - 7, width: 14, height: 14)
                    ctx.fill(Path(ellipseIn: halo), with: .color(OB.gold.opacity(0.16 * pulse)))
                    let core = CGRect(x: px - 2.5, y: py - 2.5, width: 5, height: 5)
                    ctx.fill(Path(ellipseIn: core), with: .color(OB.gold.opacity(0.9)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Progress rail

private struct ProgressRail: View {
    let progress: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(OB.rule)
                Capsule().fill(LinearGradient(colors: [OB.sage, OB.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Intro

private struct IntroStep: View {
    @State private var textIn = false
    var body: some View {
        VStack(spacing: 16) {
            Text("Your inner sky\nis waiting")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(-0.6)
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("A few questions, and your first stars\nappear. Every thought you speak\nbecomes one more.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(OB.inkDim)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .padding(.horizontal, 30)
        .opacity(textIn ? 1 : 0)
        .offset(y: textIn ? 0 : 16)
        .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { textIn = true } }
    }
}

// MARK: - Question

private struct QuestionStep: View {
    let question: Question
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text(question.prompt)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.3)
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.element.id) { idx, opt in
                    AnswerChip(opt: opt, isSelected: selected == opt.text, index: idx) {
                        onSelect(opt.text)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct AnswerChip: View {
    let opt: Opt
    let isSelected: Bool
    let index: Int
    let onTap: () -> Void
    @State private var appear = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(opt.emoji).font(.system(size: 22))
                Text(opt.text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? OB.ink : OB.inkDim)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? OB.forest : OB.rule)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? OB.sage.opacity(0.12) : OB.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? OB.sage : OB.rule, lineWidth: isSelected ? 1.8 : 1))
            .shadow(color: OB.ink.opacity(isSelected ? 0 : 0.03), radius: 5, y: 2)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 14)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) { appear = true }
        }
    }
}

// MARK: - Name

private struct NameStep: View {
    @Binding var userName: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 12) {
            Text("What should your\nsky call you?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Your name", text: $userName)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused(focused)
                .padding(.vertical, 16).padding(.horizontal, 20)
                .background(OB.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focused.wrappedValue ? OB.sage : OB.rule, lineWidth: focused.wrappedValue ? 2 : 1))
                .padding(.top, 22).padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)

            Text("Optional — stored only on your phone.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(OB.inkMute)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Reveal

private struct RevealStep: View {
    let name: String
    let stars: Int
    @State private var pop = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(OB.gold.opacity(0.12)).frame(width: 120, height: 120)
                Circle().fill(OB.gold.opacity(0.22)).frame(width: 82, height: 82)
                Image(systemName: "sparkles").font(.system(size: 34, weight: .semibold)).foregroundColor(OB.gold)
            }
            .scaleEffect(pop ? 1 : 0.6).opacity(pop ? 1 : 0)

            Text(name.isEmpty ? "Your inner sky\nis forming" : "Your sky is forming,\n\(name).")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(OB.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("You've placed your first \(stars) stars. Speak your first entry and watch the constellation grow.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(OB.inkDim)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 28)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { pop = true } }
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
