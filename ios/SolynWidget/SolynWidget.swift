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
    
    /// Which of the last seven nights were spoken, oldest first; the last
    /// element is tonight.
    ///
    /// This is what the widget draws INSTEAD of the entry: seven dots carry the
    /// habit without carrying a single readable word onto the lock screen.
    func lastSevenNights() -> [Bool] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let from = calendar.date(byAdding: .day, value: -6, to: today) else {
            return Array(repeating: false, count: 7)
        }
        request.predicate = NSPredicate(format: "date >= %@", from as NSDate)

        do {
            let entries = try context.fetch(request)
            let spoken = Set(entries.compactMap { entry -> Date? in
                guard let d = entry.value(forKey: "date") as? Date else { return nil }
                return calendar.startOfDay(for: d)
            })
            return (0..<7).map { i in
                guard let day = calendar.date(byAdding: .day, value: i - 6, to: today) else { return false }
                return spoken.contains(day)
            }
        } catch {
            return Array(repeating: false, count: 7)
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
        DiaryWidgetEntry(date: Date(), text: nil, mood: nil, hasEntry: true, streak: 5, totalEntries: 42,
                         nights: [true, true, false, true, true, true, false])
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryWidgetEntry) -> Void) {
        let data = WidgetDataFetcher.shared.fetchTodayEntry()
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        let nights = WidgetDataFetcher.shared.lastSevenNights()
        let entry = DiaryWidgetEntry(date: Date(), text: data.text, mood: data.mood, hasEntry: data.hasEntry, streak: streak, totalEntries: total, nights: nights)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryWidgetEntry>) -> Void) {
        let data = WidgetDataFetcher.shared.fetchTodayEntry()
        let streak = WidgetDataFetcher.shared.calculateStreak()
        let total = WidgetDataFetcher.shared.getTotalEntries()
        let nights = WidgetDataFetcher.shared.lastSevenNights()
        let entry = DiaryWidgetEntry(date: Date(), text: data.text, mood: data.mood, hasEntry: data.hasEntry, streak: streak, totalEntries: total, nights: nights)

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
    /// Fetched, and deliberately never rendered by any view in this file.
    /// Kept only so `fetchTodayEntry`'s tuple does not have to change shape;
    /// `hasEntry` is what the views actually read. See SmallWidgetView.
    let text: String?
    let mood: String?
    let hasEntry: Bool
    let streak: Int
    let totalEntries: Int
    /// Last seven nights, oldest first; the last element is tonight.
    var nights: [Bool] = Array(repeating: false, count: 7)
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


extension View {
    /// Behave in the system's accented and tinted rendering modes.
    ///
    /// A tinted Home Screen (iOS 18) and the Lock Screen both flatten a widget
    /// into one or two colours, which would turn the gold star and the green
    /// disc into the same anonymous shape. `widgetAccentable` tells the system
    /// which parts are the SUBJECT, so the star and the mic keep the accent and
    /// the rest recedes — the shapes stay readable instead of dissolving.
    /// The full palette still applies wherever the user has not asked for a tint.
    func widgetTintable() -> some View {
        widgetAccentable()
    }
}

/// The app's own four-point star, not SF Symbols' five-point rating star.
private struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addCurve(to: CGPoint(x: c.x + s, y: c.y),
                   control1: CGPoint(x: c.x + s * 0.055, y: c.y - s * 0.436),
                   control2: CGPoint(x: c.x + s * 0.436, y: c.y - s * 0.055))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s),
                   control1: CGPoint(x: c.x + s * 0.436, y: c.y + s * 0.055),
                   control2: CGPoint(x: c.x + s * 0.055, y: c.y + s * 0.436))
        p.addCurve(to: CGPoint(x: c.x - s, y: c.y),
                   control1: CGPoint(x: c.x - s * 0.055, y: c.y + s * 0.436),
                   control2: CGPoint(x: c.x - s * 0.436, y: c.y + s * 0.055))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - s),
                   control1: CGPoint(x: c.x - s * 0.436, y: c.y - s * 0.055),
                   control2: CGPoint(x: c.x - s * 0.055, y: c.y - s * 0.436))
        p.closeSubpath()
        return p
    }
}

/// Widget surfaces in the Evergreen tokens, day and night.
///
/// `.accentColor` used to carry these, and the widget extension has no accent
/// colour asset of its own — so every tinted glyph here was rendering in the
/// system default blue, on the one surface that is meant to look like the app.
private struct WidgetSkin {
    let night: Bool
    var background: Color { night ? WP.navy : WP.cream }
    var text: Color { night ? WP.navyText : WP.ink }
    var secondary: Color { (night ? WP.navyText : WP.ink).opacity(0.6) }
    /// GREEN ACTS by day; at night gold is the actor, by the one rule in §1.
    var action: Color { night ? WP.gold : WP.sage }
    var onAction: Color { night ? WP.navy : WP.cream }
    /// Gold TEXT needs a different value on each ground to hold contrast.
    var goldText: Color { night ? WP.goldNight : WP.goldDay }
    var dotEmpty: Color { (night ? WP.navyText : WP.ink).opacity(0.18) }
}

