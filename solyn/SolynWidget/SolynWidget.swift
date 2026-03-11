//
//  DailyVoxWidget.swift
//  DailyVoxWidget
//
//  Voice diary widgets for quick access, streak tracking, and mood display.
//

import WidgetKit
import SwiftUI
import CoreData
import os.log

private let logger = Logger(subsystem: "com.dailyvox.app.widget", category: "SolynWidget")

// MARK: - Shared Data Fetcher

struct WidgetDataFetcher {
    static let shared = WidgetDataFetcher()
    let persistenceController = WidgetPersistenceController.shared
    
    /// Fetch today's entry
    func fetchTodayEntry() -> (text: String?, mood: String?, hasEntry: Bool) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let entry = results.first {
                let text = entry.value(forKey: "text") as? String
                let moodString = entry.value(forKey: "mood") as? String
                return (text, moodString, true)
            }
        } catch {
            logger.error("Widget fetch error: \(error.localizedDescription)")
        }
        
        return (nil, nil, false)
    }
    
    /// Calculate current streak
    func calculateStreak() -> Int {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let entries = try context.fetch(request)
            let calendar = Calendar.current
            var streak = 0
            var checkDate = calendar.startOfDay(for: Date())
            
            // Check if today has an entry
            let todayHasEntry = entries.contains { entry in
                guard let entryDate = entry.value(forKey: "date") as? Date else { return false }
                return calendar.isDate(entryDate, inSameDayAs: checkDate)
            }
            
            if !todayHasEntry {
                // Start checking from yesterday
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            
            // Count consecutive days
            while true {
                let hasEntry = entries.contains { entry in
                    guard let entryDate = entry.value(forKey: "date") as? Date else { return false }
                    return calendar.isDate(entryDate, inSameDayAs: checkDate)
                }
                
                if hasEntry {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }
            
            return streak
        } catch {
            return 0
        }
    }
    
    /// Get mood distribution for the week
    func getWeekMoods() -> [String: Int] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        request.predicate = NSPredicate(format: "date >= %@", weekAgo as NSDate)
        
        do {
            let entries = try context.fetch(request)
            var moodCounts: [String: Int] = [:]
            
            for entry in entries {
                if let mood = entry.value(forKey: "mood") as? String, !mood.isEmpty {
                    moodCounts[mood, default: 0] += 1
                }
            }
            
            return moodCounts
        } catch {
            return [:]
        }
    }
    
    /// Get total entry count
    func getTotalEntries() -> Int {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
}

// MARK: - Main Widget Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DiaryWidgetEntry {
        DiaryWidgetEntry(date: Date(), text: "Your thoughts from today...", mood: nil, hasEntry: true, streak: 5, totalEntries: 42)
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryWidgetEntry) -> Void) {
        let data = WidgetDataFetcher.shared.fetchTodayEntry()
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        let entry = DiaryWidgetEntry(date: Date(), text: data.text, mood: data.mood, hasEntry: data.hasEntry, streak: streak, totalEntries: total)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryWidgetEntry>) -> Void) {
        let data = WidgetDataFetcher.shared.fetchTodayEntry()
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        let entry = DiaryWidgetEntry(date: Date(), text: data.text, mood: data.mood, hasEntry: data.hasEntry, streak: streak, totalEntries: total)

        // Refresh at midnight or in 30 minutes
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let thirtyMinutes = Date().addingTimeInterval(1800)
        let nextUpdate = min(midnight, thirtyMinutes)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Streak Widget Provider

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakWidgetEntry {
        StreakWidgetEntry(date: Date(), streak: 7, hasEntryToday: true, totalEntries: 42)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakWidgetEntry) -> Void) {
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let today = WidgetDataFetcher.shared.fetchTodayEntry()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        completion(StreakWidgetEntry(date: Date(), streak: streak, hasEntryToday: today.hasEntry, totalEntries: total))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakWidgetEntry>) -> Void) {
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let today = WidgetDataFetcher.shared.fetchTodayEntry()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        let entry = StreakWidgetEntry(date: Date(), streak: streak, hasEntryToday: today.hasEntry, totalEntries: total)

        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

// MARK: - Mood Widget Provider

struct MoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(date: Date(), todayMood: "happy", weekMoods: ["happy": 3, "calm": 2, "grateful": 1])
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodWidgetEntry) -> Void) {
        let today = WidgetDataFetcher.shared.fetchTodayEntry()
        let weekMoods = WidgetDataFetcher.shared.getWeekMoods()
        completion(MoodWidgetEntry(date: Date(), todayMood: today.mood, weekMoods: weekMoods))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodWidgetEntry>) -> Void) {
        let today = WidgetDataFetcher.shared.fetchTodayEntry()
        let weekMoods = WidgetDataFetcher.shared.getWeekMoods()
        let entry = MoodWidgetEntry(date: Date(), todayMood: today.mood, weekMoods: weekMoods)

        let thirtyMinutes = Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(thirtyMinutes))
        completion(timeline)
    }
}

