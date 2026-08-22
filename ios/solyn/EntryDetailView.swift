//
//  EntryDetailView.swift
//  solyn
//
//  Detail view for viewing and editing a single diary entry.
//  Supports text editing, mood selection, and audio playback.
//

import SwiftUI
import DailyVoxTwinEngine
import AVFoundation
import PhotosUI
import WidgetKit

/// Detail view for a single diary entry.
/// Allows viewing, editing text, setting mood, playing back audio, and attaching photos.
struct EntryDetailView: View {
    @Environment(\.dvTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var entry: DiaryEntry
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isTextFocused: Bool

    @State private var text: String
    @State private var selectedMood: Mood
    @State private var showMoodPicker = false
    @State private var isEditing = false
    @State private var showAIInsights = false
    /// B4's "Ask about this" — opens the Twin already pointed at this entry.
    @State private var askAboutThis = false
    @State private var showShareSheet = false
    @State private var aiAnalysis: AIAnalysisResult?

    // Photo state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoFileNames: [String] = []
    #if canImport(UIKit)
    @State private var photoImages: [UIImage] = []
    #endif

    private var isIPad: Bool { horizontalSizeClass == .regular }

    init(entry: DiaryEntry) {
        self.entry = entry
        _text = State(initialValue: entry.text ?? "")
        let moodString = entry.value(forKey: "mood") as? String ?? ""
        _selectedMood = State(initialValue: Mood(rawValue: moodString) ?? .none)
    }

    var body: some View {
        ZStack {
            WarmBackground()

            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Header card with metadata
                    headerCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Audio, in ONE surface however many recordings a day holds.
                    //
                    // Each player draws its own card, so a day with two takes
                    // rendered two identical full-width cards with two shadows —
                    // which reads as a duplicate bug rather than as "you spoke
                    // twice". Grouped, with a count when it is more than one,
                    // they read as this entry's audio.
                    let urls = localAudioURLs()
                    if !urls.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            if urls.count > 1 {
                                Text("\(urls.count) RECORDINGS")
                                    .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundColor(theme.secondaryTextColor)
                                    .padding(.horizontal, 4)
                            }
                            ForEach(urls, id: \.self) { url in
                                AudioPlayerView(audioURL: url)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    } else if hasRecordedAudio {
                        // The entry HAS a recording, just not on this device —
                        // it arrived over iCloud sync and the audio stayed home.
                        //
                        // This state used to live in the metadata card, which was
                        // removed for being mostly administrivia. Taking the
                        // indicator with it meant a synced entry showed nothing
                        // about its audio at all, which reads as the recording
                        // having been lost.
                        HStack(spacing: 8) {
                            Image(systemName: "icloud")
                                .font(.dv(size: 12, weight: .semibold))
                            Text("AUDIO STAYED ON THE PHONE THAT RECORDED IT")
                                .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                                .tracking(1.0)
                        }
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }

                    // Photo section
                    photoSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    // The life-area chip ("Work") used to float on its own
                    // between the audio and the transcript — one lone capsule in
                    // its own band of the page, belonging to nothing. It is a
                    // fact the machine derived, so it belongs where the other
                    // derived facts are: the Twin ledger, as a TOPICS row.

                    // Main content area
                    if isEditing {
                        editingView
                    } else {
                        readingView

                        // The ledger goes directly under the transcript it is a
                        // receipt for — B4's order, and the only order where the
                        // gold underlines above and the rows below read as the
                        // same statement.
                        twinFiledSection

                        // No "AI Insights" card. It was a second name for what
                        // "What your Twin filed" already says — the machine's
                        // reading of this entry — and "AI" is the category this
                        // product defines itself against. Two names on one screen
                        // teach people the Twin is a skin over something generic.
                        // The section's code stays; nothing composes it.

                        entryActions

                        // The floating tab bar overlays every screen in the
                        // ZStack, pushed detail views included — so without this
                        // the two actions at the foot of an entry sat UNDER it
                        // and could not be pressed at all.
                        Color.clear
                            .frame(height: DailyVoxTabBar.reservedHeight)
                    }
                }
            }
            .frame(maxWidth: isIPad ? 700 : .infinity)
            .frame(maxWidth: .infinity)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: isTextFocused) { _, focused in
                if focused {
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollProxy.scrollTo("entryEditor", anchor: .top)
                    }
                }
            }
            }
        }
        .navigationTitle(formattedShortDate)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView().appThemedSheet()
        }
        .sheet(isPresented: $askAboutThis) {
            NavigationStack {
                TwinChatView(seedQuestion: seedQuestion)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // The star alone. Edit moved to the action row at the foot of
                // the entry (B4), which also splits two unrelated actions that
                // were sharing one pill.
                Button(action: toggleStar) {
                    Image(systemName: entry.isStarred ? "star.fill" : "star")
                        .foregroundColor(entry.isStarred ? DS.Palette.gold : theme.secondaryTextColor)
                }
                .accessibilityLabel(entry.isStarred ? "Unstar this entry" : "Star this entry")
            }
        }
        .onDisappear(perform: saveIfNeeded)
        // Backgrounding is the other way an edit leaves the screen, and the one
        // iOS can follow with termination. `.onDisappear` does not fire then.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveIfNeeded() }
        }
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

    /// B4 puts the entry's facts as a MONO LINE under the date, not in a card.
    ///
    /// The card repeated the navigation title ("Aug 21" above "Friday, August
    /// 21, 2026"), then spent a full surface on a timestamp and a word count.
    /// On a screen whose job is to show you what you said, the first thing you
    /// met was a box of administrivia.
    private var headerCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(entryMetaLine)
                .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(theme.secondaryTextColor)

            Spacer(minLength: 0)

            // Mood stays: it is the one thing here you can still change.
            Button { showMoodPicker = true } label: {
                if selectedMood == .none {
                    Text("ADD MOOD")
                        .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(theme.accentColor)
                } else {
                    Text(selectedMood.displayName.uppercased())
                        .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(selectedMood.color)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
    }

    /// "5:28 PM · 0:04 · 17 WORDS"
    private var entryMetaLine: String {
        var parts: [String] = []
        // `entry.date`, not `updatedAt`. This line says when the entry was
        // SPOKEN; reading it from the modification stamp meant fixing one typo
        // at 11:47pm rewrote a morning entry's history to "11:47 PM".
        if let spokenAt = entry.date { parts.append(formattedTime(spokenAt).uppercased()) }
        let seconds = Int(entry.duration.rounded())
        if seconds > 0 { parts.append(String(format: "%d:%02d", seconds / 60, seconds % 60)) }
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        if words > 0 { parts.append("\(words) WORDS") }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Reading View

    private var isTranscribing: Bool {
        text.isEmpty && hasAudioReference
    }

    private var readingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty {
                if isTranscribing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Transcribing your recording...")
                            .font(.dv(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.cursor")
                            .font(.dv(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No text yet")
                            .font(.dv(.subheadline))
                            .foregroundColor(.secondary)
                        Button("Add text") {
                            isEditing = true
                        }
                        .font(.dv(.subheadline, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            } else {
                // B4: the entities the Twin found are underlined in gold, in
                // place. It is the cheapest possible proof that something read
                // this — the ledger below says WHAT was filed, the underline
                // says WHERE it came from.
                Text(underlined(text))
                    .font(.dv(.body))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
        .padding(.vertical, 8)
        // NO tap-to-edit. The same text is `.textSelection(.enabled)`, so
        // reaching in to select a sentence to quote instead opened a TextEditor
        // and threw the keyboard up — two gestures competing for one press,
        // with the destructive one winning. Edit is an explicit button in the
        // actions row, which is where it reads as a choice.
    }

    /// What "Ask about this" actually asks.
    ///
    /// Dated rather than quoted: the retrieval path already finds the entry from
    /// its date, and pasting the transcript into the question would make the
    /// answer echo the entry back instead of relating it to the rest.
    private var seedQuestion: String {
        let when = formattedShortDate
        if let subject = filedEntities.first?.label {
            return "What do my entries say about \(subject), around \(when)?"
        }
        return "What was going on for me around \(when)?"
    }

    // MARK: - Entity underlining

    /// Names the knowledge graph already knows, marked up where they appear.
    ///
    /// Matched against the graph rather than re-detected here: the graph has
    /// already decided what counts as a person or a place, and a second opinion
    /// in the view would underline things the Twin never filed — which would
    /// make the ledger below look wrong when it is right.
    private func underlined(_ source: String) -> AttributedString {
        var attributed = AttributedString(source)
        let labels = filedEntities.map(\.label)
        guard !labels.isEmpty else { return attributed }

        for label in labels where !label.isEmpty {
            // Word boundaries, via the same rule the ledger below is filtered
            // by — otherwise the transcript underlines things the ledger does
            // not list, and each makes the other look broken.
            for range in EntityMatch.properNounRanges(of: label, in: source) {
                guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                      let upper = AttributedString.Index(range.upperBound, within: attributed)
                else { continue }
                let found = lower..<upper
                attributed[found].underlineStyle = .single
                attributed[found].underlineColor = UIColor(DS.Palette.gold)
                attributed[found].foregroundColor = UIColor(ThemeManager.shared.goldText)
            }
        }
        return attributed
    }

    /// Graph nodes whose label actually occurs in this entry.
    private var filedEntities: [PersonalKnowledgeGraph.KnowledgeNode] {
        guard !text.isEmpty else { return [] }
        return DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .person, limit: 40)
            .filter { EntityMatch.mentionsAsName($0.label, in: text) }
    }

    private var filedPlaces: [PersonalKnowledgeGraph.KnowledgeNode] {
        guard !text.isEmpty else { return [] }
        return DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .place, limit: 20)
            .filter { EntityMatch.mentionsAsName($0.label, in: text) }
    }

    // MARK: - What your Twin filed (B4)

    /// The ledger.
    ///
    /// Not a summary and not an interpretation — a receipt. Every row is
    /// something the Twin took from this entry and will use later, stated in the
    /// same words it stored. If a row here is wrong, the user can see it is
    /// wrong, which is the only way an on-device model earns any trust at all.
    @ViewBuilder
    private var twinFiledSection: some View {
        let people = filedEntities
        let places = filedPlaces
        let words = text.split(whereSeparator: \.isWhitespace).count
        let pace: String? = {
            let seconds = entry.duration
            guard seconds > 5, words > 0 else { return nil }
            let wpm = Double(words) / (Double(seconds) / 60)
            guard wpm.isFinite, wpm > 20, wpm < 400 else { return nil }
            return "\(Int(wpm.rounded())) words a minute"
        }()

        // Shown only when the Twin actually filed something. With nothing
        // detected it rendered a full card whose single row read "MOOD not set"
        // — a heading, a surface and a shadow to tell you nothing happened.
        let hasAnything = selectedMood != .none || !people.isEmpty || !places.isEmpty
            || bodyLine != nil || pace != nil || !detectLifeAreas(from: text).isEmpty

        if !text.isEmpty && hasAnything {
            VStack(alignment: .leading, spacing: 10) {
                Text("WHAT YOUR TWIN FILED \u{2726}")
                    .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(ThemeManager.shared.secondaryTextColor)

                // MOOD, MENTIONED, BODY, PACE, TOPICS.
                //
                // The second row folds people and places into one line — the
                // canvas lists what was in the entry, not which detector found
                // it — but it was LABELLED "Places", so a dinner-party entry
                // filed "PLACES: Sarah · James · Emma · Lisa". The extractor
                // also types the same name as both a person and a place, so the
                // merged list could repeat a name. "Mentioned" is true of every
                // item whichever detector produced it, and the dedupe is
                // case-insensitive because the two detectors do not agree on
                // capitalisation either.
                filedRow("Mood", moodLine)
                var seen = Set<String>()
                let named = (people + places).map(\.label)
                    .filter { seen.insert($0.lowercased()).inserted }
                if !named.isEmpty {
                    filedRow("Mentioned", named.joined(separator: " \u{00B7} "))
                }
                if let body = bodyLine {
                    filedRow("Body", body)
                }
                if let pace {
                    filedRow("Pace", pace)
                }
                // Topics, where the floating "Work" chip went.
                let areas = detectLifeAreas(from: text)
                if !areas.isEmpty {
                    filedRow("Topics", areas.map(\.rawValue).joined(separator: " \u{00B7} "))
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    /// Mood the way the canvas writes it: the word and the number together.
    private var moodLine: String {
        guard selectedMood != .none else { return "not set" }
        let v = (Double(selectedMood.moodValue) - 3.0) / 2.0
        return String(format: "%@ %+.1f", selectedMood.displayName, v)
    }

    /// Body context for the day this entry was spoken, if any was kept.
    private var bodyLine: String? {
        guard let date = entry.date else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        // `capturedAt`, not `keptAt`: keeping is batched, so `keptAt` is when
        // the user got round to reviewing, which is routinely a different day
        // from the one the entry — and the body reading — belong to.
        let kept = KeptSnapshotStore.shared.loadAll().first {
            Calendar.current.startOfDay(for: $0.snapshot.capturedAt) == day
        }
        guard let hours = kept?.snapshot.sleepHours else { return nil }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh%02d sleep the night before", h, m)
    }

    /// B4's two actions, as a row at the foot of the entry.
    ///
    /// Edit used to live in the navigation bar sharing a pill with the star —
    /// two unrelated actions in one container — and Ask-about-this was a chip
    /// inside the ledger. The canvas gives them equal weight at the bottom,
    /// which is where you are once you have finished reading.
    private var entryActions: some View {
        HStack(spacing: 10) {
            Button { isEditing = true } label: {
                Text("Edit")
                    .font(.dv(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textColor)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.textColor.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button { askAboutThis = true } label: {
                HStack(spacing: 6) {
                    Text("\u{2726}")
                    Text("Ask about this")
                }
                .font(.dv(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(theme.isNight ? DS.Palette.navy : .white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.accentColor)
                )
            }
            .buttonStyle(.plain)

            // Share, where the thing worth sharing is.
            //
            // §F is the whole marketing thesis — "the app that can't post is the
            // app worth posting about" — and it was reachable from exactly one
            // place: a 34pt unlabelled glyph in the corner of the Twin tab.
            // An entry you have just read is the most likely moment anyone ever
            // wants to make a card.
            Button { showShareSheet = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.dv(size: 16, weight: .semibold))
                    .foregroundColor(theme.goldText)
                    .frame(width: 52, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DS.Palette.gold.opacity(0.16))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share this entry")
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private func filedRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(ThemeManager.shared.secondaryTextColor)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.dv(size: 13.5))
                .foregroundColor(ThemeManager.shared.textColor)
            Spacer(minLength: 0)
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
                        .foregroundColor(theme.accentColor)
                    Text("AI Insights")
                        .font(.dv(.subheadline, weight: .medium))
                    Spacer()
                    Image(systemName: showAIInsights ? "chevron.up" : "chevron.down")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            if showAIInsights, let analysis = aiAnalysis {
                VStack(alignment: .leading, spacing: 16) {
                    // Emotion & Sentiment
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Image(systemName: analysis.dominantEmotion.emoji)
                                .font(.dv(.title))
                            Text(analysis.dominantEmotion.rawValue.capitalized)
                                .font(.dv(.caption))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 70)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sentiment")
                                .font(.dv(.caption))
                                .foregroundColor(.secondary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Palette.inkMute.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(analysis.sentiment > 0 ? DS.Palette.forest : DS.Palette.terracotta)
                                        .frame(width: geo.size.width * CGFloat(abs(analysis.sentiment)))
                                }
                            }
                            .frame(height: 8)
                            
                            Text(analysis.sentiment > 0.2 ? "Positive" : (analysis.sentiment < -0.2 ? "Negative" : "Neutral"))
                                .font(.dv(.caption2))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Intent
                    HStack {
                        Image(systemName: "quote.bubble")
                            .foregroundColor(theme.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Intent")
                                .font(.dv(.caption))
                                .foregroundColor(.secondary)
                            Text(analysis.intent.description)
                                .font(.dv(.subheadline))
                        }
                    }
                    
                    // Topics
                    if !analysis.topics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topics")
                                .font(.dv(.caption))
                                .foregroundColor(.secondary)
                            
                            FlowLayout(spacing: 6) {
                                ForEach(analysis.topics.prefix(5), id: \.self) { topic in
                                    Text(topic)
                                        .font(.dv(.caption2))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(DS.Palette.sage.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // AI Response
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.dv(.caption))
                            Text("Reflection")
                        }
                            .font(.dv(.caption))
                            .foregroundColor(.secondary)
                        Text(analysis.suggestedResponse)
                            .font(.dv(.caption))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Palette.sage.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .font(.dv(.body))
                .lineSpacing(6)
                .focused($isTextFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 240, maxHeight: 360)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Keyboard toolbar
            if isTextFocused {
                HStack {
                    Text("\(wordCount) words · \(characterCount) chars")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Done") {
                        isTextFocused = false
                        isEditing = false
                        // Done means done. This used to only drop focus and
                        // leave the edit sitting in @State until .onDisappear —
                        // so an entry rewritten and then left on screen was
                        // lost outright if iOS reclaimed the app.
                        saveIfNeeded()
                    }
                    .font(.dv(.subheadline, weight: .medium))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .onAppear {
            isTextFocused = true
        }
        .id("entryEditor")
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
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: isIPad ? 120 : 80, height: isIPad ? 120 : 80)
                                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 12 : 8))

                                Button {
                                    removePhoto(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.dv(.title3))
                                        .foregroundStyle(.white, .red)
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            #endif

            // Photo picker — withheld while FeatureFlags.photoAttachments is
            // off. Existing photos below still render and still export: this
            // hides the way to ADD one, never anybody's attachments.
            if FeatureFlags.photoAttachments {
                PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.dv(.caption))
                    Text(photoFileNames.isEmpty ? "Add Photos" : "Add More")
                        .font(.dv(.caption, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
                }
            }

            if !photoFileNames.isEmpty {
                Text("Photos stay on this device")
                    .font(.dv(.caption2))
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

    private func removePhoto(at index: Int) {
        guard index < photoFileNames.count else { return }
        let fileName = photoFileNames[index]
        PhotoStorageManager.shared.deletePhoto(fileName: fileName)
        photoFileNames.remove(at: index)
        #if canImport(UIKit)
        if index < photoImages.count {
            photoImages.remove(at: index)
        }
        #endif
        savePhotoFileNames()
        HapticManager.shared.entryDeleted()
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

    /// All recordings referenced by this entry (multi-recording aware, with legacy fallback).
    private func audioFileNamesList() -> [String] {
        AudioFileList.parse(entry.value(forKey: "audioFileNames") as? String,
                            legacy: entry.value(forKey: "audioFileName") as? String)
    }

    /// Local URLs for the recordings that actually exist on this device.
    /// True when the entry names a recording, whether or not this device has it.
    private var hasRecordedAudio: Bool {
        !audioFileNamesList().isEmpty
    }

    private func localAudioURLs() -> [URL] {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordingsDir = base.appendingPathComponent("Recordings", isDirectory: true)
        return audioFileNamesList()
            .map { recordingsDir.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Actions

    private func toggleStar() {
        entry.isStarred.toggle()
        entry.updatedAt = Date()
        HapticManager.shared.entryStarred()
        do {
            try viewContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // ignore
        }
    }

    private func saveIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMood = entry.value(forKey: "mood") as? String ?? ""
        let oldText = entry.text ?? ""
        let needsSave = trimmed != oldText || selectedMood.rawValue != currentMood

        if needsSave {
            entry.text = trimmed
            entry.setValue(selectedMood.rawValue, forKey: "mood")
            entry.updatedAt = Date()
            do {
                try viewContext.save()
                WidgetCenter.shared.reloadAllTimelines()

                // Feed into Digital Twin — use reprocess if text was edited
                if !trimmed.isEmpty {
                    if !oldText.isEmpty && trimmed != oldText {
                        // Text was edited — re-process to update entity names
                        DigitalTwinEngine.shared.reprocessEditedEntry(
                            oldText: oldText,
                            newText: trimmed,
                            mood: selectedMood.rawValue,
                            date: entry.date ?? Date(),
                            duration: entry.duration,
                            entryId: entry.id?.uuidString
                        )
                    } else {
                        DigitalTwinEngine.shared.processEntry(
                            text: trimmed,
                            mood: selectedMood.rawValue,
                            date: entry.date ?? Date(),
                            duration: entry.duration,
                            entryId: entry.id?.uuidString
                        )
                    }
                    // v1.6: keep the semantic memory index in step with edits.
                    if let id = entry.id {
                        SemanticSearchManager.shared.indexEntry(id: id, text: trimmed, date: entry.date ?? Date())
                    }
                    // v1.6 voice biomarkers: extract prosody from the audio ONCE
                    // (fresh process, not an edit) and fold it as the entry's
                    // arousal signal — delta from the user's own vocal baseline.
                    if oldText.isEmpty, let url = audioURL() {
                        let wordCount = trimmed.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
                        Task.detached {
                            let features = ProsodyExtractor.features(from: url, wordCount: wordCount)
                            await MainActor.run { DigitalTwinEngine.shared.foldProsody(features) }
                        }
                    }
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
            WidgetCenter.shared.reloadAllTimelines()
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
                                .font(.dv(.title3))
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
                                    .font(.dv(.title3))
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
