//
//  StatsView.swift
//  solyn
//
//  Writing streaks and mood trends
//

import SwiftUI
import DailyVoxTwinEngine
import CoreData

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var goalManager = GoalManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var showMilestone: Int? = nil

    /// Embodied insights, computed off the render path in onAppear — the
    /// correlation math must never run inside body (Twin-perf lesson).
    @State private var bodyInsights: [BodyInsight] = []

    /// Cache key for `bodyInsights`: recompute only when the calendar day or
    /// the kept-snapshot count changes, so tab-switching to Insights never
    /// re-walks a multi-year history for the same answer.
    @State private var bodyInsightsKey: BodyInsightsCacheKey?

    private struct BodyInsightsCacheKey: Equatable {
        let day: Date
        let keptCount: Int
    }

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if entries.isEmpty {
                    emptyStateCard
                } else {
                    // Shareable Weekly Insights
                    WeeklyInsightsSection(entries: Array(entries))

                    // AI Insights
                    aiInsightsCard

                    // Streak Card
                    streakCard

                    // Goal Progress Card
                    if goalManager.isEnabled {
                        goalProgressCard
                    }

                    // This Week Activity
                    weekActivityCard

                    // Mood Trends
                    moodTrendsCard

                    // Body & Mood — absent entirely until honest patterns exist
                    if !bodyInsights.isEmpty {
                        bodyCorrelationsCard
                    }

                    // Stats Summary
                    statsSummaryCard

                    // Weekly Summary
                    weeklySummaryCard
                }
            }
            .padding()
            .frame(maxWidth: isIPad ? 700 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background { WarmBackground() }
        .navigationTitle("Insights")
        .overlay {
            if let milestone = showMilestone {
                milestoneOverlay(days: milestone)
            }
        }
        .onAppear {
            refreshBodyInsights()
            if let milestone = goalManager.checkMilestone(currentStreak: currentStreak) {
                HapticManager.shared.streakMilestone()
                withAnimation(.spring(response: 0.5)) {
                    showMilestone = milestone
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            }

            Text("Your patterns will appear here")
                .font(.system(.headline, design: .rounded))

            Text("Record a few entries and DailyVox will show streaks, mood trends, and gentle summaries of your writing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(DS.Palette.terracotta)
                Text("Writing Streak")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.terracotta)
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                Spacer()
            }

            // Streak info
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Longest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(longestStreak) days")
                        .font(.subheadline.weight(.medium))
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entriesThisMonth) entries")
                        .font(.subheadline.weight(.medium))
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entries.count) entries")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()
            }
        }
        .dsCard()
    }

    // MARK: - Week Activity Card

    private var weekActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 8) {
                ForEach(last7Days, id: \.self) { date in
                    let hasEntry = hasEntryOn(date)
                    VStack(spacing: 6) {
                        Circle()
                            .fill(hasEntry ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: isIPad ? 44 : 32, height: isIPad ? 44 : 32)
                            .overlay {
                                if hasEntry {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                        Text(dayAbbreviation(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .dsCard()
    }

    // MARK: - Mood Trends Card

    private var moodTrendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trends")
                .font(.system(.headline, design: .rounded))

            if moodData.isEmpty {
                Text("Record entries with moods to see trends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Mood distribution
                HStack(spacing: 12) {
                    ForEach(topMoods, id: \.mood) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.mood.icon)
                                .font(.system(.body).weight(.semibold))
                                .foregroundColor(item.mood.color)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(item.mood.color.opacity(0.14))
                                )
                            Text("\(item.count)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(item.mood.color)
                            Text(item.mood.displayName)
                                .font(.dsCaption)
                                .foregroundColor(DS.Palette.inkMute)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Mood over the last 14 days
                moodStrip
                    .padding(.top, DS.Space.sm)
            }
        }
        .dsCard()
    }

    /// Compact 14-day mood strip — bar height by valence, color by mood, faint dot
    /// for days with no entry. Reads as an intentional trend even with sparse data.
    private var moodStrip: some View {
        let maxH: CGFloat = 66
        return VStack(spacing: DS.Space.xs) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(moodChartData, id: \.date) { item in
                    ZStack(alignment: .bottom) {
                        Color.clear.frame(height: maxH)
                        if let mood = item.mood {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [mood.color, mood.color.opacity(0.75)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: max(12, maxH * CGFloat(mood.moodValue) / 5.0))
                        } else {
                            Circle()
                                .fill(DS.Palette.inkMute.opacity(0.18))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("2 weeks ago").font(.dsCaption2).foregroundColor(DS.Palette.inkMute)
                Spacer()
                Text("Today").font(.dsCaption2).foregroundColor(DS.Palette.inkMute)
            }
        }
    }

    // MARK: - Body & Mood Card

    /// Patterns between the body signals the user chose to keep and how the
    /// same days felt. The engine (BodyCorrelations) stays silent below 14
    /// paired days or |r| < 0.35, so this card only ever shows real patterns —
    /// and the card itself disappears when there are none.
    private var bodyCorrelationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(DS.Palette.terracotta)
                Text("Body & Mood")
                    .font(.system(.headline, design: .rounded))
            }

            ForEach(bodyInsights) { insight in
                HStack(alignment: .top, spacing: DS.Space.md) {
                    Image(systemName: bodyInsightIcon(insight.kind))
                        .font(.system(.subheadline).weight(.semibold))
                        .foregroundColor(bodyInsightColor(insight.kind))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(bodyInsightColor(insight.kind).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(bodyInsightTitle(insight))
                            .font(.dsHeadline)
                        Text(bodyInsightDescription(insight))
                            .font(.dsCaption)
                            .foregroundColor(DS.Palette.inkMute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Text("Patterns from the body signals you chose to keep — a noticing, not a prescription.")
                .font(.dsCaption2)
                .foregroundColor(DS.Palette.inkMute)
        }
        .dsCard()
    }

    /// Feeds kept snapshots + the per-day mood series into the engine.
    ///
    /// Cached and computed off-main: for a Body Twin user with years of
    /// history this walks every entry (Calendar.startOfDay dominates) plus
    /// every kept snapshot — tens of ms that must not ride the tab-switch
    /// frame on every Insights visit. Only the raw (date, mood) pairs are
    /// gathered on the main actor (managed objects are not thread-safe);
    /// the day-bucketing and Pearson math run at utility QoS.
    private func refreshBodyInsights() {
        let kept = KeptSnapshotStore.shared.loadAll()
        guard !kept.isEmpty else {
            bodyInsights = []
            bodyInsightsKey = nil
            return
        }

        let key = BodyInsightsCacheKey(day: Calendar.current.startOfDay(for: Date()),
                                       keptCount: kept.count)
        guard key != bodyInsightsKey else { return }
        bodyInsightsKey = key

        // Main-thread extraction only — no Core Data access off-main.
        let moodPairs: [(date: Date, mood: String)] = entries.compactMap { entry in
            guard let date = entry.date,
                  let moodString = entry.value(forKey: "mood") as? String else { return nil }
            return (date, moodString)
        }
        let snapshots = kept.map(\.snapshot)

        Task.detached(priority: .utility) {
            // Mood valence (1–5) per calendar day, real moods only — `.none`
            // is a placeholder, not a reading, and would flatten every
            // correlation. First entry in fetch order (newest) wins a day.
            let calendar = Calendar.current
            var moodByDay: [Date: Double] = [:]
            for pair in moodPairs {
                guard let mood = Mood(rawValue: pair.mood), mood != .none else { continue }
                let day = calendar.startOfDay(for: pair.date)
                if moodByDay[day] == nil { moodByDay[day] = Double(mood.moodValue) }
            }
            let result = BodyCorrelations.compute(snapshots: snapshots, moodByDay: moodByDay)
            await MainActor.run { bodyInsights = result }
        }
    }

    private func bodyInsightIcon(_ kind: BodyInsight.Kind) -> String {
        switch kind {
        case .sleepAndMood: return "moon.zzz.fill"
        case .stepsAndMood: return "figure.walk"
        case .hrvAndMood: return "waveform.path.ecg"
        }
    }

    /// Same signal→color mapping as the review sheet, invite sheet, and
    /// Settings → Health: sleep is sage, steps gold, HRV terracotta.
    private func bodyInsightColor(_ kind: BodyInsight.Kind) -> Color {
        switch kind {
        case .sleepAndMood: return DS.Palette.sage
        case .stepsAndMood: return DS.Palette.gold
        case .hrvAndMood: return DS.Palette.terracotta
        }
    }

    private func bodyInsightTitle(_ insight: BodyInsight) -> String {
        switch insight.kind {
        case .sleepAndMood:
            return insight.movesTogether
                ? "Rest and brightness rise together"
                : "Your sleep writes its own pattern"
        case .stepsAndMood:
            return insight.movesTogether
                ? "Moving days glow a little brighter"
                : "Your stiller days glow brighter"
        case .hrvAndMood:
            return insight.movesTogether
                ? "Your calm shows in your morning rhythm"
                : "Your morning rhythm runs its own way"
        }
    }

    /// The two group means tell the pattern honestly in either direction.
    private func bodyInsightDescription(_ insight: BodyInsight) -> String {
        let days = "across \(insight.sampleDays) days"
        switch insight.kind {
        case .sleepAndMood:
            let bright = String(format: "%.1f", insight.signalMeanOnBrighterDays)
            let dim = String(format: "%.1f", insight.signalMeanOnDimmerDays)
            return "Your brighter days followed about \(bright)h of sleep; dimmer ones about \(dim)h — \(days)."
        case .stepsAndMood:
            let bright = Int(insight.signalMeanOnBrighterDays).formatted()
            let dim = Int(insight.signalMeanOnDimmerDays).formatted()
            return "Brighter days carried around \(bright) steps; dimmer ones around \(dim) — \(days)."
        case .hrvAndMood:
            let bright = Int(insight.signalMeanOnBrighterDays.rounded())
            let dim = Int(insight.signalMeanOnDimmerDays.rounded())
            return "Morning rhythm (HRV) averaged \(bright) ms on brighter days and \(dim) ms on dimmer ones — \(days)."
        }
    }

    // MARK: - Stats Summary Card

    private var statsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing Stats")
                .font(.system(.headline, design: .rounded))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 4 : 2), spacing: 16) {
                StatItem(title: "Total Words", value: "\(totalWords)", icon: "text.word.spacing", color: DS.Palette.sage)
                StatItem(title: "Avg Words/Entry", value: "\(avgWordsPerEntry)", icon: "chart.bar.fill", color: DS.Palette.forest)
                StatItem(title: "Starred", value: "\(starredCount)", icon: "star.fill", color: DS.Palette.gold)
                StatItem(title: "With Audio", value: "\(audioCount)", icon: "waveform", color: DS.Palette.terracotta)
            }
        }
        .dsCard()
    }

    // MARK: - AI Insights Card

    private var aiInsightsCard: some View {
        let insights = InsightsEngine.generateInsights(from: entries.map(\.twinInput))

        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(DS.Palette.gold)
                        Text("AI Insights")
                            .font(.system(.headline, design: .rounded))
                    }

                    ForEach(insights.prefix(3)) { insight in
                        HStack(alignment: .top, spacing: DS.Space.md) {
                            Image(systemName: insight.icon)
                                .font(.system(.subheadline).weight(.semibold))
                                .foregroundColor(colorFromName(insight.color))
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(colorFromName(insight.color).opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.dsHeadline)
                                Text(insight.description)
                                    .font(.dsCaption)
                                    .foregroundColor(DS.Palette.inkMute)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .dsCard()
            }
        }
    }

    // MARK: - Weekly Summary Card

    private var weeklySummaryCard: some View {
        let summary = InsightsEngine.generateWeeklySummary(from: entries.map(\.twinInput))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(DS.Palette.sage)
                Text("Weekly reflection")
                    .font(.system(.headline, design: .rounded))
            }

            Text(summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .dsCard()
    }

    // MARK: - Goal Progress Card

    private var goalProgressCard: some View {
        let progress = goalManager.progressThisWeek(from: Array(entries))
        let count = goalManager.entriesThisWeek(from: Array(entries))
        let remaining = goalManager.daysRemainingInWeek()

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundColor(DS.Palette.sage)
                Text("Weekly Goal")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text("\(count)/\(goalManager.weeklyTarget)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DS.Palette.sage)
            }

            ZStack {
                Circle()
                    .stroke(DS.Palette.inkMute.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.Palette.sage, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold())
                        .foregroundColor(DS.Palette.sage)
                    Text("\(remaining) days left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            if progress >= 1.0 {
                Text("Goal reached! Great work this week.")
                    .font(.caption)
                    .foregroundColor(DS.Palette.forest)
            }
        }
        .dsCard()
    }

    // MARK: - Milestone Overlay

    private func milestoneOverlay(days: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showMilestone = nil
                    }
                }

            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DS.Palette.gold)

                Text("Milestone!")
                    .font(.largeTitle.bold())

                Text("\(days)-Day Streak")
                    .font(.title2)
                    .foregroundColor(DS.Palette.gold)

                Text("You've journaled for \(days) consecutive days. Your dedication to self-reflection is paying off.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Keep Going") {
                    withAnimation {
                        showMilestone = nil
                    }
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(DS.Palette.sage)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 20)
            .padding(40)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "orange": return DS.Palette.terracotta  // terracotta
        case "green": return DS.Palette.forest   // forest green
        case "blue": return DS.Palette.sage    // sage green
        case "yellow": return DS.Palette.gold  // warm gold
        case "pink": return DS.Palette.terracotta    // dusty rose
        case "purple": return DS.Palette.terracotta  // muted plum
        case "indigo": return DS.Palette.starBlue  // twilight blue
        default: return .secondary
        }
    }

    // MARK: - Computed Properties

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's an entry today
        if !hasEntryOn(checkDate) {
            // Check yesterday - streak might still be active
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            if !hasEntryOn(checkDate) {
                return 0
            }
        }

        // Count consecutive days
        while hasEntryOn(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = entries.compactMap { $0.date }.map { calendar.startOfDay(for: $0) }
        let uniqueDates = Set(sortedDates).sorted(by: >)

        guard !uniqueDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<uniqueDates.count {
            let diff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i-1]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    private var entriesThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }.count
    }

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private func hasEntryOn(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.isDate(entryDate, inSameDayAs: date)
        }
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }

    private var moodData: [(mood: Mood, count: Int)] {
        var counts: [Mood: Int] = [:]
        for entry in entries {
            if let moodString = entry.value(forKey: "mood") as? String,
               let mood = Mood(rawValue: moodString),
               mood != .none {
                counts[mood, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    private var topMoods: [(mood: Mood, count: Int)] {
        Array(moodData.prefix(4))
    }

    private var moodChartData: [(date: Date, mood: Mood?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<14).compactMap { offset -> (Date, Mood?)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let entry = entries.first { entry in
                guard let entryDate = entry.date else { return false }
                return calendar.isDate(entryDate, inSameDayAs: date)
            }
            let mood: Mood?
            if let moodString = entry?.value(forKey: "mood") as? String {
                mood = Mood(rawValue: moodString)
            } else {
                mood = nil
            }
            return (date, mood)
        }.reversed()
    }

    private var totalWords: Int {
        entries.reduce(0) { total, entry in
            let text = entry.text ?? ""
            return total + text.split { $0.isWhitespace || $0.isNewline }.count
        }
    }

    private var avgWordsPerEntry: Int {
        guard entries.count > 0 else { return 0 }
        return totalWords / entries.count
    }

    private var starredCount: Int {
        entries.filter { $0.isStarred }.count
    }

    private var audioCount: Int {
        entries.filter { entry in
            let fileName = entry.value(forKey: "audioFileName") as? String
            return fileName != nil && !fileName!.isEmpty
        }.count
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.14))
                )
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.dsCaption)
                .foregroundColor(DS.Palette.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(ThemeManager.shared.warmSubtleFill)
        )
    }
}

// MARK: - Mood Extension for Chart

extension Mood {
    var moodValue: Int {
        switch self {
        case .happy, .excited, .grateful: return 5
        case .calm: return 4
        case .tired: return 3
        case .anxious: return 2
        case .sad, .angry: return 1
        case .none: return 3
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
