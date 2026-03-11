//
//  EntryDetailView.swift
//  solyn
//
//  Detail view for viewing and editing a single diary entry.
//  Supports text editing, mood selection, and audio playback.
//

import SwiftUI
import AVFoundation
import PhotosUI

/// Detail view for a single diary entry.
/// Allows viewing, editing text, setting mood, playing back audio, and attaching photos.
struct EntryDetailView: View {
    @ObservedObject var entry: DiaryEntry
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextFocused: Bool

    @State private var text: String
    @State private var selectedMood: Mood
    @State private var showMoodPicker = false
    @State private var isEditing = false
    @State private var showAIInsights = false
    @State private var aiAnalysis: AIAnalysisResult?

    // Photo state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoFileNames: [String] = []
    #if canImport(UIKit)
    @State private var photoImages: [UIImage] = []
    #endif

    init(entry: DiaryEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text ?? "")
        let moodString = entry.value(forKey: "mood") as? String ?? ""
        _selectedMood = State(initialValue: Mood(rawValue: moodString) ?? .none)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header card with metadata
                headerCard
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Audio player (when audio exists locally)
                if hasAudio, let url = audioURL() {
                    AudioPlayerView(audioURL: url)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                // Photo section
                photoSection
                    .padding(.horizontal)
                    .padding(.top, 4)

                // Main content area
                if isEditing {
                    editingView
                } else {
                    readingView

                    if !text.isEmpty {
                        aiInsightsSection
                    }
                }
            }
        }
        .navigationTitle(formattedShortDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: toggleStar) {
                        Image(systemName: entry.isStarred ? "star.fill" : "star")
                            .foregroundColor(entry.isStarred ? .yellow : .secondary)
                    }

                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "Done" : "Edit")
                    }
                }
            }
        }
        .onDisappear(perform: saveIfNeeded)
        .onAppear(perform: loadPhotos)
        .onChange(of: selectedPhotos) { _, newItems in
            handlePhotoSelection(newItems)
        }
        .onChange(of: entry.text) { _, newValue in
            // Update local text when entry.text changes (e.g., after transcription completes)
            // Only update if not currently editing to avoid overwriting user edits
            if !isEditing && !isTextFocused {
                text = newValue ?? ""
            }
        }
        .sheet(isPresented: $showMoodPicker) {
            MoodPickerSheet(selectedMood: $selectedMood, onSave: saveMood)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            // Date and time
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedFullDate)
                        .font(.subheadline.weight(.medium))
                    if let updatedAt = entry.updatedAt {
                        Text("Updated \(formattedTime(updatedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Mood badge
                Button(action: { showMoodPicker = true }) {
                    if selectedMood == .none {
                        Label("Add mood", systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: selectedMood.icon)
                                .font(.caption)
                            Text(selectedMood.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(selectedMood.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedMood.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            // Stats row
            HStack(spacing: 20) {
                Label("\(wordCount) words", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let duration = entry.value(forKey: "duration") as? Double, duration > 0 {
                    Label(formattedDuration(duration), systemImage: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Audio playback or "on other device" note
                if audioOnOtherDevice {
                    // Audio exists but on another device
                    HStack(spacing: 4) {
                        Image(systemName: "icloud")
                            .font(.caption)
                        Text("Audio on original device")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reading View

    private var isTranscribing: Bool {
        text.isEmpty && hasAudioReference
    }

    private var readingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if text.isEmpty {
                    if isTranscribing {
                        // Transcription in progress
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Transcribing your recording...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // No text and no audio
                        VStack(spacing: 12) {
                            Image(systemName: "text.cursor")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No text yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Add text") {
                                isEditing = true
                            }
                            .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                } else {
                    Text(text)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onTapGesture {
            if !isTranscribing {
                isEditing = true
            }
        }
    }

    // MARK: - AI Insights Section
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showAIInsights.toggle()
                    if showAIInsights && aiAnalysis == nil {
                        aiAnalysis = LocalAIEngine.shared.analyze(text: text)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.teal)
                    Text("AI Insights")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: showAIInsights ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            if showAIInsights, let analysis = aiAnalysis {
                VStack(alignment: .leading, spacing: 16) {
                    // Emotion & Sentiment
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(analysis.dominantEmotion.emoji)
                                .font(.title)
                            Text(analysis.dominantEmotion.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 70)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sentiment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(analysis.sentiment > 0 ? Color.green : Color.orange)
                                        .frame(width: geo.size.width * CGFloat(abs(analysis.sentiment)))
                                }
                            }
                            .frame(height: 8)
                            
                            Text(analysis.sentiment > 0.2 ? "Positive" : (analysis.sentiment < -0.2 ? "Negative" : "Neutral"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Intent
                    HStack {
                        Image(systemName: "quote.bubble")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Intent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(analysis.intent.description)
                                .font(.subheadline)
                        }
                    }
                    
                    // Topics
                    if !analysis.topics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topics")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            FlowLayout(spacing: 6) {
                                ForEach(analysis.topics.prefix(5), id: \.self) { topic in
                                    Text(topic)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.teal.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // AI Response
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💭 Reflection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(analysis.suggestedResponse)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.teal.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Editing View

    private var editingView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.body)
                .lineSpacing(6)
                .focused($isTextFocused)
                .scrollContentBackground(.hidden)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Keyboard toolbar
            if isTextFocused {
                HStack {
                    Text("\(wordCount) words · \(characterCount) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Done") {
                        isTextFocused = false
                        isEditing = false
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .onAppear {
            isTextFocused = true
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if canImport(UIKit)
            // Photo thumbnails
            if !photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            #endif

            // Photo picker
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.caption)
                    Text(photoFileNames.isEmpty ? "Add Photos" : "Add More")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
            }

            if !photoFileNames.isEmpty {
                Text("Photos stay on this device")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadPhotos() {
        #if canImport(UIKit)
        let jsonString = entry.value(forKey: "photoFileNames") as? String
        photoFileNames = PhotoStorageManager.parsePhotoFileNames(jsonString)
        photoImages = photoFileNames.compactMap { PhotoStorageManager.shared.loadPhoto(fileName: $0) }
        #endif
    }

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        #if canImport(UIKit)
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let fileName = PhotoStorageManager.shared.savePhoto(image) {
                            photoFileNames.append(fileName)
                            photoImages.append(image)
                            savePhotoFileNames()
                        }
                    }
                }
            }
        }
        selectedPhotos = []
        #endif
    }

    private func savePhotoFileNames() {
        let encoded = PhotoStorageManager.encodePhotoFileNames(photoFileNames)
        entry.setValue(encoded, forKey: "photoFileNames")
        entry.updatedAt = Date()
        try? viewContext.save()
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var characterCount: Int {
        text.count
    }

    private var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: entry.date ?? Date())
    }

    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: entry.date ?? Date())
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Entry has an audio filename stored (may have been recorded on another device)
    private var hasAudioReference: Bool {
        (entry.value(forKey: "audioFileName") as? String)?.isEmpty == false
    }

    /// Audio file exists locally on this device
    private var hasAudio: Bool {
        guard let url = audioURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Audio was recorded but file is on another device (synced via iCloud)
    private var audioOnOtherDevice: Bool {
        hasAudioReference && !hasAudio
    }

    private func formattedDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func audioURL() -> URL? {
        guard let fileName = entry.value(forKey: "audioFileName") as? String, !fileName.isEmpty else { return nil }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordingsDir = base.appendingPathComponent("Recordings", isDirectory: true)
        return recordingsDir.appendingPathComponent(fileName)
    }

    // MARK: - Actions

    private func toggleStar() {
        entry.isStarred.toggle()
        entry.updatedAt = Date()
        HapticManager.shared.entryStarred()
        do {
            try viewContext.save()
        } catch {
            // ignore
        }
    }

    private func saveIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMood = entry.value(forKey: "mood") as? String ?? ""
        let needsSave = trimmed != (entry.text ?? "") || selectedMood.rawValue != currentMood

        if needsSave {
            entry.text = trimmed
            entry.setValue(selectedMood.rawValue, forKey: "mood")
            entry.updatedAt = Date()
            do {
                try viewContext.save()

                // Feed into Digital Twin
                if !trimmed.isEmpty {
                    DigitalTwinEngine.shared.processEntry(
                        text: trimmed,
                        mood: selectedMood.rawValue,
                        date: entry.date ?? Date(),
                        duration: entry.duration
                    )
                }
            } catch {
                // ignore
            }
        }
    }

    private func saveMood() {
        entry.setValue(selectedMood.rawValue, forKey: "mood")
        entry.updatedAt = Date()
        HapticManager.shared.moodSelected()
        do {
            try viewContext.save()
        } catch {
            // ignore
        }
    }
}

// MARK: - Mood Picker Sheet

struct MoodPickerSheet: View {
    @Binding var selectedMood: Mood
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        selectedMood = .none
                        onSave()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.dashed")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            Text("No mood")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedMood == .none {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }

                Section(header: Text("Select a mood")) {
                    ForEach(Mood.selectableMoods) { mood in
                        Button(action: {
                            selectedMood = mood
                            onSave()
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: mood.icon)
                                    .font(.title3)
                                    .foregroundColor(mood.color)
                                    .frame(width: 28)
                                Text(mood.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMood == mood {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
