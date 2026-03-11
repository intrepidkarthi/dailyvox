//
//  TodayView.swift
//  solyn
//
//  Main recording interface for creating voice diary entries.
//  Handles audio recording, transcription, and entry creation.
//

import SwiftUI
import CoreData
import AVFoundation
import UIKit
import PhotosUI
import os.log

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

    @StateObject private var recorder = AudioRecorder()
    @State private var recordingState: RecordingState = .idle
    @State private var errorMessage: String?
    @State private var selectedPrompt: EntryPrompt? = nil
    @State private var selectedPhotos: [PhotosPickerItem] = []

    @FetchRequest private var todayEntries: FetchedResults<DiaryEntry>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: true)],
        animation: .default)
    private var allEntries: FetchedResults<DiaryEntry>

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
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerSection

                        // Entry Card
                        entryCardSection

                        // Show prompts only before today's first entry is recorded
                        if recordingState == .idle && latestEntry == nil {
                            promptsSection
                        }
                    }
                    .padding()
                }

                Spacer(minLength: 0)

                // Recording controls at bottom
                recordingSection
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
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromSiri)) { _ in
            // Auto-start recording when triggered from Siri shortcut
            if recordingState == .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    toggleRecording()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row with greeting and privacy badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formattedToday)
                        .font(.title.bold())
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
                        color: .orange
                    )
                }

                if daysRecordedThisYear > 0 {
                    StatBadge(
                        icon: "calendar",
                        value: "\(daysRecordedThisYear) this year",
                        color: .blue
                    )
                }

                Spacer()
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    // MARK: - Prompts Section

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Need a nudge?")
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
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(6)

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
                                        Text("Transcribing your recording...")
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                // No entry yet - show welcome card for first-time users
                if allEntries.isEmpty {
                    WelcomeCard()
                } else {
                    // Has entries but none today
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor)
                        }

                        VStack(spacing: 4) {
                            Text("Ready to journal?")
                                .font(.headline)
                            Text("Tap the mic to record today's entry")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 16) {
            // Processing indicator
            if recordingState == .processing {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Transcribing your thoughts...")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            }

            // Audio level meter (when recording)
            if recordingState == .recording {
                VStack(spacing: 12) {
                    // Recording time
                    Text(formatTime(recorder.currentTime))
                        .font(.system(size: 42, weight: .light, design: .monospaced))
                        .foregroundColor(.red)

                    // Waveform-style level indicator
                    HStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(for: i))
                                .frame(width: 4, height: barHeight(for: i))
                        }
                    }
                    .frame(height: 30)

                    Text("Recording... Tap to stop")
                        .font(.caption)
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
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 48, height: 48)
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
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
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Text("Your voice stays on this device")
                        .font(.caption)
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
        .background(Color(.systemGroupedBackground))
        .animation(.spring(response: 0.4), value: recordingState)
    }

    private var recordButton: some View {
        Button {
            if recordingState != .processing {
                toggleRecording()
            }
        } label: {
            ZStack {
                // Main circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: 72, height: 72)
                
                // Outer ring (subtle)
                Circle()
                    .stroke(buttonColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 88, height: 88)
                
                // Icon
                if recordingState == .recording {
                    // Stop square
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else if recordingState == .processing {
                    ProgressView()
                        .tint(.white)
                } else {
                    // Mic icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
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
        case .recording: return .red
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
        let threshold = CGFloat(index) / 20.0

        if normalizedLevel > threshold {
            return index > 14 ? .red : (index > 10 ? .orange : .accentColor)
        }
        return Color.secondary.opacity(0.2)
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
        entry.setValue(audioURL.lastPathComponent, forKey: "audioFileName")
        let existingDuration = entry.value(forKey: "duration") as? Double ?? 0
        entry.setValue(existingDuration + duration, forKey: "duration")

        do {
            try viewContext.save()
            // Clear any selected prompt once an entry has been saved
            selectedPrompt = nil
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

                        // Feed into Digital Twin for learning
                        DigitalTwinEngine.shared.processEntry(
                            text: textSegment,
                            mood: entry.mood,
                            date: entry.date ?? Date(),
                            duration: entry.duration
                        )
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 220, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
