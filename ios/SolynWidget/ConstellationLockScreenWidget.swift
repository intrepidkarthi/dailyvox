//
//  ConstellationLockScreenWidget.swift
//  DailyVoxWidgets
//
//  Lock Screen and StandBy widget that renders a small constellation Canvas,
//  one star per entry in the last 30 days, coloured by mood. Sits alongside
//  the existing accessory widgets and gives the user a Lock Screen surface
//  for the constellation metaphor introduced in v1.3.
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - Constellation data + provider

struct ConstellationStar: Hashable {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let moodRaw: String
}

struct ConstellationWidgetEntry: TimelineEntry {
    let date: Date
    let stars: [ConstellationStar]
    let streak: Int
}

struct ConstellationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConstellationWidgetEntry {
        ConstellationWidgetEntry(date: Date(), stars: Self.sampleStars(), streak: 7)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConstellationWidgetEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConstellationWidgetEntry>) -> Void) {
        let entry = buildEntry()
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func buildEntry() -> ConstellationWidgetEntry {
        let stars = fetchRecentStars()
        let streak = WidgetDataFetcher.shared.calculateStreak()
        return ConstellationWidgetEntry(date: Date(), stars: stars, streak: streak)
    }

    /// Pull the last 30 days of entries from the App-Group store and lay them
    /// out deterministically inside the unit square using a hash of their id.
    private func fetchRecentStars() -> [ConstellationStar] {
        let context = WidgetPersistenceController.shared.container.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "DiaryEntry")
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "date >= %@", cutoff as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 60

        guard let entries = try? context.fetch(request) else { return [] }
        return entries.compactMap { entry in
            guard let id = entry.value(forKey: "id") as? UUID else { return nil }
            let h = id.uuidString.hashValue
            let x = CGFloat((h & 0xFFFF)) / CGFloat(0xFFFF)
            let y = CGFloat(((h >> 16) & 0xFFFF)) / CGFloat(0xFFFF)
            let r: CGFloat = 1.5 + CGFloat((h >> 8) & 0x3) * 0.5
            let mood = (entry.value(forKey: "mood") as? String) ?? ""
            return ConstellationStar(x: x, y: y, radius: r, moodRaw: mood)
        }
    }

    static func sampleStars() -> [ConstellationStar] {
        let moods = ["happy", "calm", "grateful", "excited", "tired"]
        return (0..<24).map { i in
            let x = CGFloat((sin(Double(i) * 1.3) + 1) / 2)
            let y = CGFloat((cos(Double(i) * 0.9) + 1) / 2)
            return ConstellationStar(x: x, y: y, radius: 1.5 + CGFloat(i % 3) * 0.5, moodRaw: moods[i % moods.count])
        }
    }
}

// MARK: - Views

struct ConstellationLockScreenView: View {
    let entry: ConstellationWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            ConstellationRectangular(entry: entry)
        case .accessoryInline:
            Text("Day \(entry.streak) · \(entry.stars.count) stars")
        case .accessoryCircular:
            ConstellationCircular(entry: entry)
        default:
            ConstellationRectangular(entry: entry)
        }
    }
}

struct ConstellationRectangular: View {
    let entry: ConstellationWidgetEntry

    var body: some View {
        HStack(spacing: 10) {
            Canvas { ctx, size in
                drawStars(entry.stars, in: ctx, size: size)
            }
            .aspectRatio(1.4, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(entry.streak)")
                    .font(.dv(.headline))
                Text("\(entry.stars.count) stars")
                    .font(.dv(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct ConstellationCircular: View {
    let entry: ConstellationWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Canvas { ctx, size in
                drawStars(entry.stars, in: ctx, size: size)
            }
            .padding(2)
        }
    }
}

/// Shared draw routine — keeps both accessory families pixel-consistent.
private func drawStars(_ stars: [ConstellationStar], in ctx: GraphicsContext, size: CGSize) {
    // Connecting lines (faint) — connect nearest neighbours within a radius
    let positions = stars.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    for i in 0..<positions.count {
        for j in (i + 1)..<positions.count {
            let dx = positions[i].x - positions[j].x
            let dy = positions[i].y - positions[j].y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < size.width * 0.18 {
                var path = Path()
                path.move(to: positions[i])
                path.addLine(to: positions[j])
                ctx.stroke(path, with: .color(Color.white.opacity(0.18)), lineWidth: 0.4)
            }
        }
    }
    for (idx, star) in stars.enumerated() {
        let point = positions[idx]
        let rect = CGRect(x: point.x - star.radius, y: point.y - star.radius, width: star.radius * 2, height: star.radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(starColor(for: star.moodRaw)))
    }
}

// MARK: - Widget configuration

struct ConstellationLockScreenWidget: Widget {
    let kind: String = "ConstellationLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConstellationProvider()) { entry in
            ConstellationLockScreenView(entry: entry)
        }
        .configurationDisplayName("Constellation")
        .description("Your inner sky on the Lock Screen — one star per recent entry.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