// MARK: - Widget Entries

struct DiaryWidgetEntry: TimelineEntry {
    let date: Date
    let text: String?
    let mood: String?
    let hasEntry: Bool
    let streak: Int
    let totalEntries: Int
}

struct StreakWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let hasEntryToday: Bool
    let totalEntries: Int
}

struct MoodWidgetEntry: TimelineEntry {
    let date: Date
    let todayMood: String?
    let weekMoods: [String: Int]
}

// For backward compatibility
typealias DiaryEntryWidget = DiaryWidgetEntry

// MARK: - Widget Views

struct DailyVoxWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let moodString = entry.mood, let mood = Mood(rawValue: moodString), mood != .none {
                    Image(systemName: mood.icon)
                        .font(.caption)
                        .foregroundColor(mood.color)
                }
            }

            if entry.hasEntry, let text = entry.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .lineLimit(4)
                    .foregroundColor(.primary)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("Tap to record")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: entry.date)
    }
}

struct MediumWidgetView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        HStack(spacing: 12) {
            // Left side - Entry preview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Today")
                        .font(.headline)
                    Spacer()
                    if let moodString = entry.mood, let mood = Mood(rawValue: moodString), mood != .none {
                        HStack(spacing: 4) {
                            Image(systemName: mood.icon)
                            Text(mood.displayName)
                        }
                        .font(.caption)
                        .foregroundColor(mood.color)
                    }
                }

                if entry.hasEntry, let text = entry.text, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .lineLimit(3)
                        .foregroundColor(.primary)
                } else {
                    Text("No entry yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }

                Spacer()

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Right side - Quick action
            VStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text("Record")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: entry.date)
    }
}

struct AccessoryCircularView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.hasEntry ? "checkmark.circle.fill" : "mic.fill")
                .font(.title2)
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.title3)
            VStack(alignment: .leading) {
                Text("DailyVox")
                    .font(.headline)
                if entry.hasEntry {
                    Text("Entry recorded")
                        .font(.caption)
                } else {
                    Text("Tap to record")
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - Streak Widget Views

struct StreakWidgetView: View {
    let entry: StreakWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallStreakView(entry: entry)
        case .accessoryCircular:
            CircularStreakView(entry: entry)
        default:
            SmallStreakView(entry: entry)
        }
    }
}