/// The mic disc — green by day, gold by night, cream capsule glyph.
///
/// Interactive on iOS 17+: tapping it goes straight into recording rather than
/// dropping you on the Record screen to tap again. Two taps to speak was the
/// whole reason the widget existed and it still cost two taps.
///
/// `.widgetAccentedRenderingMode(.desaturated)` keeps it legible when someone
/// tints their Home Screen — on iOS 18 an untreated coloured disc gets flattened
/// into the tint and the glyph disappears into it.
private struct MicDisc: View {
    let skin: WidgetSkin
    var diameter: CGFloat = 46

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: StartSpeakingIntent()) { disc }
                .buttonStyle(.plain)
                .accessibilityLabel("Speak an entry")
        } else {
            disc
        }
    }

    private var disc: some View {
        ZStack {
            Circle().fill(skin.action)
            Capsule()
                .fill(skin.onAction)
                .frame(width: diameter * 0.21, height: diameter * 0.36)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Seven nights, oldest first. Tonight is the last one, and it is hollow until
/// it is spoken — a shape, never a scolding.
private struct NightDots: View {
    let nights: [Bool]
    let skin: WidgetSkin
    var dot: CGFloat = 7

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(nights.enumerated()), id: \.offset) { _, spoken in
                Circle()
                    .fill(spoken ? WP.gold : skin.dotEmpty)
                    .frame(width: dot, height: dot)
            }
        }
    }
}

/// 2x2 — mic and a star, and nothing else (spec §5).
///
/// IT NEVER RENDERS ENTRY TEXT. This view used to draw `Text(entry.text)` at
/// four lines: widgets are visible on the Lock Screen and in StandBy, so a
/// journal that puts a sentence there has broken its own promise in the most
/// public place on the device. The star says whether tonight has been spoken;
/// that is the whole of what a passer-by is entitled to see.
struct SmallWidgetView: View {
    let entry: DiaryEntryWidget
    @Environment(\.colorScheme) private var scheme

    private var skin: WidgetSkin { WidgetSkin(night: scheme == .dark) }

