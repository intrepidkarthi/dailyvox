//
//  TodayView.swift
//  solyn
//
//  Main recording interface for creating voice diary entries.
//  Handles audio recording, transcription, and entry creation.
//

import SwiftUI
import DailyVoxTwinEngine
import CoreData
import AVFoundation
import UIKit
import PhotosUI
import os.log
import WidgetKit

private let logger = Logger(subsystem: "com.dailyvox.app", category: "TodayView")

// MARK: - Recording State

/// Represents the current state of the recording process
enum RecordingState {
    case idle       // Ready to record
    case recording  // Currently recording audio
    case processing // Transcribing audio to text
}

// MARK: - Today View

/// Main view for recording and viewing today's diary entry.
/// Provides voice recording with real-time audio level visualization.

/// Everything the record screen has to hear from outside itself.
///
/// Bundled into one modifier because four chained observers on top of an already
/// long chain tipped `body` past the type-checker's budget — the failure that
/// reports as "unable to type-check this expression in reasonable time" and
/// names a line that is not the problem.
///
/// The sources are the Dynamic Island's two buttons, the audio session's
/// interruptions, and the tab bar, which needs to get out of the way.
private struct RecordingSignals: ViewModifier {
    let isRecording: Bool
    let onFinish: () -> Void
    let onDiscard: () -> Void
    let onInterrupted: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            // The floating tab bar hides while the dial is up. It already
            // listens for this; nothing was posting it from the iOS record path.
            .onChange(of: isRecording) { _, recording in
                NotificationCenter.default.post(name: .dailyVoxRecordingChanged,
                                                object: recording)
            }
            // §E state ③'s Finish and Discard. The intents run in this process
            // while the app is backgrounded, so they are the same two actions as
            // the dial's, reached without unlocking.
            .onReceive(NotificationCenter.default.publisher(for: .dailyVoxFinishRecording)) { _ in
                guard isRecording else { return }
                onFinish()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailyVoxDiscardRecording)) { _ in
                guard isRecording else { return }
                onDiscard()
            }
            // A call or an alarm paused us. Show it as paused rather than
            // leaving a dial that looks live over a microphone the system has
            // taken away.
            .onReceive(NotificationCenter.default.publisher(for: .dailyVoxRecordingInterrupted)) { note in
                onInterrupted((note.object as? Bool) ?? false)
            }
    }
}

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var recorder = AudioRecorder()
    /// Screenshot mode only: the dial is the app's signature surface and there
    /// is no microphone in a simulator, so the store frame cannot be captured
    /// by recording. This shows the dial without arming the recorder.
    @State private var recordingState: RecordingState =
        ScreenshotScene.current == .recording ? .recording : .idle
    @State private var showSettings = ScreenshotScene.current == .settings
    @ObservedObject private var theme = ThemeManager.shared
    @State private var errorMessage: String?
    @State private var selectedPrompt: EntryPrompt? = nil
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var processingPhase: Int = 0
    @State private var processingTimer: Timer?
    @State private var pulseScale: CGFloat = 1.0
    @State private var showFirstEntryMoment: Bool = false
    @State private var firstTimePulse: Bool = false
    @State private var recordingRingPulse: Bool = false
    /// B2b. True between Pause and Resume — the recording is open but not
    /// listening, which is a third state the screen never had.
    @State private var isPaused = false

    // Research pilot: optional post-recording self-label picker (Settings → Research).
    @AppStorage("pilotLabelingEnabled") private var pilotLabelingEnabled = false
    @State private var labelTarget: DiaryEntry?

    @FetchRequest private var todayEntries: FetchedResults<DiaryEntry>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: true)],
        animation: .default)
    private var allEntries: FetchedResults<DiaryEntry>

    private var isIPad: Bool { horizontalSizeClass == .regular }

    init() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        _todayEntries = FetchRequest<DiaryEntry>(
            sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }

    private var latestEntry: DiaryEntry? {
        todayEntries.first
    }

    /// B2b: recording gets the whole screen. Handing off entirely rather than
    /// morphing the idle layout around it — the same decision the Android build
    /// made, and for the same reason.
    ///
    /// Extracted from `body` because inline it tipped the type-checker over
    /// ("unable to type-check this expression in reasonable time"), which is a
    /// failure that does not announce itself until some unrelated edit adds the
    /// last straw.
    private var recordingDial: some View {
        RecordingDialView(
            elapsed: Int(recorder.currentTime),
            level: CGFloat(recorder.level),
            paused: isPaused,
            live: recorder.live,
            onStop: {
                isPaused = false
                stopRecording()
            },
            onDiscard: {
                HapticManager.shared.recordingStopped()
                recorder.discardRecording()
                isPaused = false
                recordingState = .idle
            },
            onPause: {
                recorder.pauseRecording()
                isPaused = true
            },
            onResume: {
                recorder.resumeRecording()
                isPaused = false
            }
        )
        .transition(.opacity)
    }

    var body: some View {
        ZStack {
            WarmBackground()

            if recordingState == .recording {
                recordingDial
            } else if allEntries.isEmpty && recordingState == .idle && latestEntry == nil {
                // FIRST-TIME FOCUSED EXPERIENCE
                firstTimeView
            } else {
                // NORMAL VIEW (existing)
                normalView
            }
        }
        // No system navigation bar. Every destination draws its own header, so
        // the bar was reserving a full band of empty space above content that
        // already had a title — the gap Karthik flagged between the status bar
        // and "Good afternoon". Settings moves into the greeting row instead.
        .toolbar(.hidden, for: .navigationBar)
        // NOT while the dial is up. The scrim paints the APP's ground behind the
        // status bar, and the dial is navy under both themes — so in daylight it
        // laid a cream gradient across the top of a night screen. The dial
        // reaches the status bar itself and needs no help.
        .dailyVoxStatusBarScrim(enabled: recordingState != .recording)
        .modifier(RecordingSignals(
            isRecording: recordingState == .recording,
            onFinish: {
                isPaused = false
                stopRecording()
            },
            onDiscard: {
                HapticManager.shared.recordingStopped()
                recorder.discardRecording()
                isPaused = false
                recordingState = .idle
            },
            onInterrupted: { paused in isPaused = paused }
        ))
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        // "Saved" fallbacks (offline / failed transcription) aren't errors —
        // don't greet a successfully kept recording with "Recording Error".
        .alert(errorMessage?.contains("saved") == true ? "Recording Saved" : "Recording Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if showFirstEntryMoment {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showFirstEntryMoment = false
                            }
                        }

                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.dv(size: 56))
                            .foregroundColor(DS.Palette.gold)

                        Text("Your first star")
                            .font(.dv(.title2, design: .rounded, weight: .bold))

                        Text("Your constellation has begun. Every entry adds a new star to your inner sky.")
                            .font(.dv(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showFirstEntryMoment = false
                            }
                        } label: {
                            Text("Continue")
                                .font(.dv(.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .transition(.scale.combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.spring(response: 0.3)) {
                            showFirstEntryMoment = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4), value: showFirstEntryMoment)
        .overlay {
            if let target = labelTarget, !showFirstEntryMoment {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { labelTarget = nil }
                        }

                    SelfLabelPickerCard(entry: target) {
                        withAnimation(.spring(response: 0.3)) { labelTarget = nil }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4), value: labelTarget != nil)
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromSiri)) { _ in
            // Auto-start recording when triggered from Siri shortcut
            if recordingState == .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    toggleRecording()
                }
            }
        }
    }

    // MARK: - First-Time Focused Experience

    private var firstTimeView: some View {
        VStack(spacing: 0) {
            // Settings had NO route on this screen. It is reached only from the
            // ellipsis in `headerSection`, which the first-run branch does not
            // draw — so the one population most likely to need it (someone who
            // just declined the microphone prompt and wants to know why nothing
            // happens) could not reach permissions, reminders or the Data
            // Shield until they had successfully recorded.
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.dv(size: 16, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.gold.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(DS.Palette.gold.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkle")
                        .font(.dv(.title3, weight: .semibold))
                        .foregroundColor(DS.Palette.gold)
                }

                VStack(spacing: 12) {
                    Text("What\u{2019}s on your mind?")
                        .font(.dv(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)

                    Text("Tap the mic and speak for 42 seconds \u{2014} or longer.\nYour first star will appear.")
                        .font(.dv(.subheadline, design: .rounded, weight: .regular))
                        .foregroundColor(theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // The mic sits LOW, in thumb reach, like the one on the normal view.
            VStack(spacing: 18) {
                Button {
                    toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(DS.Palette.sage.opacity(0.2), lineWidth: 2)
                            .frame(width: 108, height: 108)
                            .scaleEffect(firstTimePulse ? 1.3 : 1.0)
                            .opacity(firstTimePulse ? 0 : 0.5)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: firstTimePulse)

                        Circle()
                            .fill(DS.Palette.sage.opacity(0.08))
                            .frame(width: 120, height: 120)
                            .blur(radius: 15)

                        Circle()
                            .stroke(DS.Palette.sage.opacity(0.3), lineWidth: 4)
                            .frame(width: 96, height: 96)

                        Circle()
                            .fill(DS.Palette.sage)
                            .frame(width: 80, height: 80)

                        Image(systemName: "mic.fill")
                            .font(.dv(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Record an entry")
                .onAppear { firstTimePulse = true }

                // ONE claim, not two. This screen used to say "Your voice stays
                // on this device" and, directly beneath it, "No servers. No
                // accounts. 100% private." — the same promise twice, stacked,
                // which reads as protesting rather than stating. The mono
                // register matches the caption under the mic on the normal view.
                Text("TRANSCRIBED ON THIS PHONE")
                    .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(theme.secondaryTextColor)
            }

            Color.clear.frame(height: DailyVoxTabBar.reservedHeight)
        }
    }

    // MARK: - Normal View

    /// Header and today's content scroll; the mic is DOCKED at the bottom.
    ///
    /// The spec's B2 frame draws the mic mid-screen with the Today card beneath
    /// it, and that is how this was built first. On a real phone it is the
    /// wrong call: the one control you press every day sat under your index
    /// finger instead of your thumb, and it moved down the screen as the
    /// journal grew. Karthik asked for it back at the bottom and he is right —
    /// reachability beats frame fidelity for the primary action.
    ///
    /// Docking it is what put it behind the floating tab bar the first time.
    /// The fix is the bar's own reserved height, so the two stack instead of
    /// competing for the same strip.
    private var normalView: some View {
        // Header at the top, the mic PINNED at the bottom, the day's star in the
        // scrollable middle.
        //
        // It used to be one scroll with the question-and-mic as a centred object
        // in the middle of it. That composition reads well on a canvas and badly
        // in a hand: the primary — and on most days only — action of the whole
        // app sat around 45% of the way up a 6.7" screen, which is outside the
        // arc a thumb reaches on the phone it is holding. Karthik flagged it.
        // The question stays married to the button, so the pair moves down
        // together and the greeting keeps the top.
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal)
                .padding(.top)

            // Today's card sits directly under the header, where a device
            // actually puts it. Centring it in the band — which is what this
            // did — opened a gap ABOVE the card that exists nowhere in the
            // running app, and made the first thing you wrote today look like
            // it was floating. The slack belongs below it, between what you
            // have said and the button for saying more.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // NO leading Spacer. A Spacer expands, so a pair of them
                        // — even with minLength 16 and 0 — splits the slack
                        // evenly and re-centres the card, which is the gap this
                        // was meant to remove. Only the trailing one remains.
                        if recordingState == .idle {
                        // Today's star, once it exists. The canvas surfaces it
                        // here rather than making you open the Journal for it.
                        //
                        // BodyTwinIdleCards is NOT here any more. It added a
                        // third card under the mic ("7,002 steps already — your
                        // day is in motion") on a screen the design gives two.
                        // Body context already appears where it means
                        // something: the BODY row of an entry's ledger, and the
                        // Body card on the Twin tab.
                            entryCardSection
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: isIPad ? 700 : .infinity)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }

            questionAndMic
                .padding(.horizontal)
                .frame(maxWidth: isIPad ? 700 : .infinity)
                .frame(maxWidth: .infinity)

            // Clears the floating bar. Docked content, so the bar's own height
            // plus breathing room rather than the full scroll reservation.
            Color.clear.frame(height: DailyVoxTabBar.reservedHeight - 10)
        }
        .task { await BodyWhisperProvider.shared.refreshIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await BodyWhisperProvider.shared.refreshIfNeeded() }
        }
    }

    // MARK: - Header Section

    /// Spec §2.2: greeting + date on the left, streak and star chips on the
    /// right, then "How was your day, really?" as the headline.
    ///
    /// This was a big date with a privacy badge beside it and the stats on
    /// their own row below — three stacked bands before the screen said
    /// anything. The date is demoted to a subtitle because you know what day it
    /// is; the question is the only thing on this screen that needs answering.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    // Green by day, gold by night — the canvas colours the
                    // greeting and leaves the date quiet. It is the one warm
                    // word on the screen before you speak.
                    Text(greeting)
                        .font(.dv(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(theme.isNight ? theme.goldText : theme.accentColor)
                    Text(formattedToday)
                        .font(.dv(size: 12.5))
                        .foregroundColor(theme.secondaryTextColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(streakCount > 0 ? "\(streakCount)-day streak" : "no streak yet")
                        .font(.dv(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                    // GOLD REWARDS: the year count is a made thing, so it is
                    // the one figure up here allowed to be gold.
                    Text("\u{2726} \(daysRecordedThisYear) this year")
                        .font(.dv(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.goldText)
                }
                Button { showSettings = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.dv(size: 16, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor)
                        // 34pt against a 44pt floor, on the app's only route to
                        // Settings.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
                .padding(.leading, 2)
            }

        }
    }

    /// B2/C1: the question sits CENTRED, directly above the mic, as one object.
    ///
    /// It used to be left-aligned at the top of the header, which made it a page
    /// title — the screen then read as heading, cards, and a control somewhere
    /// below. In the canvas the question and the mic are a single centred unit
    /// with air above and below, so the thing being asked and the thing you
    /// answer it with are one gesture apart.
    private var questionAndMic: some View {
        VStack(spacing: 26) {
            Text("How was your day,\nreally?")
                .font(.dv(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            recordButton

            // "TAP TO RECORD · 42 SECONDS" — DM Mono, uppercase, tracked. The
            // canvas gives this line the data register, not body copy: it is a
            // caption on an instrument. It replaces two stacked sentences that
            // said the same thing twice.
            Text(micCaption)
                .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(theme.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var micCaption: String {
        switch recordingState {
        case .idle: return "TAP TO RECORD \u{00B7} 42 SECONDS"
        case .recording: return "TAP TO STOP"
        case .processing: return "FINDING YOUR WORDS\u{2026}"
        }
    }

    /// The canvas's own line, and it changes with the ground: by day it states
    /// the fact, by night it dares you to check it.
    private var privacyLine: String {
        theme.isNight
            ? "Airplane mode on? Works exactly the same."
            : "Transcribed on this phone \u{00B7} 0 network calls, ever"
    }

    /// Kept, and deliberately not composed on the idle screen.
    ///
    /// It is static text making a claim you have already read, on the screen you
    /// open most — and the claim is redundant exactly where it matters, because
    /// the recording dial says "RECORDING · ON-DEVICE · 0 B OUT" while you are
    /// speaking. Reassurance belongs at the moment of risk. The onboarding
    /// ledger, the Data Shield in Settings and the shareable receipt all still
    /// make the argument to anyone who wants it.
    private var privacyCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(theme.successColor)
                .frame(width: 9, height: 9)
            Text(privacyLine)
                .font(.dv(size: 12.5))
                .foregroundColor(theme.textColor.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackgroundColor)
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<21: timeGreeting = "Good evening"
        default: timeGreeting = "Good night"
        }

        // First-time warmth
        if allEntries.isEmpty {
            return "Welcome to your sky"
        }
        return timeGreeting
    }

    // MARK: - Prompts Section

    /// Every third day, pilot participants see a plain "log your day" prompt
    /// first — the neutral-rich slice the affect research needs (R1 §10
    /// item 5); the default prompts all pull toward an emotional register.
    /// Day-of-year cadence keeps it deterministic and testable.
    private var orderedPrompts: [EntryPrompt] {
        guard pilotLabelingEnabled,
              let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()),
              day % 3 == 0
        else { return EntryPrompt.defaultPrompts }
        let neutral = EntryPrompt.neutralPrompts[(day / 3) % EntryPrompt.neutralPrompts.count]
        return [neutral] + EntryPrompt.defaultPrompts
    }

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("A starting thought")
                    .font(.dv(.subheadline, weight: .semibold))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orderedPrompts) { prompt in
                        PromptChip(
                            prompt: prompt,
                            isSelected: prompt == selectedPrompt
                        ) {
                            if selectedPrompt == prompt {
                                selectedPrompt = nil
                            } else {
                                selectedPrompt = prompt
                                HapticManager.shared.selectionChanged()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Entry Card Section

    private var entryCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = latestEntry {
                // We have an entry for today
                NavigationLink {
                    EntryDetailView(entry: entry)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        // B2's Today card is ONE compact row: when, how long, one
                        // line of what you said. It was rendering the entry in
                        // full — an unbounded transcript with a titled header row
                        // and a footer of three stats — so the card grew with
                        // whatever you happened to say and pushed everything
                        // below it off the screen. The whole entry is one tap
                        // away; this is a receipt, not a copy.
                        if let text = entry.text, !text.isEmpty {
                            HStack(spacing: 8) {
                                Text(todayMetaLine(for: entry))
                                    .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundColor(theme.secondaryTextColor)
                                Spacer(minLength: 0)
                                if let duration = entry.value(forKey: "duration") as? Double, duration > 0 {
                                    Text("\u{25B6} " + formatDuration(duration))
                                        .font(.dv(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundColor(theme.accentColor)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(theme.warmSubtleFill))
                                }
                            }

                            // Four lines. One truncated line was a receipt for
                            // something you already knew you'd done; four is
                            // enough to re-read the thought and decide whether
                            // to open it.
                            Text(text)
                                .font(.dv(size: 13.5))
                                .lineSpacing(3)
                                .foregroundColor(theme.textColor.opacity(0.88))
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                        } else {
                            // Entry exists but no text yet
                            VStack(alignment: .leading, spacing: 8) {
                                if recordingState == .processing {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Understanding your words...")
                                            .font(.dv(.subheadline))
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    // Recording saved but no transcription (offline or failed)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Recording saved")
                                            .font(.dv(.subheadline))
                                            .foregroundColor(.primary)
                                        Text("Tap to add text or play your recording")
                                            .font(.dv(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .dsShadowSoft()
                }
                .buttonStyle(.plain)
            } else {
                // No entry yet - show welcome card for first-time users
                if allEntries.isEmpty {
                    VStack(spacing: 16) {
                        WelcomeCard()

                        // First-time guided hint
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down")
                                .font(.dv(.subheadline, weight: .semibold))
                                .foregroundColor(DS.Palette.gold)
                            Text("Tap the mic below to plant your first star")
                                .font(.dv(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(DS.Palette.gold.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                // No "Add a star to today's sky" card when today is empty.
                //
                // It drew an 80pt circle with a mic glyph and read as a record
                // button — the first microphone on the screen, forty points
                // above the real one, and not tappable. On the one screen whose
                // job is to get someone talking in a few seconds, that is the
                // worst possible thing to put first. The canvas has no such
                // card: an empty day is a day with no star card yet.
            }
        }
    }

    // MARK: - Processing Phase Message

    private var processingPhaseMessage: String {
        switch processingPhase {
        case 0: return "Listening to your words..."
        case 1: return "Understanding your thoughts..."
        case 2: return "A new star is forming..."
        default: return "Listening to your words..."
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 16) {
            // Processing indicator with phased warm messages
            if recordingState == .processing {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    Text(processingPhaseMessage)
                        .font(.dv(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: processingPhase)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    pulseScale = 1.4
                    processingPhase = 0
                    processingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                        DispatchQueue.main.async {
                            withAnimation {
                                processingPhase = (processingPhase + 1) % 3
                            }
                        }
                    }
                }
                .onDisappear {
                    processingTimer?.invalidate()
                    processingTimer = nil
                    pulseScale = 1.0
                }
            }

            // Audio level meter (when recording)
            if recordingState == .recording {
                VStack(spacing: 12) {
                    // Recording time
                    Text(formatTime(recorder.currentTime))
                        .font(.dv(size: 42, weight: .light, design: .rounded))
                        .foregroundColor(ThemeManager.shared.recordingColor)

                    // Waveform-style level indicator
                    HStack(spacing: isIPad ? 5 : 3) {
                        ForEach(0..<(isIPad ? 30 : 20), id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: i))
                                .frame(width: isIPad ? 6 : 4, height: barHeight(for: i))
                        }
                    }
                    .frame(height: isIPad ? 40 : 30)

                    Text("Speaking... tap when you're done")
                        .font(.dv(.footnote, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Record button stays dead-centre; photo-add was a secondary side
            // action beside it (it used to share the row and push the mic
            // off-centre to the right). Withheld behind FeatureFlags — this is
            // a voice journal, and a picker did not earn space on the one
            // screen whose job is to get you talking in a few seconds.
            ZStack {
                recordButton

                if FeatureFlags.photoAttachments && recordingState == .idle {
                    HStack {
                        Spacer()
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            ZStack {
                                Circle()
                                    .fill(ThemeManager.shared.warmSubtleFill)
                                    .frame(width: isIPad ? 52 : 44, height: isIPad ? 52 : 44)
                                Image(systemName: "photo.badge.plus")
                                    .font(.dv(size: isIPad ? 20 : 17))
                                    .foregroundColor(DS.Palette.inkMute)
                            }
                        }
                        .buttonStyle(SpringPressStyle())
                        .onChange(of: selectedPhotos) { _, newItems in
                            handlePhotoPickerSelection(newItems)
                        }
                        .padding(.trailing, DS.Space.xl)
                        .accessibilityLabel("Add photos")
                    }
                }
            }

            // Status text (only when idle)
            if recordingState == .idle {
                VStack(spacing: 6) {
                    Text(statusText)
                        .font(.dv(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Your voice stays on this device")
                        .font(.dv(.caption, weight: .medium))
                        .foregroundColor(.secondary)

                    if let prompt = selectedPrompt {
                        Text(prompt.detail)
                            .font(.dv(.caption))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4), value: recordingState)
    }

    /// Enough height that the centred unit sits in air on a tall phone and the
    /// screen still scrolls on a short one, rather than the mic being pinned to
    /// the bottom of a squeezed scroll view.
    private var minCanvasHeight: CGFloat { isIPad ? 760 : 560 }

    /// "TODAY ✦ · 8:43 AM" — the canvas's own meta line for this card.
    private func todayMetaLine(for entry: DiaryEntry) -> String {
        let when = entry.updatedAt ?? entry.date ?? Date()
        return "TODAY \u{2726} \u{00B7} " + formattedTime(when).uppercased()
    }

    private var recordButtonSize: CGFloat { isIPad ? 88 : 72 }
    private var recordButtonOuterSize: CGFloat { isIPad ? 108 : 88 }

    private var recordButton: some View {
        Button {
            if recordingState != .processing {
                toggleRecording()
            }
        } label: {
            ZStack {
                // First-time attention pulse
                if allEntries.isEmpty && recordingState == .idle {
                    Circle()
                        .stroke(buttonColor.opacity(0.25), lineWidth: 2)
                        .frame(width: recordButtonOuterSize + 20, height: recordButtonOuterSize + 20)
                        .scaleEffect(firstTimePulse ? 1.3 : 1.0)
                        .opacity(firstTimePulse ? 0 : 0.5)
                        .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: firstTimePulse)
                        .onAppear { firstTimePulse = true }
                }

                // Recording pulse rings — concentric, expanding outward
                if recordingState == .recording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(buttonColor.opacity(0.35), lineWidth: 2)
                            .frame(width: recordButtonOuterSize, height: recordButtonOuterSize)
                            .scaleEffect(recordingRingPulse ? 1.8 : 1.0)
                            .opacity(recordingRingPulse ? 0 : 0.5)
                            .animation(
                                .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(i) * 0.6),
                                value: recordingRingPulse
                            )
                    }
                }

                // Warm ambient glow
                Circle()
                    .fill(buttonColor.opacity(recordingState == .idle ? 0.12 : 0.06))
                    .frame(width: recordButtonOuterSize + 30, height: recordButtonOuterSize + 30)
                    .blur(radius: 15)

                // Main circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: recordButtonSize, height: recordButtonSize)

                // The 42-dot tick ring (spec §2.2): one dot per second of the
                // ritual, drifting at 120s/rev with one gold star orbiting at
                // 16s — a solar-system idle rather than a progress indicator.
                //
                // THE RING IS A SHAPE, NOT A CUTOFF. It fills to 42s and keeps
                // counting quietly; a ring that stopped there would invert the
                // meaning of the whole motif.
                TickRing(
                    diameter: recordButtonOuterSize + 34,
                    elapsed: recordingState == .recording ? Int(recorder.currentTime) : 0,
                    recording: recordingState == .recording
                )

                // Icon
                Group {
                    if recordingState == .recording {
                        // Stop square
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: isIPad ? 30 : 24, height: isIPad ? 30 : 24)
                            .transition(.scale.combined(with: .opacity))
                    } else if recordingState == .processing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.dv(size: isIPad ? 34 : 28))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: recordingState)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(recordingState == .recording ? "Stop recording" : "Start recording")
        .onChange(of: recordingState) { _, newValue in
            recordingRingPulse = (newValue == .recording)
        }
    }

    private var buttonColor: Color {
        switch recordingState {
        case .idle: return .accentColor
        case .recording: return ThemeManager.shared.recordingColor
        case .processing: return DS.Palette.gold
        }
    }

    private var statusText: String {
        switch recordingState {
        case .idle: return "Tap to record"
        case .recording: return "Tap to stop"
        case .processing: return "Almost done..."
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, recorder.level)))
        let baseHeight: CGFloat = 8
        let maxAdditional: CGFloat = 22

        // Create wave effect based on index
        let wave = sin(Double(index) * 0.5 + Date().timeIntervalSince1970 * 8) * 0.3 + 0.7
        return baseHeight + maxAdditional * normalizedLevel * CGFloat(wave)
    }

    private func barColor(for index: Int) -> Color {
        let normalizedLevel = CGFloat(max(0, min(1, recorder.level)))
        let barCount = CGFloat(isIPad ? 30 : 20)
        let threshold = CGFloat(index) / barCount

        if normalizedLevel > threshold {
            // Warm gradient from sage to gold — NOT traffic light colors
            let t = CGFloat(index) / barCount
            let sage = DS.Palette.sage
            let gold = DS.Palette.gold
            return t < 0.6 ? sage : gold
        }
        return Color.secondary.opacity(0.12)
    }

    // MARK: - Photo Handling

    private func handlePhotoPickerSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        // Get or create today's entry
        let entry = getOrCreateTodayEntry()

        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let fileName = PhotoStorageManager.shared.savePhoto(image) {
                            let jsonString = entry.value(forKey: "photoFileNames") as? String
                            var fileNames = PhotoStorageManager.parsePhotoFileNames(jsonString)
                            fileNames.append(fileName)
                            entry.setValue(PhotoStorageManager.encodePhotoFileNames(fileNames), forKey: "photoFileNames")
                            entry.updatedAt = Date()
                            try? viewContext.save()
                            HapticManager.shared.entrySaved()
                        }
                    }
                }
            }
        }
        selectedPhotos = []
    }

    private func getOrCreateTodayEntry() -> DiaryEntry {
        if let existing = latestEntry {
            return existing
        }
        let now = Date()
        let entry = DiaryEntry(context: viewContext)
        entry.id = UUID()
        entry.date = now
        entry.createdAt = now
        entry.text = ""
        entry.isStarred = false
        entry.updatedAt = now
        try? viewContext.save()
        return entry
    }

    // MARK: - Recording Logic

    private func toggleRecording() {
        switch recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            break
        }
    }

    private func startRecording() {
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    do {
                        try self.recorder.startRecording()
                        self.recordingState = .recording
                        HapticManager.shared.recordingStarted()
                    } catch {
                        self.errorMessage = "Unable to start recording. Please try again."
                        HapticManager.shared.error()
                    }
                } else {
                    self.errorMessage = "DailyVox needs microphone access to record your diary."
                    HapticManager.shared.warning()
                }
            }
        }
        #else
        errorMessage = "Recording is only available on iOS."
        #endif
    }

    private func stopRecording() {
        HapticManager.shared.recordingStopped()

        if let result = recorder.stopRecording() {
            recordingState = .processing
            saveEntry(audioURL: result.url, duration: result.duration)
        } else {
            recordingState = .idle
        }
    }

    private func saveEntry(audioURL: URL, duration: TimeInterval) {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        let fetchRequest: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1

        let entry: DiaryEntry
        if let existing = (try? viewContext.fetch(fetchRequest))?.first {
            entry = existing
        } else {
            entry = DiaryEntry(context: viewContext)
            entry.id = UUID()
            entry.date = now
            entry.createdAt = now
            entry.text = ""
            entry.isStarred = false
        }

        entry.updatedAt = now
        let newFileName = audioURL.lastPathComponent
        // Accumulate every recording for the day instead of overwriting the last one.
        // Build the list from the existing multi-file field (falling back to the legacy
        // single field) BEFORE we update the legacy field to the newest recording.
        var fileNames = AudioFileList.parse(entry.value(forKey: "audioFileNames") as? String,
                                            legacy: entry.value(forKey: "audioFileName") as? String)
        if !fileNames.contains(newFileName) { fileNames.append(newFileName) }
        entry.setValue(AudioFileList.encode(fileNames), forKey: "audioFileNames")
        entry.setValue(newFileName, forKey: "audioFileName") // latest, kept for back-compat
        let existingDuration = entry.value(forKey: "duration") as? Double ?? 0
        entry.setValue(existingDuration + duration, forKey: "duration")

        do {
            try viewContext.save()
            // Clear any selected prompt once an entry has been saved
            selectedPrompt = nil
            WidgetCenter.shared.reloadAllTimelines()
            // Tonight is spoken for, so drop tonight's reminder. The Settings
            // card promises "skips once you've spoken" and this is the moment
            // that makes it true.
            ReminderManager.shared.refresh(in: viewContext)
            // Body Twin: offer this moment's body signals to the review queue.
            // Fire-and-forget — never delays or fails the save, and this is the
            // ONLY capture site (onboarding seeds, Siri, imports and edits
            // deliberately never snapshot).
            Task { await BodyTwinManager.shared.captureSnapshotIfEligible() }

            // Research pilot: offer the one-tap self-label right at the recording
            // moment (labels must never be retrospective). Does not wait for
            // transcription; latest-wins if the day already carries a label.
            if pilotLabelingEnabled
                || ProcessInfo.processInfo.arguments.contains("-PilotLabelDemo") {
                withAnimation(.spring(response: 0.4)) { labelTarget = entry }
            }
        } catch {
            logger.error("Failed to save entry: \(error.localizedDescription)")
            recordingState = .idle
            return
        }

        #if os(iOS)
        SpeechTranscriber.shared.transcribe(from: audioURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let textSegment):
                    let existingText = entry.text ?? ""
                    if existingText.isEmpty {
                        entry.text = textSegment
                    } else {
                        entry.text = existingText + "\n\n" + textSegment
                    }
                    entry.updatedAt = Date()
                    do {
                        try viewContext.save()
                        HapticManager.shared.entrySaved()
                        ReviewManager.shared.recordEntry()
                        WidgetCenter.shared.reloadAllTimelines()

                        // Show celebration for first-ever entry
                        if !UserDefaults.standard.bool(forKey: "hasCompletedFirstEntry") {
                            UserDefaults.standard.set(true, forKey: "hasCompletedFirstEntry")
                            withAnimation(.spring(response: 0.4)) {
                                self.showFirstEntryMoment = true
                            }
                        }

                        // Feed into Digital Twin for learning
                        DigitalTwinEngine.shared.processEntry(
                            text: textSegment,
                            mood: entry.mood,
                            date: entry.date ?? Date(),
                            duration: entry.duration,
                            entryId: entry.id?.uuidString
                        )

                        // Fire the "a new star appeared" Live Activity and
                        // refresh the persistent streak Live Activity (if opted in).
                        Task { @MainActor in
                            let streak = currentStreak(in: viewContext)
                            let total = totalEntryCount(in: viewContext)
                            // Celebrate only the FIRST entry of the day. Subsequent
                            // same-day entries must not stack a new "a new star
                            // appeared" Live Activity each time.
                            if entriesTodayCount(in: viewContext) <= 1 {
                                LiveActivityManager.shared.fireStarBirthActivity(
                                    streak: streak,
                                    totalStars: total,
                                    moodRaw: entry.mood ?? ""
                                )
                            }
                            LiveActivityManager.shared.refreshStreakActivity(
                                streak: streak,
                                hasEntryToday: true,
                                totalEntries: total
                            )
                        }
                    } catch {
                        logger.error("Failed to update entry with transcription: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    logger.error("Transcription failed: \(error.localizedDescription)")
                    // Show user-friendly message for offline/transcription errors
                    if let transcriptionError = error as? SpeechTranscriber.TranscriptionError {
                        self.errorMessage = transcriptionError.errorDescription
                    } else {
                        self.errorMessage = "Transcription failed. Your recording is saved — tap the entry to add text manually."
                    }
                }
                recordingState = .idle
            }
        }
        #else
        recordingState = .idle
        #endif
    }

    // MARK: - Formatting

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func wordCount(for text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // MARK: - Stats

    private var daysRecordedThisYear: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        let days: Set<Date> = Set(allEntries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return calendar.startOfDay(for: date)
        })

        return days.filter { calendar.component(.year, from: $0) == currentYear }.count
    }

    private var streakCount: Int {
        Streak.current(dates: allEntries.compactMap(\.date))
    }
}

// MARK: - Stat Badge Component

/// Springy scale-down press feedback for tappable controls (the "buttery" tap feel).
struct SpringPressStyle: ButtonStyle {
    var scale: CGFloat = 0.92
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.dv(.caption, weight: .semibold))
            Text(value)
                .font(.dsCaption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

struct EntryPrompt: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String

    static let defaultPrompts: [EntryPrompt] = [
        EntryPrompt(
            title: "Daily reflection",
            detail: "What is one moment from today that you want to remember?"
        ),
        EntryPrompt(
            title: "Gratitude",
            detail: "What are three small things you feel grateful for right now?"
        ),
        EntryPrompt(
            title: "Energy check",
            detail: "How does your body feel today - tense, tired, or calm?"
        ),
        EntryPrompt(
            title: "Letting go",
            detail: "What is one worry you can gently put down for tonight?"
        ),
        EntryPrompt(
            title: "Self-kindness",
            detail: "If you spoke to yourself like a friend, what would you say?"
        ),
        EntryPrompt(
            title: "Tomorrow",
            detail: "What is one gentle intention you have for tomorrow?"
        )
    ]

    /// Plain, factual prompts (pilot protocol R1 §10 item 5): neutral is the
    /// scarce hard class in real diary data, and every default prompt above
    /// invites an emotional register. Pilot days periodically lead with one
    /// of these instead.
    static let neutralPrompts: [EntryPrompt] = [
        EntryPrompt(
            title: "Just log your day",
            detail: "Walk through your day start to finish - what you did, where, with whom. Facts are enough."
        ),
        EntryPrompt(
            title: "Plain notes",
            detail: "What did today actually look like? No reflection needed - just what happened."
        )
    ]
}

struct PromptChip: View {
    let prompt: EntryPrompt
    let isSelected: Bool
    let onTap: () -> Void

    /// The card underneath is `warmCardBackground`, which is navy at night —
    /// but the title was pinned to `DS.Palette.ink` and the detail to
    /// `inkMute`, both DAY tokens. At night the prompt titles rendered
    /// near-black on navy and simply were not there.
    @Environment(\.dvTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.dsCallout)
                    .foregroundColor(isSelected
                                     ? (theme.isNight ? DS.Palette.navy : DS.Palette.sageDeep)
                                     : theme.textColor)
                Text(prompt.detail)
                    .font(.dsCaption)
                    .foregroundColor(isSelected
                                     ? (theme.isNight ? DS.Palette.navy.opacity(0.7) : DS.Palette.inkMute)
                                     : theme.secondaryTextColor)
                    .lineLimit(2)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .frame(maxWidth: 280, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected
                          ? (theme.isNight ? DS.Palette.gold : DS.Palette.tintSage)
                          : theme.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected
                            ? theme.accentColor.opacity(0.40)
                            : theme.textColor.opacity(0.06), lineWidth: 1)
            )
            .dsShadowSoft()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Streak / Count helpers (shared with LiveActivityManager)

/// Counts consecutive days (ending today, or yesterday if no entry yet today)
/// that contain at least one diary entry. Returns 0 if none.
func currentStreak(in context: NSManagedObjectContext) -> Int {
    let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    guard let entries = try? context.fetch(request) else { return 0 }
    return Streak.current(dates: entries.compactMap(\.date))
}

func totalEntryCount(in context: NSManagedObjectContext) -> Int {
    let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
    return (try? context.count(for: request)) ?? 0
}

/// Number of entries created today — used to fire the Star Birth celebration
/// only on the first entry of the day.
func entriesTodayCount(in context: NSManagedObjectContext) -> Int {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
    let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
    request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
    return (try? context.count(for: request)) ?? 0
}

func hasEntryToday(in context: NSManagedObjectContext) -> Bool {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
    let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
    request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
    request.fetchLimit = 1
    return ((try? context.count(for: request)) ?? 0) > 0
}

/// 42 ticks around the record button, drawn as individual capsules so each one
/// has a round cap — a dashed stroke gives square ends and reads as a gear.
private struct TickRing: View {
    let diameter: CGFloat
    let elapsed: Int
    let recording: Bool

    @Environment(\.dvTheme) private var theme
    /// §8.8. Ambient loops are the first thing that has to stop.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: Double = 0
    @State private var orbit: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<42, id: \.self) { i in
                Capsule()
                    .fill(colour(for: i))
                    .frame(width: 2.5, height: 7)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(i) / 42 * 360 + drift))
            }

            // One small gold star, orbiting. Faster while recording: the solar
            // system speeds up while you speak.
            Circle()
                .fill(DS.Palette.gold)
                .frame(width: 7, height: 7)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(orbit))
        }
        .frame(width: diameter, height: diameter)
        .onAppear { restartSpin() }
        // The spin used to be started in `onAppear` alone, so the spec's
        // 16s → 12s acceleration on record never happened: this view is not
        // recreated when recording starts, and nothing re-read the flag.
        .onChange(of: recording) { _, _ in restartSpin() }
        .onChange(of: reduceMotion) { _, _ in restartSpin() }
    }

    private func restartSpin() {
        guard !reduceMotion else {
            // Park it, rather than freezing mid-rotation at a random angle.
            withAnimation(.linear(duration: 0.2)) { drift = 0; orbit = 0 }
            return
        }
        withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
            drift = 360
        }
        withAnimation(.linear(duration: recording ? 12 : 16).repeatForever(autoreverses: false)) {
            orbit = 360
        }
    }

    /// Lit ticks are gold — a second spoken is a thing made. Past 42 the ring
    /// stays full rather than wrapping, because it is a shape, not a cutoff.
    private func colour(for i: Int) -> Color {
        let lit = recording && i < min(elapsed, 42)
        if lit { return DS.Palette.gold }
        return theme.isNight
            ? DS.Palette.navyText.opacity(0.22)
            : DS.Palette.gold.opacity(0.35)
    }
}
