//
//  TimelineView.swift
//  solyn
//
//  Displays all diary entries in a chronological timeline.
//  Supports search, filtering by starred entries, mood, date range, and swipe-to-delete.
//

import SwiftUI
import CoreData
#if os(iOS)
import Speech
#endif

/// Displays all diary entries grouped by month.
/// Supports search, starred filter, mood filter, date range, and pull-to-refresh.
struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    // MARK: - Search State
    
    @State private var searchText: String = ""
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

    var body: some View {
        VStack(spacing: 0) {
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
                ForEach(sectionKeys, id: \.self) { key in
                    if let sectionEntries = groupedEntries[key] {
                        Section(header: Text(sectionTitle(for: key))) {
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
                }
                
                // Empty state
                if filteredEntries.isEmpty {
                    emptySearchState
                }
            }
            .listStyle(.insetGrouped)
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .refreshable {
            HapticManager.shared.pullToRefresh()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Voice search button
                    Button {
                        toggleVoiceSearch()
                    } label: {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .foregroundColor(isListening ? .red : .accentColor)
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
                        .foregroundColor(showStarredOnly ? .yellow : .accentColor)
                }
                .accessibilityLabel("Show starred only")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Timeline")
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
                    .padding(.vertical, 8)
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
                    .foregroundColor(.red)
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
                    FilterChip(label: "Starred", icon: "star.fill", color: .yellow) {
                        showStarredOnly = false
                    }
                }
                
                if let mood = selectedMoodFilter {
                    FilterChip(label: mood.rawValue, icon: mood.icon, color: mood.color) {
                        selectedMoodFilter = nil
                    }
                }
                
                if let start = startDate {
                    FilterChip(label: "From \(formatShortDate(start))", icon: "calendar", color: .blue) {
                        startDate = nil
                    }
                }
                
                if let end = endDate {
                    FilterChip(label: "To \(formatShortDate(end))", icon: "calendar", color: .blue) {
                        endDate = nil
                    }
                }
                
                if hasActiveFilters {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.red)
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

    private var groupedEntries: [SectionKey: [DiaryEntry]] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { (entry: DiaryEntry) -> SectionKey in
            let date = entry.date ?? Date.distantPast
            let comps = calendar.dateComponents([.year, .month], from: date)
            return SectionKey(year: comps.year ?? 0, month: comps.month ?? 0)
        }
        return groups.mapValues { entries in
            entries.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }
    }

    private var sectionKeys: [SectionKey] {
        groupedEntries.keys.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.month > rhs.month
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

    private func entryDateString(_ entry: DiaryEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: entry.date ?? Date())
    }

    private func delete(entries: [DiaryEntry], at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            viewContext.delete(entry)
        }
        do {
            try viewContext.save()
            HapticManager.shared.entryDeleted()
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

    private var wordCount: Int {
        guard let text = entry.text, !text.isEmpty else { return 0 }
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var hasPhotos: Bool {
        let jsonString = entry.value(forKey: "photoFileNames") as? String ?? ""
        return !PhotoStorageManager.parsePhotoFileNames(jsonString).isEmpty
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let moodString = entry.value(forKey: "mood") as? String,
                       let mood = Mood(rawValue: moodString),
                       mood != .none {
                        Image(systemName: mood.icon)
                            .font(.caption)
                            .foregroundColor(mood.color)
                    }

                    if wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    if hasPhotos {
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                if let text = entry.text, !text.isEmpty {
                    highlightedText(text)
                        .lineLimit(2)
                } else {
                    Text("Tap to add text")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            Spacer()
            if entry.isStarred {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        if searchText.isEmpty {
            Text(text)
                .font(.subheadline)
        } else {
            Text(attributedString(for: text))
                .font(.subheadline)
        }
    }

    private func attributedString(for text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        let searchLower = searchText.lowercased()
        let textLower = text.lowercased()

        var searchStart = textLower.startIndex
        while let range = textLower.range(of: searchLower, range: searchStart..<textLower.endIndex) {
            if let attrRange = Range(range, in: attributedString) {
                attributedString[attrRange].backgroundColor = .yellow.opacity(0.3)
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
