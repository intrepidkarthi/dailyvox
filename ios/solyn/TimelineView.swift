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
/// B3's four filter chips: All · People · Mood · Body.
///
/// The screen already had filters — starred, a mood picker, a date range — but
/// not THESE, and the difference is not cosmetic. The spec's four are the four
/// dimensions the Twin files against, so the chips double as a statement of what
/// it is paying attention to. Mood-by-mood pickers answer "show me the sad
/// ones"; these answer "show me the ones with people in".
enum JournalFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case people = "People"
    case mood = "Mood"
    case body = "Body"

    var id: String { rawValue }
}

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dailyVoxKeyboardVisible) private var keyboardVisible
    @State private var showShareSheet = false
    /// Search is opened, not always present.
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool

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
    @State private var journalFilter: JournalFilter = .all
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
                        .font(.dv(size: 10, weight: .bold))
                    Text(label)
                        .font(.dv(size: 12, weight: .bold, design: .rounded))
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
                .font(.dv(size: 16, weight: .semibold))
                // `theme.accentColor`, not a pinned `sage`. Forest green on navy
                // is the exact combination §1 says has no presence — these three
                // icons were nearly invisible at night — and the grammar's own
                // exception covers it: at night gold is the actor.
                .foregroundColor(tint ?? theme.accentColor)
                // 30pt was under the 44pt floor, on the same row as the title.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    .font(.dv(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textColor)
                Spacer(minLength: 6)
                playTodayPill
                // The toolbar actions come with the header: hiding the
                // navigation bar took search, voice and filter with it, and a
                // journal you cannot search is a worse trade than a tall title.
                // EditButton is the one casualty — swipe-to-delete still works
                // via .onDelete, so nothing became unreachable.
                headerAction(showSearch ? "magnifyingglass.circle.fill" : "magnifyingglass",
                             showSearch ? "Close search" : "Search what you meant") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        showSearch.toggle()
                    }
                    if !showSearch { searchText = "" }
                    searchFocused = showSearch
                    HapticManager.shared.buttonTap()
                }
                // §F reaches the Journal as well. Three surfaces now offer a
                // card — an entry, the sky, and the timeline — instead of one
                // corner of one tab.
                headerAction("square.and.arrow.up", "Share a card") {
                    showShareSheet = true
                }
                // Kept always visible. Hiding it unless a filter was already
                // on would have made mood and date filters unreachable — the
                // chips filter, they do not open anything — and losing function
                // to save one glyph is a bad trade. The duplication worth fixing
                // is that Mood should open the mood row itself; that is a real
                // change, not a deletion.
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

            // On demand. You browse constantly and search occasionally, so the
            // field earned its permanent band only while it was also teaching
            // the feature.
            //
            // The teaching still happens, in the one place it has to: the
            // placeholder still reads "Describe it — search what you meant", so
            // opening search explains itself the first time. What is NOT
            // repeated is the earlier mistake — the glyph that opens this is
            // labelled for VoiceOver and there is no second, competing search
            // anywhere in the app.
            if searchIsActive {
                searchField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // No chip row.
            //
            // All / People / Mood / Body was the least-used band on the screen
            // and it duplicated the field above it with less precision — typing
            // a name beats tapping People and then scanning. "All" gave it away:
            // a control whose job is to represent the absence of a control.
            //
            // Filtering still exists, through the glyph in the header, which is
            // where an occasional action belongs. `specFilterChips` is kept
            // below in case this is worth reversing.

            // The entity chip row is gone. It was a SECOND filter bar directly
            // under the first — six names at the same visual weight as All /
            // People / Mood / Body, with nothing to say they were a different
            // kind of thing. Title, search field, two chip rows and a month
            // header meant a third of the screen went by before a word of
            // journal.
            //
            // Nothing is lost: each chip only typed its own label into the
            // search box, and the search box is now a field you can type in.

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
                    // A quiet mono rule, not a headline with statistics beside
                    // it. The canvas has no month headers at all; they earn
                    // their place on a journal this long, but as a divider you
                    // scan past — not a second title competing with "Journal"
                    // and a per-month word count nobody asked for.
                    Section(header:
                            Text(sectionTitle(for: key).uppercased())
                                .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(1.3)
                                .foregroundColor(theme.secondaryTextColor)
                                .textCase(nil)
                                .padding(.top, DS.Space.xs)
                        ) {
                            ForEach(sectionEntries) { entry in
                                // ZStack + opacity-0 link rather than a plain
                                // NavigationLink: in a List a NavigationLink
                                // draws a disclosure chevron on every row, and
                                // the canvas has none. A chevron on every entry
                                // of a journal is 137 arrows telling you what
                                // tapping already tells you.
                                ZStack {
                                    NavigationLink {
                                        EntryDetailView(entry: entry)
                                    } label: { EmptyView() }
                                        .opacity(0)

                                    EntryRowView(
                                        entry: entry,
                                        searchText: searchText,
                                        dateString: entryDateString(entry)
                                    )
                                }
                                .listRowSeparator(.hidden)
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
                    .frame(height: keyboardVisible ? 0 : DailyVoxTabBar.reservedHeight)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, DS.Space.xs, for: .scrollContent)
            .background { WarmBackground().ignoresSafeArea() }
        }
        // `.searchable` is gone — it was the SECOND search on this screen, and
        // the one that got the discoverable position while meaning-search hid
        // behind an icon. `searchField` above is now the only one.
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView().appThemedSheet()
        }
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
        .dailyVoxStatusBarScrim()
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
                                        .font(.dv(.caption2))
                                    Text(node.label)
                                        .font(.dv(.caption))
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.dv(size: 15, weight: .semibold))
                .foregroundColor(theme.secondaryTextColor)

            TextField("", text: $searchText, prompt:
                Text("Describe it — search what you meant")
                    .foregroundColor(theme.secondaryTextColor)
            )
            .font(.dv(size: 15))
            .foregroundColor(theme.textColor)
            .focused($searchFocused)
            .submitLabel(.search)
            .onSubmit { if !searchText.isEmpty { showSemanticSearch = true } }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.dv(size: 15))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            // Voice search lives IN the field now. It was a separate header
            // glyph competing with two others; here it is obviously part of the
            // thing it fills in.
            Button { toggleVoiceSearch() } label: {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.dv(size: 15, weight: .semibold))
                    .foregroundColor(isListening ? theme.recordingColor : theme.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search by voice")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        // 44, not 48. It was sized as the first of two stacked bands; alone
        // above the entries it can sit closer to the title.
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.warmSubtleFill)
        )
        .padding(.horizontal)
    }

    private var specFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(JournalFilter.allCases) { filter in
                    let on = journalFilter == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            journalFilter = filter
                        }
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text(filter.rawValue)
                            .font(.dv(size: 11.5, weight: on ? .heavy : .bold, design: .rounded))
                            // Green tint, per §1: these select, they do not
                            // reward, so gold would be the wrong colour.
                            .foregroundColor(on
                                ? (theme.isNight ? DS.Palette.navy : Color.white)
                                : theme.secondaryTextColor)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .frame(minHeight: 34)
                            .background(
                                Capsule().fill(on
                                    ? theme.accentColor
                                    : theme.warmSubtleFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.horizontal)
        }
    }

    /// People the graph knows, lowercased once rather than per entry.
    private var knownPeople: [String] {
        DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .person, limit: 40)
            .map { $0.label.lowercased() }
            .filter { !$0.isEmpty }
    }

    /// Days on which the user kept a body snapshot. Matching by CALENDAR DAY
    /// rather than by id: body signals are a property of the day an entry was
    /// spoken, and they are captured on their own schedule, not per entry.
    private var bodyDays: Set<Date> {
        Set(KeptSnapshotStore.shared.loadAll().map {
            Calendar.current.startOfDay(for: $0.keptAt)
        })
    }

    private func matchesJournalFilter(_ entry: DiaryEntry) -> Bool {
        switch journalFilter {
        case .all:
            return true
        case .people:
            let text = (entry.text ?? "").lowercased()
            guard !text.isEmpty else { return false }
            return knownPeople.contains { text.contains($0) }
        case .mood:
            let mood = entry.value(forKey: "mood") as? String ?? ""
            return !mood.isEmpty && mood != Mood.none.rawValue
        case .body:
            guard let date = entry.date else { return false }
            return bodyDays.contains(Calendar.current.startOfDay(for: date))
        }
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Mood filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Mood:")
                        .font(.dv(.caption))
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
                            .font(.dv(.caption))
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
                    .font(.dv(.caption))
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
                    .font(.dv(.caption, weight: .medium))
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
                .font(.dv(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No entries found")
                .font(.dv(.headline))
                .foregroundColor(.secondary)
            
            if hasActiveFilters {
                Button("Clear Filters") {
                    clearAllFilters()
                }
                .font(.dv(.subheadline))
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

    /// Search stays open while a query is live, so a filtered list can never be
    /// showing results with nothing on screen to say why.
    private var searchIsActive: Bool { showSearch || !searchText.isEmpty }

    private var filteredEntries: [DiaryEntry] {
        entries.filter { entry in
            guard let entryDate = entry.date else { return false }
            
            // B3's chips first — they are the coarse cut.
            if !matchesJournalFilter(entry) { return false }

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

    /// "TONIGHT · 2M 05 · 58 WORDS".
    ///
    /// Relative where relative is more useful than exact — you know what today
    /// was — and it carries the DURATION, which the row never showed. In a voice
    /// journal how long you spoke is a fact about the entry, not metadata.
    private var metaLine: String {
        var parts: [String] = [relativeDay]
        if entry.duration > 0 {
            let total = Int(entry.duration.rounded())
            parts.append(total >= 60
                         ? String(format: "%dM %02d", total / 60, total % 60)
                         : "0:\(String(format: "%02d", total))")
        }
        if wordCount > 0 { parts.append("\(wordCount) WORDS") }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var relativeDay: String {
        guard let date = entry.date else { return dateString.uppercased() }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TONIGHT" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        // Within the last week, the weekday alone locates it.
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                         to: cal.startOfDay(for: Date())).day, days < 7 {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: date).uppercased()
        }
        return dateString.uppercased()
    }

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
            // A hairline. At 4pt against a white card it read as a border on
            // every row; its job is to be noticed while scanning, not while
            // reading.
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(moodColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 5) {
                // B3's meta line: one DM Mono run, uppercase and tracked —
                // "TONIGHT · 2M 05 · 58 WORDS". It was body-size mixed type with
                // a coloured mood glyph in the middle of it, which read as a
                // sentence rather than as data.
                HStack(spacing: 6) {
                    Text(metaLine)
                        .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(inkMuted)

                    if hasPhotos {
                        Image(systemName: "photo")
                            .font(.dv(.caption2))
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
                // The app's four-point mark, not SF's five-point rating star —
                // "gold ✦ = starred" is the spec's own wording, and it is the
                // same glyph the sky and the share cards draw.
                Text("\u{2726}")
                    .font(.dv(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.gold)
                    .accessibilityLabel("Starred")
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
                .font(.dv(.caption2))
            Text(label)
                .font(.dv(.caption))
            Button {
                withAnimation {
                    onRemove()
                }
                HapticManager.shared.buttonTap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.dv(.caption))
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
                    .font(.dv(.caption))
                if let date = date {
                    Text("\(title): \(formatDate(date))")
                        .font(.dv(.caption))
                } else {
                    Text(title)
                        .font(.dv(.caption))
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
