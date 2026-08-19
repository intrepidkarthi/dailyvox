//
//  TimelineView.swift
//  solyn
//
//  Displays all diary entries in a chronological timeline.
//  Supports search, filtering by starred entries, mood, date range, and swipe-to-delete.
//

import SwiftUI
import DailyVoxTwinEngine
import CoreData
import WidgetKit
#if os(iOS)
import Speech
#endif

// MARK: - Life Area Auto-Tagging

enum LifeArea: String, CaseIterable {
    case work = "Work"
    case health = "Health"
    case relationships = "Relationships"
    case growth = "Growth"
    case family = "Family"
    case creativity = "Creativity"

    /// Warm-palette hues (same blue→sage, green→forest, pink→dusty rose,
    /// purple→plum, orange→terracotta, yellow→gold mapping as Insights).
    var color: Color {
        switch self {
        case .work: return DS.Palette.sage
        case .health: return DS.Palette.forest
        case .relationships: return DS.Palette.terracotta // dusty rose
        case .growth: return DS.Palette.terracotta        // muted plum
        case .family: return DS.Palette.terracotta
        case .creativity: return DS.Palette.gold
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .health: return "heart.fill"
        case .relationships: return "person.2.fill"
        case .growth: return "arrow.up.right"
        case .family: return "house.fill"
        case .creativity: return "paintbrush.fill"
        }
    }

    var keywords: [String] {
        switch self {
        case .work:
            return ["work", "job", "meeting", "project", "deadline", "boss", "office", "client", "career", "team", "colleague"]
        case .health:
            return ["health", "exercise", "sleep", "tired", "gym", "run", "walk", "sick", "doctor", "yoga", "meditate", "stress", "anxiety"]
        case .relationships:
            return ["friend", "date", "love", "relationship", "partner", "girlfriend", "boyfriend", "wife", "husband"]
        case .growth:
            return ["learn", "read", "book", "course", "goal", "improve", "habit", "skill", "practice", "study"]
        case .family:
            return ["family", "mom", "dad", "parent", "brother", "sister", "child", "kid", "son", "daughter", "home"]
        case .creativity:
            return ["write", "create", "art", "music", "design", "build", "idea", "paint", "draw", "photo", "film"]
        }
    }
}

func detectLifeAreas(from text: String) -> [LifeArea] {
    let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    let wordSet = Set(words)

    var counts: [(LifeArea, Int)] = LifeArea.allCases.compactMap { area in
        let matchCount = area.keywords.filter { wordSet.contains($0) }.count
        return matchCount > 0 ? (area, matchCount) : nil
    }

    counts.sort { $0.1 > $1.1 }
    return Array(counts.prefix(2).map(\.0))
}

