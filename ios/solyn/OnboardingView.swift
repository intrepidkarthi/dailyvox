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
import CoreData
import WidgetKit
import DailyVoxTwinEngine
import AVFoundation
import Speech

/// What the "speak your first star" moment produces, handed to the container to persist.
struct OnboardingFirstEntry {
    var audioFileName: String?   // nil in demo / no-audio paths
    var duration: Double
    var transcript: String
}

// MARK: - Palette

private enum OB {
    static let paper   = DS.Palette.ivory
    static let paper2  = DS.Palette.tintSage
    static let card    = Color.white
    static let ink     = DS.Palette.navy
    static let inkDim  = DS.Palette.navy.opacity(0.62)
    static let inkMute = DS.Palette.navy.opacity(0.40)
    static let rule    = DS.Palette.navy.opacity(0.10)
    static let gold    = DS.Palette.gold
    static let sage    = DS.Palette.sage
    static let forest  = DS.Palette.forest
}

// MARK: - Container

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.managedObjectContext) private var viewContext

    @State private var screen = 0          // 0 invite, 1 speak, 2 claim
    @State private var starBorn = false
    @State private var transcript = ""
    @State private var firstEntry: OnboardingFirstEntry?

    private var demo: Bool { ProcessInfo.processInfo.arguments.contains("-OnboardingDemo") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [OB.paper, OB.paper2], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            LivingSky(bright: starBorn ? 1 : 0)

            Group {
                switch screen {
                case 0:
                    // B1. It goes FIRST because it is the only claim the user
                    // can check independently, and checking it costs one swipe
                    // down and a tap. Everything after this is easier to believe
                    // once someone has watched the app work in airplane mode.
                    LedgerScreen { advance() }
                case 1:
                    InviteScreen(demo: demo) { advance() }
                case 2:
                    SpeakScreen(demo: demo) { entry in
                        firstEntry = entry
                        transcript = entry.transcript
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
        persistFirstStar()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.4)) { hasCompletedOnboarding = true }
    }

    /// Save the onboarding recording as the user's real first DiaryEntry, so "that
    /// star is yours" is true — they enter the app to a sky that already holds their
    /// star, not an empty one, and TodayView won't re-fire a duplicate first-star moment.
    private func persistFirstStar() {
        guard let entry = firstEntry else { return }
        let text = entry.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.audioFileName != nil || !text.isEmpty else { return }
        let now = Date()
        let e = DiaryEntry(context: viewContext)
        e.id = UUID()
        e.date = now
        e.createdAt = now
        e.updatedAt = now
        e.text = text
        e.isStarred = false
        if let fileName = entry.audioFileName {
            e.setValue(AudioFileList.encode([fileName]), forKey: "audioFileNames")
            e.setValue(fileName, forKey: "audioFileName")
            e.setValue(entry.duration, forKey: "duration")
        }
        do {
            try viewContext.save()
            UserDefaults.standard.set(true, forKey: "hasCompletedFirstEntry")
            DigitalTwinEngine.shared.processEntry(text: text, mood: nil, date: now, duration: entry.duration, entryId: e.id?.uuidString)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Non-fatal: onboarding still completes; worst case the star isn't pre-seeded.
        }
    }
}

// MARK: - Beat 1: Invite