    var body: some View {
        VStack(spacing: 12) {
            MicDisc(skin: skin, diameter: 52)

            if entry.hasEntry {
                FourPointStar()
                    .fill(WP.gold)
                    .frame(width: 22, height: 22)
            } else {
                FourPointStar()
                    .stroke(WP.gold.opacity(0.55), lineWidth: 1.2)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(skin.background, for: .widget)
        .widgetTintable()
    }
}

/// 4x2 — mic, the day line, the seven-night strip and the sky count (spec §5).
/// Same rule as above: no entry text in any state.
struct MediumWidgetView: View {
    let entry: DiaryEntryWidget
    @Environment(\.colorScheme) private var scheme

    private var skin: WidgetSkin { WidgetSkin(night: scheme == .dark) }

    var body: some View {
        HStack(spacing: 16) {
            MicDisc(skin: skin, diameter: 54)

            VStack(alignment: .leading, spacing: 9) {
                Text(dayLine)
                    .font(.dv(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(skin.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                NightDots(nights: entry.nights, skin: skin)

                Text("\(entry.totalEntries) IN YOUR SKY")
                    .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(skin.goldText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(skin.background, for: .widget)
        .widgetTintable()
    }

    /// No guilt copy: an unspoken night is an invitation, not a lapse.
    private var dayLine: String {
        if entry.hasEntry {
            return entry.streak > 0 ? "Day \(entry.streak) · spoken" : "Spoken tonight"
        }
        return entry.streak > 0 ? "Day \(entry.streak + 1) · speak tonight" : "Speak tonight"
    }
}

struct AccessoryCircularView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.hasEntry ? "checkmark.circle.fill" : "mic.fill")
                .font(.dv(.title2))
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: DiaryEntryWidget

    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.dv(.title3))
            VStack(alignment: .leading) {
                Text("DailyVox")
                    .font(.dv(.headline))
                if entry.hasEntry {
                    Text("Entry recorded")
                        .font(.dv(.caption))
                } else {
                    Text("Tap to record")
                        .font(.dv(.caption))
                }
            }
        }
    }
}

// MARK: - Streak Widget Views

struct StreakWidgetView: View {
    @Environment(\.colorScheme) private var scheme
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
    @Environment(\.colorScheme) private var scheme
    let entry: StreakWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Streak flame
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "flame.fill")
                    .font(.dv(size: 28))
                    .foregroundColor(streakColor)
            }
            
            // Streak count
            Text("\(entry.streak)")
                .font(.dv(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(entry.streak == 1 ? "day streak" : "day streak")
                .font(.dv(.caption))
                .foregroundColor(.secondary)
            
            // Today status
            HStack(spacing: 4) {
                Image(systemName: entry.hasEntryToday ? "checkmark.circle.fill" : "circle")
                    .font(.dv(.caption2))
                    .foregroundColor(entry.hasEntryToday ? .green : .secondary)
                Text(entry.hasEntryToday ? "Done today" : "Record today")
                    .font(.dv(.caption2))
                    .foregroundColor(entry.hasEntryToday ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetSkin(night: scheme == .dark).background, for: .widget)
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
                    .font(.dv(.caption))
                Text("\(entry.streak)")
                    .font(.dv(size: 18, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Mood Widget Views

struct MoodWidgetView: View {
    @Environment(\.colorScheme) private var scheme
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
    @Environment(\.colorScheme) private var scheme
    let entry: MoodWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Today's Mood")
                .font(.dv(.caption))
                .foregroundColor(.secondary)
            
            if let moodString = entry.todayMood, let mood = Mood(rawValue: moodString), mood != .none {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(mood.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: mood.icon)
                            .font(.dv(.title2))
                            .foregroundColor(mood.color)
                    }
                    Text(mood.displayName)
                        .font(.dv(.subheadline, weight: .medium))
                        .foregroundColor(mood.color)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "face.dashed")
                        .font(.dv(.largeTitle))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No mood set")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetSkin(night: scheme == .dark).background, for: .widget)
    }
}

struct MediumMoodView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: MoodWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Today's mood
            VStack(spacing: 8) {
                Text("Today")
                    .font(.dv(.caption))
                    .foregroundColor(.secondary)
                
                if let moodString = entry.todayMood, let mood = Mood(rawValue: moodString), mood != .none {
                    ZStack {
                        Circle()
                            .fill(mood.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: mood.icon)
                            .font(.dv(.title3))
                            .foregroundColor(mood.color)
                    }
                    Text(mood.displayName)
                        .font(.dv(.caption, weight: .medium))
                        .foregroundColor(mood.color)
                } else {
                    Image(systemName: "face.dashed")
                        .font(.dv(.title))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Not set")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80)
            
            Divider()
            
            // Week mood summary
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.dv(.caption))
                    .foregroundColor(.secondary)
                
                if entry.weekMoods.isEmpty {
                    Text("No moods recorded")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    // Top moods
                    let sortedMoods = entry.weekMoods.sorted { $0.value > $1.value }.prefix(3)
                    ForEach(Array(sortedMoods), id: \.key) { moodString, count in
                        if let mood = Mood(rawValue: moodString), mood != .none {
                            HStack(spacing: 6) {
                                Image(systemName: mood.icon)
                                    .font(.dv(.caption2))
                                    .foregroundColor(mood.color)
                                Text(mood.displayName)
                                    .font(.dv(.caption2))
                                Spacer()
                                Text("\(count)")
                                    .font(.dv(.caption2, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .containerBackground(WidgetSkin(night: scheme == .dark).background, for: .widget)
    }
}

// MARK: - Quick Record Widget Views

struct QuickRecordWidgetView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WP.sage.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "mic.fill")
                    .font(.dv(.title))
                    .foregroundColor(WP.sage)
            }
            
            Text("Tap to Record")
                .font(.dv(.subheadline, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Open DailyVox")
                .font(.dv(.caption))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetSkin(night: scheme == .dark).background, for: .widget)
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
        ConstellationLockScreenWidget()

        if #available(iOS 16.2, *) {
            RecordingLiveActivityWidget()
            StarBirthLiveActivityWidget()
            StreakLiveActivityWidget()
        }

        // Control Centre, the Lock Screen controls and the Action Button — the
        // §5 Quick Settings tile, finally available on this platform.
        if #available(iOS 18.0, *) {
            SpeakControl()
        }
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

            // These MUST match the app's PersistenceController. The app creates the
            // store with history tracking + file protection; a reader that opens it
            // without the same options gets a stale/empty view (widget shows zeros).
            #if os(iOS)
            description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                                  forKey: NSPersistentStoreFileProtectionKey)
            #endif
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                logger.error("Widget Core Data error: \(error.localizedDescription)")
            }
        }

        // Pick up writes the app makes while the widget process is alive.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
