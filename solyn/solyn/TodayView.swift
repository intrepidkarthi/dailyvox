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
struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var recorder = AudioRecorder()
    @State private var recordingState: RecordingState = .idle
    @State private var errorMessage: String?
    @State private var selectedPrompt: EntryPrompt? = nil
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var processingPhase: Int = 0
    @State private var processingTimer: Timer?
    @State private var pulseScale: CGFloat = 1.0
    @State private var showFirstEntryMoment: Bool = false
    @State private var firstTimePulse: Bool = false

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

    var body: some View {
        ZStack {
            WarmBackground()

            if allEntries.isEmpty && recordingState == .idle && latestEntry == nil {
                // FIRST-TIME FOCUSED EXPERIENCE
                firstTimeView
            } else {
                // NORMAL VIEW (existing)
                normalView
            }
        }
        .alert("Recording Error", isPresented: Binding(
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
                            .font(.system(size: 56))
                            .foregroundColor(Color(red: 0.831, green: 0.647, blue: 0.278))

                        Text("Your first star")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("Your constellation has begun. Every entry adds a new star to your inner sky.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showFirstEntryMoment = false
                            }
                        } label: {
                            Text("Continue")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
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
            Spacer()

            // Gentle prompt
            VStack(spacing: 24) {
                // Small star icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.1))
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.831, green: 0.647, blue: 0.278))
                }

                VStack(spacing: 12) {
                    Text("What's on your mind?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Tap the mic and speak for 42 seconds — or longer.\nYour first star will appear.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // The mic button — large, centered, inviting
            VStack(spacing: 20) {
                Button {
                    toggleRecording()
                } label: {
                    ZStack {
                        // Pulsing ring
                        Circle()
                            .stroke(Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.2), lineWidth: 2)
                            .frame(width: 108, height: 108)
                            .scaleEffect(firstTimePulse ? 1.3 : 1.0)
                            .opacity(firstTimePulse ? 0 : 0.5)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: firstTimePulse)

                        // Ambient glow
                        Circle()
                            .fill(Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.08))
                            .frame(width: 120, height: 120)
                            .blur(radius: 15)

                        // Outer ring
                        Circle()
                            .stroke(Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.3), lineWidth: 4)
                            .frame(width: 96, height: 96)

                        // Main circle
                        Circle()
                            .fill(Color(red: 0.357, green: 0.486, blue: 0.420))
                            .frame(width: 80, height: 80)

                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .onAppear { firstTimePulse = true }

                Text("Your voice stays on this device")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                // Privacy assurance
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.420, green: 0.620, blue: 0.482))
                    Text("No servers. No accounts. 100% private.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Normal View

    private var normalView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    entryCardSection
                    if recordingState == .idle && latestEntry == nil {
                        promptsSection
                    }
                }
                .padding()
                .frame(maxWidth: isIPad ? 700 : .infinity)
                .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
            recordingSection
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row with greeting and privacy badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(formattedToday)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                PrivacyBadge(compact: true)
            }

            // Stats row
            HStack(spacing: 12) {
                if streakCount > 0 {
                    StatBadge(
                        icon: "flame.fill",
                        value: "\(streakCount) day streak",
                        color: Color(red: 0.769, green: 0.584, blue: 0.416)
                    )
                }

                if daysRecordedThisYear > 0 {
                    StatBadge(
                        icon: "calendar",
                        value: "\(daysRecordedThisYear) this year",
                        color: Color(red: 0.357, green: 0.486, blue: 0.420)
                    )
                }

                Spacer()
            }
        }
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

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("A starting thought")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryPrompt.defaultPrompts) { prompt in
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
                    VStack(alignment: .leading, spacing: 12) {
                        // Header row
                        HStack {
                            Label("Today's Entry", systemImage: "doc.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }

                        // Entry content or processing state
                        if let text = entry.text, !text.isEmpty {
                            Text(text)
                                .font(.body)
                                .lineSpacing(4)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)

                            // Meta info
                            HStack(spacing: 16) {
                                if let duration = entry.value(forKey: "duration") as? Double, duration > 0 {
                                    Label(formatDuration(duration), systemImage: "waveform")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                let words = wordCount(for: text)
                                if words > 0 {
                                    Label("\(words) words", systemImage: "text.word.spacing")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if let updatedAt = entry.updatedAt {
                                    Text(formattedTime(updatedAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                            }
                        } else {
                            // Entry exists but no text yet
                            VStack(alignment: .leading, spacing: 8) {
                                if recordingState == .processing {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Understanding your words...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    // Recording saved but no transcription (offline or failed)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Recording saved")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("Tap to add text or play your recording")
                                            .font(.caption)
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
                    .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.831, green: 0.647, blue: 0.278))
                            Text("Tap the mic below to plant your first star")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.08))
                        .clipShape(Capsule())
                    }
                } else {
                    // Has entries but none today
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(red: 0.357, green: 0.486, blue: 0.420))
                        }

                        VStack(spacing: 4) {
                            Text("Add a star to today's sky")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                            Text("Just 42 seconds — your constellation grows with every entry")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
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
                        .font(.subheadline.weight(.medium))
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
                        .font(.system(size: 42, weight: .light, design: .rounded))
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Record button + photo button
            HStack(spacing: 24) {
                Spacer()

                // Photo picker
                if recordingState == .idle {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        ZStack {
                            Circle()
                                .fill(ThemeManager.shared.warmSubtleFill)
                                .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48)
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: isIPad ? 22 : 18))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        handlePhotoPickerSelection(newItems)
                    }
                }

                recordButton

                Spacer()
            }

            // Status text (only when idle)
            if recordingState == .idle {
                VStack(spacing: 6) {
                    Text(statusText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Your voice stays on this device")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    if let prompt = selectedPrompt {
                        Text(prompt.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(
            ThemeManager.shared.selectedTheme == .ivory
                ? Color(red: 0.980, green: 0.973, blue: 0.961)
                : Color(.systemGroupedBackground)
        )
        .animation(.spring(response: 0.4), value: recordingState)
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

                // Warm ambient glow
                Circle()
                    .fill(buttonColor.opacity(recordingState == .idle ? 0.12 : 0.06))
                    .frame(width: recordButtonOuterSize + 30, height: recordButtonOuterSize + 30)
                    .blur(radius: 15)

                // Main circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: recordButtonSize, height: recordButtonSize)

                // Outer ring (subtle)
                Circle()
                    .stroke(buttonColor.opacity(0.3), lineWidth: 4)
                    .frame(width: recordButtonOuterSize, height: recordButtonOuterSize)

                // Icon
                if recordingState == .recording {
                    // Stop square
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white)
                        .frame(width: isIPad ? 30 : 24, height: isIPad ? 30 : 24)
                } else if recordingState == .processing {
                    ProgressView()
                        .tint(.white)
                } else {
                    // Mic icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: isIPad ? 34 : 28))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recordingState == .recording ? "Stop recording" : "Start recording")
    }

    private var buttonColor: Color {
        switch recordingState {
        case .idle: return .accentColor
        case .recording: return ThemeManager.shared.recordingColor
        case .processing: return .orange
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
            let sage = Color(red: 0.357, green: 0.486, blue: 0.420)
            let gold = Color(red: 0.831, green: 0.647, blue: 0.278)
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
                            duration: entry.duration
                        )

                        // Fire the "a new star appeared" Live Activity and
                        // refresh the persistent streak Live Activity (if opted in).
                        Task { @MainActor in
                            let streak = currentStreak(in: viewContext)
                            let total = totalEntryCount(in: viewContext)
                            LiveActivityManager.shared.fireStarBirthActivity(
                                streak: streak,
                                totalStars: total,
                                moodRaw: entry.mood ?? ""
                            )
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
                        self.errorMessage = "Transcription failed. Your recording is saved—tap the entry to add text manually."
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
        let calendar = Calendar.current

        let daysSet: Set<Date> = Set(allEntries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return calendar.startOfDay(for: date)
        })

        var days = Array(daysSet)
        guard !days.isEmpty else { return 0 }
        days.sort(by: >)

        var streak = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i], to: days[i - 1]).day ?? 0
            if diff == 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
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
}

struct PromptChip: View {
    let prompt: EntryPrompt
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.caption.weight(.semibold))
                Text(prompt.detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 280, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : ThemeManager.shared.warmCardBackground)
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    let calendar = Calendar.current
    var checkDate = calendar.startOfDay(for: Date())
    let todayHasEntry = entries.contains { entry in
        guard let date = entry.date else { return false }
        return calendar.isDate(date, inSameDayAs: checkDate)
    }
    if !todayHasEntry {
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
    }

    var streak = 0
    while true {
        let hasEntry = entries.contains { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: checkDate)
        }
        if hasEntry {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        } else {
            break
        }
    }
    return streak
}

func totalEntryCount(in context: NSManagedObjectContext) -> Int {
    let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
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