/// B1 — the permission ledger and the airplane-mode proof.
///
/// The original iOS onboarding opened with "Your sky starts with your voice",
/// which is the promise. This is the evidence, and the design package is blunt
/// about which one was missing: the airplane-mode proof is called "the site's
/// strongest argument, currently absent from the app" (§8.1 of the brief).
///
/// The row that carries the whole thing is INTERNET · NOT REQUESTED. Android can
/// say it structurally — the app holds no INTERNET permission at all — and iOS
/// cannot make that exact claim while CloudKit is linked for optional sync, so
/// the wording here is what is true on this platform: nothing is sent to
/// DailyVox, because there is no DailyVox server. Overclaiming on the one screen
/// whose job is to be checkable would be the worst possible place to do it.
private struct LedgerScreen: View {
    let onNext: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 40)

            Text("01 / 04 \u{00B7} PERMISSION")
                .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(OB.inkMute)

            Spacer().frame(height: 16)

            Text("Nothing you say\nleaves this phone.")
                .font(.dv(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(OB.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 14)

            Text("Your voice is transcribed by this iPhone. No account, no analytics, and no DailyVox server — there isn't one to send anything to.")
                .font(.dv(size: 15))
                .lineSpacing(4)
                .foregroundColor(OB.inkDim)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 26)

            VStack(spacing: 8) {
                LedgerRow(label: "Microphone", state: "REQUIRED", dot: OB.gold)
                LedgerRow(label: "Speech recognition", state: "ON DEVICE", dot: OB.sage)
                LedgerRow(label: "Apple Health", state: "OPTIONAL", dot: OB.inkMute)
                LedgerRow(label: "Sent to DailyVox", state: "NOTHING, EVER", dot: OB.sage)
            }

            Spacer().frame(height: 20)

            // The proof card. Navy on cream, per B1 — it is the one dark object
            // on the screen because it is the one thing being pointed at.
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle().fill(OB.gold.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: "airplane")
                        .font(.dv(size: 15, weight: .bold))
                        .foregroundColor(OB.gold)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Try it in airplane mode")
                        .font(.dv(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Palette.navyText)
                    Text("Turn the radios off before you speak your first entry. Everything still works — the transcript, the mood, the star. That is the whole product, demonstrated in ten seconds.")
                        .font(.dv(size: 13))
                        .lineSpacing(3)
                        .foregroundColor(DS.Palette.navyText.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Palette.navy))

            Spacer(minLength: 28)

            // One green CTA. B1 has exactly one thing to do.
            PrimaryButton(title: "Speak your first star", filled: true, action: onNext)

            Spacer().frame(height: 22)
        }
        .padding(.horizontal, 26)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }
}