/// Displays all diary entries grouped by month.
/// Supports search, starred filter, mood filter, date range, and pull-to-refresh.
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var theme = ThemeManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    // MARK: - Search State
    
    @State private var searchText: String = ""
    @StateObject private var todayQueue = TodayAudioQueue()
    @State private var todayDuration: TimeInterval?
    @State private var showSemanticSearch: Bool = false
    @State private var showStarredOnly: Bool = false
    @State private var showFilters: Bool = false
    @State private var selectedMoodFilter: Mood? = nil
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var isListening: Bool = false
    @State private var searchSuggestions: [DigitalTwinEngine.SearchSuggestion] = []

    #if os(iOS)
    @StateObject private var voiceSearch = VoiceSearchManager()
    #endif

    private var twin: DigitalTwinEngine { DigitalTwinEngine.shared }

    /// §2.3's Play-today pill, extracted from `body`. Inline it tipped the
    /// toolbar over the compiler's type-check budget — the same failure this
    /// file hit once already, and it surfaces as a timeout on `body` rather
    /// than an error where the cost actually is.
    @ViewBuilder
    private var playTodayPill: some View {
        if let total = todayDuration {
            let label = todayQueue.isPlaying
                ? "\(todayQueue.index + 1) of \(todayQueue.count)"
                : "Play today \u{00B7} \(Self.clock(total))"
            Button {
                todayQueue.toggle(in: viewContext)
                HapticManager.shared.buttonTap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: todayQueue.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(DS.Palette.sage))
            }
            .accessibilityLabel(todayQueue.isPlaying
                                ? "Stop playing today"
                                : "Play today's recordings")
        }
    }

    @ViewBuilder
    private func headerAction(_ symbol: String, _ label: String,
                              tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint ?? DS.Palette.sage)
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel(label)
    }

    static func clock(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Inline header, like every other destination. A large navigation
            // title reserved a band above the list AND insetGrouped adds its
            // own top inset to the first section — together that was the gap
            // between "Journal" and the first entry.
            HStack(spacing: 10) {
                Text("Journal")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textColor)
                Spacer(minLength: 6)
                playTodayPill
                // The toolbar actions come with the header: hiding the
                // navigation bar took search, voice and filter with it, and a
                // journal you cannot search is a worse trade than a tall title.
                // EditButton is the one casualty — swipe-to-delete still works
                // via .onDelete, so nothing became unreachable.
                headerAction("sparkle.magnifyingglass", "Search by meaning") {
                    showSemanticSearch = true
                }
                headerAction(isListening ? "mic.fill" : "mic", "Voice search",
                             tint: isListening ? theme.recordingColor : nil) {
                    toggleVoiceSearch()
                }
                headerAction(hasActiveFilters
                             ? "line.3.horizontal.decrease.circle.fill"
                             : "line.3.horizontal.decrease.circle", "Filters") {
                    withAnimation(.easeInOut(duration: 0.2)) { showFilters.toggle() }
                    HapticManager.shared.buttonTap()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 6)

            // Quick filter chips (when search is empty)
            if searchText.isEmpty && !showFilters {
                quickFilterChips
            }

            // Filter bar (when active)
            if showFilters {
                filterBar
            }
            
            // Active filters summary
            if hasActiveFilters {
                activeFiltersBar
            }
            
            // Entry list
            List {
                ForEach(sections, id: \.key) { section in
                    let key = section.key
                    let sectionEntries = section.entries
                    Section(header: HStack(alignment: .firstTextBaseline) {
                            Text(sectionTitle(for: key))
                                .font(.dsTitle2)
                                .foregroundColor(theme.textColor)
                                .textCase(nil)
                            Spacer()
                            Text(sectionSummary(for: sectionEntries))
                                .font(.dsCaption)
                                .foregroundColor(theme.secondaryTextColor)
                                .textCase(nil)
                        }
                        .padding(.top, DS.Space.xs)
                        ) {
                            ForEach(sectionEntries) { entry in
                                NavigationLink {
                                    EntryDetailView(entry: entry)
                                } label: {
                                    EntryRowView(
                                        entry: entry,
                                        searchText: searchText,
                                        dateString: entryDateString(entry)
                                    )
                                }
                            }
                            .onDelete { indexSet in
                                delete(entries: sectionEntries, at: indexSet)
                            }
                        }
                }

                // Empty state
                if filteredEntries.isEmpty {
                    emptySearchState
                }
            
                // Clearance for the floating tab bar. A List does not take
                // container padding as scroll room, so the space has to be a
                // row the list can actually scroll to — otherwise the last
                // entry stays permanently under the pill.
                Color.clear
                    .frame(height: DailyVoxTabBar.reservedHeight)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, DS.Space.xs, for: .scrollContent)
            .background { WarmBackground().ignoresSafeArea() }
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .sheet(isPresented: $showSemanticSearch) {
            SemanticSearchView()
        }
        .refreshable {
            HapticManager.shared.pullToRefresh()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Semantic search (v1.6) — find an entry by meaning.
                    Button {
                        showSemanticSearch = true
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("Search by meaning")

                    // Voice search button
                    Button {
                        toggleVoiceSearch()
                    } label: {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .foregroundColor(isListening ? theme.recordingColor : .accentColor)
                    }
                    .accessibilityLabel("Voice search")
                    
                    // Filter button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFilters.toggle()
                        }
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                    
                    EditButton()
                }
            }
            #endif
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showStarredOnly.toggle()
                    HapticManager.shared.selectionChanged()
                }) {
                    Image(systemName: showStarredOnly ? "star.fill" : "star")
                        .foregroundColor(showStarredOnly ? DS.Palette.gold : DS.Palette.sage)
                }
                .accessibilityLabel("Show starred only")
            }
        }
        .background { WarmBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { todayDuration = TodayAudioQueue.todayDuration(in: viewContext) }
        .onDisappear { todayQueue.stop() }
        #if os(iOS)
        .onChange(of: voiceSearch.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                searchText = newValue
                isListening = false
            }
        }
        #endif
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 2 {
                searchSuggestions = twin.searchSuggestions(for: trimmed)
            } else {
                searchSuggestions = []
            }
        }
        .searchSuggestions {
            ForEach(searchSuggestions, id: \.text) { suggestion in
                Button {
                    if suggestion.type == "mood" {
                        // Apply mood filter
                        if let mood = Mood(rawValue: suggestion.text.lowercased()) {
                            selectedMoodFilter = mood
                            searchText = ""
                        }
                    } else {
                        searchText = suggestion.text
                    }
                } label: {
                    Label(suggestion.text, systemImage: suggestion.icon)
                }
                .searchCompletion(suggestion.text)
            }
        }
    }
    
    // MARK: - Quick Filter Chips

    private var quickFilterChips: some View {
        let topPeople = twin.knowledgeGraph.topNodes(ofType: .person, limit: 3)
        let topTopics = twin.knowledgeGraph.topNodes(ofType: .topic, limit: 3)
        let chips = topPeople + topTopics

        return Group {
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.id) { node in
                            Button {
                                searchText = node.label
                                HapticManager.shared.selectionChanged()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: node.type == .person ? "person.fill" : "tag.fill")
                                        .font(.caption2)
                                    Text(node.label)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Mood filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Mood:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Mood.allCases.filter { $0 != .none }, id: \.self) { mood in
                        Button {
                            withAnimation {
                                if selectedMoodFilter == mood {
                                    selectedMoodFilter = nil
                                } else {
                                    selectedMoodFilter = mood
                                }
                            }
                            HapticManager.shared.selectionChanged()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mood.icon)
                                Text(mood.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedMoodFilter == mood ? mood.color.opacity(0.2) : Color(.tertiarySystemFill))
                            .foregroundColor(selectedMoodFilter == mood ? mood.color : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // Date range
            HStack(spacing: 12) {
                DateRangeButton(title: "From", date: $startDate)
                DateRangeButton(title: "To", date: $endDate)
                
                Spacer()
                
                if startDate != nil || endDate != nil {
                    Button("Clear Dates") {
                        withAnimation {
                            startDate = nil
                            endDate = nil
                        }
                        HapticManager.shared.buttonTap()
                    }
                    .font(.caption)
                    .foregroundColor(DS.Palette.coral)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Active Filters Bar
    
    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if showStarredOnly {
                    FilterChip(label: "Starred", icon: "star.fill", color: DS.Palette.gold) {
                        showStarredOnly = false
                    }
                }
                
                if let mood = selectedMoodFilter {
                    FilterChip(label: mood.rawValue, icon: mood.icon, color: mood.color) {
                        selectedMoodFilter = nil
                    }
                }
                
                if let start = startDate {
                    FilterChip(label: "From \(formatShortDate(start))", icon: "calendar", color: DS.Palette.terracotta) {
                        startDate = nil
                    }
                }
                
                if let end = endDate {
                    FilterChip(label: "To \(formatShortDate(end))", icon: "calendar", color: DS.Palette.terracotta) {
                        endDate = nil
                    }
                }
                
                if hasActiveFilters {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(DS.Palette.coral)
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No entries found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if hasActiveFilters {
                Button("Clear Filters") {
                    clearAllFilters()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Voice Search
    
    private func toggleVoiceSearch() {
        #if os(iOS)
        if isListening {
            voiceSearch.stopListening()
            isListening = false
        } else {
            voiceSearch.startListening()
            isListening = true
            HapticManager.shared.recordingStarted()
        }
        #endif
    }
    
    // MARK: - Filter Helpers
    
    private var hasActiveFilters: Bool {
        showStarredOnly || selectedMoodFilter != nil || startDate != nil || endDate != nil
    }
    
    private func clearAllFilters() {
        withAnimation {
            showStarredOnly = false
            selectedMoodFilter = nil
            startDate = nil
            endDate = nil
            searchText = ""
        }
        HapticManager.shared.buttonTap()
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Grouping

    private struct SectionKey: Hashable {
        let year: Int
        let month: Int
    }

    private var filteredEntries: [DiaryEntry] {
        entries.filter { entry in
            guard let entryDate = entry.date else { return false }
            
            // Starred filter
            if showStarredOnly && !entry.isStarred { return false }
            
            // Mood filter
            if let moodFilter = selectedMoodFilter {
                let entryMood = entry.value(forKey: "mood") as? String ?? ""
                if entryMood != moodFilter.rawValue { return false }
            }
            
            // Date range filter
            if let start = startDate {
                let startOfDay = Calendar.current.startOfDay(for: start)
                if entryDate < startOfDay { return false }
            }
            if let end = endDate {
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
                if entryDate >= endOfDay { return false }
            }
            
            // Text search
            let searchTrimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !searchTrimmed.isEmpty {
                let text = entry.text ?? ""
                if !text.localizedCaseInsensitiveContains(searchTrimmed) { return false }
            }
            
            return true
        }
    }

    /// Months, newest first, each with its entries — computed in ONE pass and
    /// read once by `body`.
    ///
    /// This replaces a `groupedEntries` dictionary and a `sectionKeys` list
    /// that were both computed properties. `sectionKeys` called
    /// `groupedEntries`, which called `filteredEntries`, which filtered the
    /// whole fetch — and then the ForEach called `groupedEntries[key]` again
    /// for EVERY section, re-running the filter, the grouping and a sort each
    /// time. At 875 entries across thirty months that is roughly 26,000 filter
    /// passes and thirty full re-groupings per render, on the main thread,
    /// while the list is scrolling.
    ///
    /// SwiftUI does not memoise computed properties. The fix is not caching —
    /// it is not asking three times.
    private var sections: [(key: SectionKey, entries: [DiaryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { (entry: DiaryEntry) -> SectionKey in
            let date = entry.date ?? Date.distantPast
            let comps = calendar.dateComponents([.year, .month], from: date)
            return SectionKey(year: comps.year ?? 0, month: comps.month ?? 0)
        }
        return groups
            .map { (key: $0.key, entries: $0.value.sorted {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }) }
            .sorted { lhs, rhs in
                if lhs.key.year != rhs.key.year { return lhs.key.year > rhs.key.year }
                return lhs.key.month > rhs.key.month
            }
    }

    private func sectionTitle(for key: SectionKey) -> String {
        var comps = DateComponents()
        comps.year = key.year
        comps.month = key.month
        let calendar = Calendar.current
        if let date = calendar.date(from: comps) {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy" // e.g. December 2025
            return formatter.string(from: date)
        }
        return "Unknown"
    }

    private func sectionSummary(for entries: [DiaryEntry]) -> String {
        let entryCount = entries.count
        let totalWords = entries.reduce(0) { total, entry in
            guard let text = entry.text, !text.isEmpty else { return total }
            return total + text.split { $0.isWhitespace || $0.isNewline }.count
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let wordsFormatted = formatter.string(from: NSNumber(value: totalWords)) ?? "\(totalWords)"
        return "\(entryCount) \(entryCount == 1 ? "entry" : "entries") · \(wordsFormatted) words"
    }

    private func entryDateString(_ entry: DiaryEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: entry.date ?? Date())
    }

    private func delete(entries: [DiaryEntry], at offsets: IndexSet) {
        // Capture the ids BEFORE deleting — a deleted managed object's `id` is
        // gone, and both derived indexes are keyed by it.
        var deletedIds: [UUID] = []
        for index in offsets {
            let entry = entries[index]
            if let id = entry.id { deletedIds.append(id) }
            viewContext.delete(entry)
        }
        do {
            try viewContext.save()
            // Detach from the derived indexes only after the delete actually
            // committed. Without this an entry the user deleted stays searchable
            // and keeps its entities attached to a row that no longer exists.
            for id in deletedIds {
                SemanticSearchManager.shared.removeEntry(id: id)
                DigitalTwinEngine.shared.forgetEntry(id.uuidString)
            }
            HapticManager.shared.entryDeleted()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // ignore for now
        }
    }
}

// MARK: - Entry Row View with Search Highlighting

struct EntryRowView: View {
    let entry: DiaryEntry
    let searchText: String
    let dateString: String
    @ObservedObject private var theme = ThemeManager.shared

    // Both grounds live in the palette now, so these come from ThemeManager.
    private var inkPrimary: Color { theme.textColor }
    private var inkMuted: Color   { theme.secondaryTextColor }

    private var wordCount: Int {
        guard let text = entry.text, !text.isEmpty else { return 0 }
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var hasPhotos: Bool {
        let jsonString = entry.value(forKey: "photoFileNames") as? String ?? ""
        return !PhotoStorageManager.parsePhotoFileNames(jsonString).isEmpty
    }

    private var moodColor: Color {
        if let moodString = entry.value(forKey: "mood") as? String,
           let mood = Mood(rawValue: moodString), mood != .none {
            return mood.color
        }
        return DS.Palette.inkMute.opacity(0.25)
    }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Mood accent — scan your journal by feeling
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(moodColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(dateString)
                        .font(.dsCaption)
                        .foregroundColor(inkMuted)

                    if let moodString = entry.value(forKey: "mood") as? String,
                       let mood = Mood(rawValue: moodString),
                       mood != .none {
                        Image(systemName: mood.icon)
                            .font(.system(.caption2).weight(.semibold))
                            .foregroundColor(mood.color)
                    }

                    if wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.dsCaption2)
                            .foregroundColor(inkMuted.opacity(0.8))
                    }

                    if hasPhotos {
                        Image(systemName: "photo")
                            .font(.system(.caption2))
                            .foregroundColor(inkMuted.opacity(0.8))
                    }
                }

                if let text = entry.text, !text.isEmpty {
                    highlightedText(text)
                        .lineLimit(2)
                } else {
                    Text("Tap to add text")
                        .font(.dsBody)
                        .foregroundColor(inkMuted)
                        .italic()
                }

                // Life area tags
                if let text = entry.text, !text.isEmpty {
                    let areas = detectLifeAreas(from: text)
                    if !areas.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(areas, id: \.self) { area in
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(area.color)
                                        .frame(width: 6, height: 6)
                                    Text(area.rawValue)
                                        .font(.dsCaption2)
                                        .foregroundColor(area.color)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(area.color.opacity(0.1)))
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if entry.isStarred {
                Image(systemName: "star.fill")
                    .foregroundColor(DS.Palette.gold)
                    .font(.system(.footnote))
            }
        }
        .padding(.vertical, DS.Space.xs)
    }

    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        if searchText.isEmpty {
            Text(text)
                .font(.dsBody)
                .foregroundColor(inkPrimary)
        } else {
            Text(attributedString(for: text))
                .font(.dsBody)
        }
    }

    private func attributedString(for text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        let searchLower = searchText.lowercased()
        let textLower = text.lowercased()

        var searchStart = textLower.startIndex
        while let range = textLower.range(of: searchLower, range: searchStart..<textLower.endIndex) {
            if let attrRange = Range(range, in: attributedString) {
                attributedString[attrRange].backgroundColor = DS.Palette.gold.opacity(0.3)
                attributedString[attrRange].foregroundColor = .primary
            }
            searchStart = range.upperBound
        }

        return attributedString
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
            Button {
                withAnimation {
                    onRemove()
                }
                HapticManager.shared.buttonTap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Date Range Button

struct DateRangeButton: View {
    let title: String
    @Binding var date: Date?
    @State private var showPicker = false
    @State private var tempDate = Date()
    
    var body: some View {
        Button {
            tempDate = date ?? Date()
            showPicker = true
            HapticManager.shared.buttonTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                if let date = date {
                    Text("\(title): \(formatDate(date))")
                        .font(.caption)
                } else {
                    Text(title)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(date != nil ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemFill))
            .foregroundColor(date != nil ? .accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NavigationView {
                DatePicker(
                    "Select Date",
                    selection: $tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            date = tempDate
                            showPicker = false
                            HapticManager.shared.selectionChanged()
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
