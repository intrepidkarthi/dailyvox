//
//  StatsView.swift
//  solyn
//
//  Writing streaks and mood trends
//

import SwiftUI
import CoreData
import Charts

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var goalManager = GoalManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var showMilestone: Int? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if entries.isEmpty {
                    emptyStateCard
                } else {
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

                    // Stats Summary
                    statsSummaryCard

                    // Weekly Summary
                    weeklySummaryCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .overlay {
            if let milestone = showMilestone {
                milestoneOverlay(days: milestone)
            }
        }
        .onAppear {
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

            Text("Insights will appear here")
                .font(.headline)

            Text("Record a few entries and DailyVox will show streaks, mood trends, and gentle summaries of your writing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Writing Streak")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Week Activity Card

    private var weekActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(last7Days, id: \.self) { date in
                    let hasEntry = hasEntryOn(date)
                    VStack(spacing: 6) {
                        Circle()
                            .fill(hasEntry ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mood Trends Card

    private var moodTrendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trends")
                .font(.headline)

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
                                .font(.title2)
                                .foregroundColor(item.mood.color)
                            Text("\(item.count)")
                                .font(.subheadline.weight(.medium))
                            Text(item.mood.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Mood chart (last 14 days)
                if #available(iOS 16.0, *) {
                    moodChart
                        .frame(height: 120)
                        .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @available(iOS 16.0, *)
    private var moodChart: some View {
        Chart {
            ForEach(moodChartData, id: \.date) { item in
                if let mood = item.mood {
                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Mood", mood.moodValue)
                    )
                    .foregroundStyle(mood.color)
                    .symbolSize(100)
                }
            }
        }
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v == 1 ? "😔" : v == 3 ? "😐" : "😊")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { value in
                AxisValueLabel(format: .dateTime.day())
            }
        }
    }

    // MARK: - Stats Summary Card

    private var statsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatItem(title: "Total Words", value: "\(totalWords)", icon: "text.word.spacing", color: .blue)
                StatItem(title: "Avg Words/Entry", value: "\(avgWordsPerEntry)", icon: "chart.bar.fill", color: .green)
                StatItem(title: "Starred", value: "\(starredCount)", icon: "star.fill", color: .yellow)
                StatItem(title: "With Audio", value: "\(audioCount)", icon: "waveform", color: .teal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - AI Insights Card

    private var aiInsightsCard: some View {
        let insights = InsightsEngine.generateInsights(from: Array(entries))

        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.teal)
                        Text("AI Insights")
                            .font(.headline)
                    }

                    ForEach(insights.prefix(3)) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.icon)
                                .font(.title3)
                                .foregroundColor(colorFromName(insight.color))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(insight.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Weekly Summary Card

    private var weeklySummaryCard: some View {
        let summary = InsightsEngine.generateWeeklySummary(from: Array(entries))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Weekly reflection")
                    .font(.headline)
            }

            Text(summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .foregroundColor(.teal)
                Text("Weekly Goal")
                    .font(.headline)
                Spacer()
                Text("\(count)/\(goalManager.weeklyTarget)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.teal)
            }

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold())
                        .foregroundColor(.teal)
                    Text("\(remaining) days left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            if progress >= 1.0 {
                Text("Goal reached! Great work this week.")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .foregroundColor(.yellow)

                Text("Milestone!")
                    .font(.largeTitle.bold())

                Text("\(days)-Day Streak")
                    .font(.title2)
                    .foregroundColor(.orange)

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
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(40)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "pink": return .pink
        case "purple": return .purple
        case "indigo": return .indigo
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