private struct LedgerRow: View {
    let label: String
    let state: String
    let dot: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(label)
                .font(.dv(size: 15))
                .foregroundColor(OB.ink)
            Spacer(minLength: 8)
            Text(state)
                .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.1)
                .foregroundColor(OB.inkDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.card))
    }
}

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
                    .font(.dv(size: 34, weight: .semibold))
                    .foregroundColor(OB.gold)
            }
            .scaleEffect(appear ? 1 : 0.7)

            VStack(spacing: 14) {
                Text("Your sky starts\nwith your voice")
                    .font(.dv(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No forms, no sign-up. Just talk about\nyour day — and watch your voice become\nthe first star in a sky only you can see.")
                    .font(.dv(.callout, design: .rounded, weight: .regular))
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

            PrimaryButton(title: "I'm ready", filled: true) {
                // Pre-frame the mic + speech prompts here, on the calm invite screen,
                // so they don't interrupt the recording moment itself.
                #if os(iOS)
                AVAudioApplication.requestRecordPermission { _ in
                    SFSpeechRecognizer.requestAuthorization { _ in
                        DispatchQueue.main.async { onBegin() }
                    }
                }
                #else
                onBegin()
                #endif
            }
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
    let onBorn: (OnboardingFirstEntry) -> Void

    @StateObject private var recorder = AudioRecorder()
    @State private var phase: Phase = .idle
    @State private var level: CGFloat = 0
    @State private var elapsed: Double = 0
    @State private var transcript = ""
    @State private var flare: CGFloat = 0
    @State private var capturedFile: String?
    @State private var capturedDuration: Double = 0
    @State private var typing = false
    @State private var typedText = ""

    enum Phase { case idle, recording, processing, born }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text(headline)
                    .font(.dv(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subhead)
                    .font(.dv(.subheadline, design: .rounded, weight: .regular))
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

                VoiceStar(level: level, active: phase == .recording, born: flare)
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
            // 42s is a soft target, not a cut-off — let people finish their sentence.
            elapsed = t
        }
        .onAppear(perform: autoDemo)
        .sheet(isPresented: $typing) {
            TypeFirstEntryView(text: $typedText, onSave: finishTyped, onCancel: { typing = false })
        }
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
                        Image(systemName: "mic.fill").font(.dv(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                Text("Tap to speak").font(.dv(.footnote, design: .rounded, weight: .medium))
                    .foregroundColor(OB.inkMute)
                Button("I can't talk right now") { typing = true }
                    .font(.dv(.footnote, design: .rounded, weight: .medium))
                    .foregroundColor(OB.sage)
                    .padding(.top, 2)
            }
        case .recording:
            Button(action: finish) {
                HStack(spacing: 8) {
                    Circle().fill(OB.forest).frame(width: 8, height: 8)
                    Text("Done · \(Int(elapsed))s")
                        .font(.dv(.callout, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 15).padding(.horizontal, 34)
                .background(Capsule().fill(OB.ink))
            }
        case .processing:
            HStack(spacing: 10) {
                ProgressView().tint(OB.sage)
                Text("finding your words…").font(.dv(.subheadline, design: .rounded))
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
        guard let res = recorder.stopRecording() else { born(); return }
        capturedFile = res.url.lastPathComponent
        capturedDuration = res.duration
        SpeechTranscriber.shared.transcribe(from: res.url) { result in
            DispatchQueue.main.async {
                if case .success(let t) = result { transcript = t }
                born()
            }
        }
    }

    private func born() {
        withAnimation(.easeInOut(duration: 0.25)) { phase = .born }
        // Springy overshoot = the waveform collapses and the star pops into being.
        withAnimation(.spring(response: 0.7, dampingFraction: 0.52).delay(0.05)) { flare = 1 }
        let payload = OnboardingFirstEntry(audioFileName: capturedFile,
                                           duration: capturedDuration,
                                           transcript: transcript)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { onBorn(payload) }
    }

    private func finishTyped() {
        let t = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        transcript = t
        capturedFile = nil
        capturedDuration = 0
        typing = false
        // Let the sheet dismiss, then ignite the star from the typed words.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { born() }
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

// MARK: - Type instead (escape hatch for "I can't talk right now")

private struct TypeFirstEntryView: View {
    @Binding var text: String
    var onSave: () -> Void
    var onCancel: () -> Void
    @FocusState private var focused: Bool

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel).foregroundColor(OB.inkMute)
                Spacer()
                Text("Your first star")
                    .font(.dv(.subheadline, design: .rounded, weight: .semibold)).foregroundColor(OB.ink)
                Spacer()
                Button("Save", action: onSave)
                    .fontWeight(.semibold)
                    .foregroundColor(isEmpty ? OB.inkMute : OB.sage)
                    .disabled(isEmpty)
            }
            .font(.dv(.subheadline, design: .rounded))
            .padding()

            Text("How was your day, really?")
                .font(.dv(.title2, design: .rounded, weight: .bold))
                .foregroundColor(OB.ink)
                .padding(.top, 4)

            TextEditor(text: $text)
                .font(.dv(.body, design: .rounded))
                .foregroundColor(OB.ink)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(OB.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OB.rule, lineWidth: 1))
                .frame(height: 200)
                .padding()
                .focused($focused)

            Text("Stored only on your phone.")
                .font(.dv(.caption, design: .rounded)).foregroundColor(OB.inkMute)

            Spacer()
        }
        .background(OB.paper.ignoresSafeArea())
        .onAppear { focused = true }
    }
}

// MARK: - Voice star (waveform that collapses & coalesces into a star)

private struct VoiceStar: View {
    let level: CGFloat
    let active: Bool
    let born: CGFloat   // 0 = live waveform, 1 = ignited star
    private let bars = 40

    var body: some View {
        SwiftUI.TimelineView(.animation) { tl in
            let t: Double = tl.date.timeIntervalSinceReferenceDate
            let b: Double = Double(born)
            ZStack {
                // Ignition shockwave — expands and fades as the star is born
                Circle()
                    .fill(OB.gold.opacity(0.35 * (1 - b)))
                    .frame(width: 60, height: 60)
                    .scaleEffect(0.4 + born * 3.4)
                    .opacity(b > 0.001 ? 1 : 0)

                // Soft recording disc (dissolves into the star)
                Circle()
                    .fill(OB.card)
                    .frame(width: 96, height: 96)
                    .shadow(color: OB.ink.opacity(0.05 * (1 - b)), radius: 8, y: 3)
                    .opacity(1 - b)
                    .scaleEffect(1 - born * 0.45)

                // Collapsing waveform bars
                ForEach(0..<bars, id: \.self) { i in
                    bar(i: i, t: t)
                }

                // Flare rays (extend as it ignites)
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(OB.gold.opacity(0.55 * b))
                        .frame(width: 2.4, height: 66)
                        .offset(y: -44)
                        .scaleEffect(x: 1, y: born, anchor: .bottom)
                        .rotationEffect(.degrees(Double(i) / 8.0 * 360.0))
                }

                // Star core (glows into being; also the live recording pulse)
                Circle()
                    .fill(OB.gold)
                    .frame(width: 16, height: 16)
                    .scaleEffect(1 + (active ? level * 0.7 : 0) + born * 0.9)
                    .shadow(color: OB.gold.opacity(0.7 * b), radius: 18 * born)
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .scaleEffect(0.6 + born * 1.1 + (active ? level * 0.4 : 0))
            }
        }
    }

    private func bar(i: Int, t: Double) -> some View {
        let angle: Double = Double(i) / Double(bars) * 360.0
        let wobble: Double = 0.5 + 0.5 * sin(t * 3.0 + Double(i) * 0.7)
        let amp: CGFloat = active ? level * CGFloat(wobble) : 0.04
        let baseH: CGFloat = 10 + amp * 64
        let h: CGFloat = max(0.5, baseH * (1 - born))     // shrink as they collapse
        let outward: CGFloat = 70 * (1 - born)            // pull inward on birth
        let op: Double = (active ? 0.9 : 0.35) * Double(1 - born)
        return Capsule()
            .fill(LinearGradient(colors: [OB.gold, OB.sage], startPoint: .top, endPoint: .bottom))
            .frame(width: 3.2, height: h)
            .offset(y: -outward)
            .rotationEffect(.degrees(angle))
            .opacity(op)
    }
}

// MARK: - Beat 3: Claim

private struct ClaimScreen: View {
    let transcript: String
    let onEnter: () -> Void
    @State private var appear = false
    /// Pre-checked: the daily nudge is the whole habit loop for a once-a-day app, and until now
    /// it was off by default and only reachable from Settings. The user can uncheck it here
    /// before entering, and change it any time in Settings.
    @State private var remindDaily = true

    private var words: String {
        let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "your first words" : t
    }

    private var reminderTimeText: String {
        var c = DateComponents()
        c.hour = ReminderManager.shared.reminderHour
        c.minute = ReminderManager.shared.reminderMinute
        guard let date = Calendar.current.date(from: c) else { return "in the evening" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// Ask for notification permission only once the user has actually made something —
    /// a soft ask at the moment of peak intent converts far better than a cold prompt on launch.
    private func applyReminderChoice() {
        guard remindDaily else { return }
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }
        ReminderManager.shared.requestPermissionIfNeeded { granted in
            if granted { ReminderManager.shared.isEnabled = true }
        }
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
                    .font(.dv(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(OB.ink)
                    .multilineTextAlignment(.center)

                Text("“\(words)”")
                    .font(.dv(.callout, design: .rounded, weight: .medium))
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
                    .font(.dv(.subheadline, design: .rounded, weight: .regular))
                    .foregroundColor(OB.inkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            Spacer()

            Button {
                remindDaily.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: remindDaily ? "checkmark.circle.fill" : "circle")
                        .font(.dv(.title2))
                        .foregroundColor(remindDaily ? OB.sage : OB.inkDim.opacity(0.45))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me each evening")
                            .font(.dv(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(OB.ink)
                        Text("One nudge at \(reminderTimeText). Change it any time in Settings.")
                            .font(.dv(.footnote, design: .rounded, weight: .regular))
                            .foregroundColor(OB.inkDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.card))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OB.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remind me each evening at \(reminderTimeText)")
            .accessibilityAddTraits(remindDaily ? [.isSelected] : [])
            .padding(.horizontal, 28)
            .padding(.bottom, 14)
            .opacity(appear ? 1 : 0)

            PrimaryButton(title: "Enter my sky", filled: true) {
                applyReminderChoice()
                onEnter()
            }
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
                .font(.dv(.body, design: .rounded, weight: .semibold))
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

                // The sky gains your star once it's born
                if bright > 0 {
                    let hx: Double = w * 0.5
                    let hy: Double = h * 0.26
                    let pulse: Double = 0.7 + 0.3 * sin(t * 1.6)
                    let halo = CGRect(x: hx - 10, y: hy - 10, width: 20, height: 20)
                    ctx.fill(Path(ellipseIn: halo), with: .color(OB.gold.opacity(0.20 * pulse)))
                    let core = CGRect(x: hx - 3, y: hy - 3, width: 6, height: 6)
                    ctx.fill(Path(ellipseIn: core), with: .color(OB.gold.opacity(0.95)))
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
                .font(compact ? .dv(.caption) : .dv(.subheadline))
                .foregroundColor(DS.Palette.forest)
            if !compact {
                Text("100% Private").font(.dv(.caption, weight: .medium)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 4 : 6)
        .background(DS.Palette.forest.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct OfflineIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(DS.Palette.forest).frame(width: 6, height: 6)
            Text("Offline").font(.dv(.caption2, weight: .medium)).foregroundColor(.secondary)
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
