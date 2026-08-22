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
    @Environment(\.dvTheme) private var theme
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

                    // No "AI Insights" card. "AI" is the category this product
                    // defines itself against, and EntryDetailView already
                    // removed its own copy of that card for exactly this
                    // reason: two names on one screen teach people the Twin is
                    // a skin over something generic. Its content also said what
                    // "Your Twin noticed" says, ten points further down the
                    // same scroll.

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

                    // B6: "Your Twin noticed ✦" — the list the spec puts at the
                    // bottom of Insights, and the only part of this screen that
                    // makes a claim rather than reporting a number.
                    twinNoticedSection

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
        .onAppear {
            refreshBodyInsights()
            // Reached milestones now surface as a gold line INSIDE the streak
            // card, rather than a full-screen gold trophy thrown over the
            // content before the user has read a word of it — "Milestone! Your
            // dedication to self-reflection is paying off", dismissible only by
            // tapping out. That is the gamification the design rules out, on
            // the screen most at risk of it. The haptic stays; the interrupt
            // does not. `checkMilestone` still records what has been seen, so
            // each one is marked once.
            if let milestone = goalManager.checkMilestone(currentStreak: currentStreak) {
                HapticManager.shared.streakMilestone()
                withAnimation(.easeOut(duration: 0.4)) {
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
                    .font(.dv(size: 32))
                    .foregroundColor(.accentColor)
            }

            Text("Your patterns will appear here")
                .font(.dv(.headline, design: .rounded))

            Text("Record a few entries and DailyVox will show streaks, mood trends, and gentle summaries of your writing.")
                .font(.dv(.subheadline))
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
                    .font(.dv(.title2))
                    .foregroundColor(DS.Palette.terracotta)
                Text("Writing Streak")
                    .font(.dv(.headline, design: .rounded))
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(currentStreak)")
                    .font(.dv(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.terracotta)
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.dv(.title3))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                Spacer()
            }

            // The milestone, where it belongs: one gold line on the card that
            // is already about the streak. Gold rewards.
            if let milestone = showMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.dv(.caption, weight: .semibold))
                    Text("\(milestone) days. That is a habit now.")
                        .font(.dv(size: 13, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                }
                .foregroundColor(DS.Palette.gold)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.Palette.gold.opacity(0.12))
                )
            }

            // Streak info
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Longest")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                    Text("\(longestStreak) days")
                        .font(.dv(.subheadline, weight: .medium))
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading) {
                    Text("This Month")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                    Text("\(entriesThisMonth) entries")
                        .font(.dv(.subheadline, weight: .medium))
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading) {
                    Text("Total")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                    Text("\(entries.count) entries")
                        .font(.dv(.subheadline, weight: .medium))
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
                .font(.dv(.headline, design: .rounded))

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
                                        .font(.dv(.caption, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        Text(dayAbbreviation(date))
                            .font(.dv(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .dsCard()
    }

    // MARK: - Your Twin noticed

    @ViewBuilder
    private var twinNoticedSection: some View {
        let patterns = TwinPatterns.find(
            Array(entries),
            people: DigitalTwinEngine.shared.knowledgeGraph
                .topNodes(ofType: .person, limit: 6)
                .map(\.label)
        )

        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR TWIN NOTICED \u{2726}")
                .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(ThemeManager.shared.secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            if patterns.isEmpty {
                Text("Not enough yet. Patterns appear once there is enough to be sure one is real rather than a coincidence.")
                    .font(.dv(.subheadline))
                    .foregroundColor(ThemeManager.shared.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ThemeManager.shared.cardBackgroundColor))
            } else {
                ForEach(patterns) { pattern in
                    HStack(alignment: .top, spacing: 11) {
                        // A tinted square with the four-point mark, matching
                        // Android's list exactly — gold, because a pattern is
                        // something the journal MADE.
                        Text("\u{2726}")
                            .font(.dv(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(ThemeManager.shared.goldText)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(DS.Palette.gold.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pattern.lead)
                                .font(.dv(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(ThemeManager.shared.textColor)
                            Text(pattern.detail)
                                .font(.dv(size: 13))
                                .foregroundColor(ThemeManager.shared.secondaryTextColor)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ThemeManager.shared.cardBackgroundColor))
                }
            }
        }
    }

    // MARK: - Mood Trends Card

    private var moodTrendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mood Trends")
                    .font(.dv(.headline, design: .rounded))
                Spacer()
                // §2.7's delta badge. Stated against the fortnight BEFORE, so it
                // answers "compared to what" instead of leaving the reader to
                // guess — a bare arrow is a mood ring, not a measurement.
                if let d = moodDelta {
                    Text("\(d >= 0 ? "\u{25B2}" : "\u{25BC}") \(String(format: "%+.1f", d))")
                        .font(.dv(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(d >= 0 ? ThemeManager.shared.goldText : DS.Palette.coral)
                }
            }

            if moodData.isEmpty {
                Text("Record entries with moods to see trends")
                    .font(.dv(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Mood distribution
                HStack(spacing: 12) {
                    ForEach(topMoods, id: \.mood) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.mood.icon)
                                .font(.dv(.body, weight: .semibold))
                                .foregroundColor(item.mood.color)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(item.mood.color.opacity(0.14))
                                )
                            Text("\(item.count)")
                                .font(.dv(.title3, design: .rounded, weight: .bold))
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
                    .font(.dv(.headline, design: .rounded))
            }

            ForEach(bodyInsights) { insight in
                HStack(alignment: .top, spacing: DS.Space.md) {
                    Image(systemName: bodyInsightIcon(insight.kind))
                        .font(.dv(.subheadline, weight: .semibold))
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
                .font(.dv(.headline, design: .rounded))

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


    // MARK: - Weekly Summary Card

    private var weeklySummaryCard: some View {
        let summary = InsightsEngine.generateWeeklySummary(from: entries.map(\.twinInput))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.accentColor)
                Text("Weekly reflection")
                    .font(.dv(.headline, design: .rounded))
            }

            Text(summary)
                .font(.dv(.subheadline))
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
                    .font(.dv(.title2))
                    .foregroundColor(theme.accentColor)
                Text("Weekly Goal")
                    .font(.dv(.headline, design: .rounded))
                Spacer()
                Text("\(count)/\(goalManager.weeklyTarget)")
                    .font(.dv(.subheadline, weight: .medium))
                    .foregroundColor(theme.accentColor)
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
                        .font(.dv(.title2, weight: .bold))
                        .foregroundColor(theme.accentColor)
                    Text("\(remaining) days left")
                        .font(.dv(.caption2))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            if progress >= 1.0 {
                Text("Goal reached! Great work this week.")
                    .font(.dv(.caption))
                    .foregroundColor(DS.Palette.forest)
            }
        }
        .dsCard()
    }

    // MARK: - Milestone Overlay


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

    // Both streaks go through `Streak` now. Insights was the one screen that
    // had the rule RIGHT, and it still had its own copy of it — which is how
    // the Record tab's wrong copy survived unnoticed.
    private var currentStreak: Int {
        Streak.current(days: entryDays)
    }

    private var longestStreak: Int {
        Streak.longest(days: entryDays)
    }

    private var entryDays: Set<Date> {
        Set(entries.compactMap { $0.date }.map { Calendar.current.startOfDay(for: $0) })
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

    /// Last fortnight against the one before it, on the 1–5 mood scale remapped
    /// to −1…1. Nil until BOTH windows have three entries: a delta computed
    /// from one day on either side is noise wearing a decimal point.
    private var moodDelta: Double? {
        let cal = Calendar.current
        let now = Date()
        guard let cutoff = cal.date(byAdding: .day, value: -14, to: now),
              let priorStart = cal.date(byAdding: .day, value: -28, to: now)
        else { return nil }

        func mean(_ window: [(date: Date, mood: Mood?)]) -> Double? {
            let values = window.compactMap { $0.mood }.map { (Double($0.moodValue) - 3) / 2 }
            guard values.count >= 3 else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        let all = moodChartData
        let recent = all.filter { $0.date >= cutoff }
        let prior = all.filter { $0.date < cutoff && $0.date >= priorStart }
        guard let r = mean(recent), let p = mean(prior) else { return nil }
        return r - p
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
                .font(.dv(.subheadline, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.14))
                )
            Text(value)
                .font(.dv(size: 26, weight: .bold, design: .rounded))
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