struct SmallStreakView: View {
    let entry: StreakWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Streak flame
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundColor(streakColor)
            }
            
            // Streak count
            Text("\(entry.streak)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(entry.streak == 1 ? "day streak" : "day streak")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Today status
            HStack(spacing: 4) {
                Image(systemName: entry.hasEntryToday ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundColor(entry.hasEntryToday ? .green : .secondary)
                Text(entry.hasEntryToday ? "Done today" : "Record today")
                    .font(.caption2)
                    .foregroundColor(entry.hasEntryToday ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var streakColor: Color {
        if entry.streak >= 30 { return .orange }
        if entry.streak >= 7 { return .yellow }
        return .red
    }
}

struct CircularStreakView: View {
    let entry: StreakWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(entry.streak)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Mood Widget Views

struct MoodWidgetView: View {
    let entry: MoodWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallMoodView(entry: entry)
        case .systemMedium:
            MediumMoodView(entry: entry)
        default:
            SmallMoodView(entry: entry)
        }
    }
}

struct SmallMoodView: View {
    let entry: MoodWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Today's Mood")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let moodString = entry.todayMood, let mood = Mood(rawValue: moodString), mood != .none {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(mood.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: mood.icon)
                            .font(.title2)
                            .foregroundColor(mood.color)
                    }
                    Text(mood.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(mood.color)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "face.dashed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No mood set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumMoodView: View {
    let entry: MoodWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Today's mood
            VStack(spacing: 8) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let moodString = entry.todayMood, let mood = Mood(rawValue: moodString), mood != .none {
                    ZStack {
                        Circle()
                            .fill(mood.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: mood.icon)
                            .font(.title3)
                            .foregroundColor(mood.color)
                    }
                    Text(mood.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(mood.color)
                } else {
                    Image(systemName: "face.dashed")
                        .font(.title)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Not set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80)
            
            Divider()
            
            // Week mood summary
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if entry.weekMoods.isEmpty {
                    Text("No moods recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    // Top moods
                    let sortedMoods = entry.weekMoods.sorted { $0.value > $1.value }.prefix(3)
                    ForEach(Array(sortedMoods), id: \.key) { moodString, count in
                        if let mood = Mood(rawValue: moodString), mood != .none {
                            HStack(spacing: 6) {
                                Image(systemName: mood.icon)
                                    .font(.caption2)
                                    .foregroundColor(mood.color)
                                Text(mood.displayName)
                                    .font(.caption2)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Quick Record Widget Views

struct QuickRecordWidgetView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
            }
            
            Text("Tap to Record")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("Open DailyVox")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configurations

struct DailyVoxWidget: Widget {
    let kind: String = "DailyVoxWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DailyVoxWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Diary Entry")
        .description("View today's diary entry and quick access to record.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Counter")
        .description("Track your journaling streak.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct MoodWidget: Widget {
    let kind: String = "MoodWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Mood Tracker")
        .description("See your mood at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickRecordWidget: Widget {
    let kind: String = "QuickRecordWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            QuickRecordWidgetView()
        }
        .configurationDisplayName("Quick Record")
        .description("Tap to open DailyVox and start recording.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

@main
struct DailyVoxWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyVoxWidget()
        StreakWidget()
        MoodWidget()
        QuickRecordWidget()
    }
}

// MARK: - Mood enum (duplicated for widget target)

enum Mood: String, CaseIterable {
    case none = ""
    case happy = "happy"
    case calm = "calm"
    case grateful = "grateful"
    case excited = "excited"
    case tired = "tired"
    case anxious = "anxious"
    case sad = "sad"
    case angry = "angry"

    var displayName: String {
        switch self {
        case .none: return "No mood"
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .grateful: return "Grateful"
        case .excited: return "Excited"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .angry: return "Angry"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .happy: return "sun.max.fill"
        case .calm: return "leaf.fill"
        case .grateful: return "heart.fill"
        case .excited: return "star.fill"
        case .tired: return "moon.zzz.fill"
        case .anxious: return "wind"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .happy: return .yellow
        case .calm: return .mint
        case .grateful: return .pink
        case .excited: return .orange
        case .tired: return .purple
        case .anxious: return .indigo
        case .sad: return .blue
        case .angry: return .red
        }
    }
}

// MARK: - Widget Persistence Controller

struct WidgetPersistenceController {
    static let shared = WidgetPersistenceController()
    static let appGroupIdentifier = "group.com.dailyvox.app"

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "solyn")

        // Use App Group for shared data
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetPersistenceController.appGroupIdentifier) {
            let storeURL = appGroupURL.appendingPathComponent("solyn.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                logger.error("Widget Core Data error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Previews

#Preview("Diary Entry - Small", as: .systemSmall) {
    DailyVoxWidget()
} timeline: {
    DiaryWidgetEntry(date: Date(), text: "Had a great day today. Went for a walk in the park.", mood: "happy", hasEntry: true, streak: 5, totalEntries: 42)
    DiaryWidgetEntry(date: Date(), text: nil, mood: nil, hasEntry: false, streak: 0, totalEntries: 0)
}

#Preview("Diary Entry - Medium", as: .systemMedium) {
    DailyVoxWidget()
} timeline: {
    DiaryWidgetEntry(date: Date(), text: "Had a great day today. Went for a walk in the park and enjoyed the sunshine.", mood: "happy", hasEntry: true, streak: 5, totalEntries: 42)
}

#Preview("Streak Counter", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(date: Date(), streak: 7, hasEntryToday: true, totalEntries: 42)
    StreakWidgetEntry(date: Date(), streak: 30, hasEntryToday: false, totalEntries: 100)
}

#Preview("Mood Tracker - Small", as: .systemSmall) {
    MoodWidget()
} timeline: {
    MoodWidgetEntry(date: Date(), todayMood: "happy", weekMoods: ["happy": 3, "calm": 2])
    MoodWidgetEntry(date: Date(), todayMood: nil, weekMoods: [:])
}

#Preview("Mood Tracker - Medium", as: .systemMedium) {
    MoodWidget()
} timeline: {
    MoodWidgetEntry(date: Date(), todayMood: "calm", weekMoods: ["happy": 3, "calm": 2, "grateful": 1])
}

#Preview("Quick Record", as: .systemSmall) {
    QuickRecordWidget()
} timeline: {
    DiaryWidgetEntry(date: Date(), text: nil, mood: nil, hasEntry: false, streak: 0, totalEntries: 0)
}
