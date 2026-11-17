//
//  ResurfaceCards.swift
//  solyn
//
//  The cards that bring a past entry back: a week ago, on this day, and the
//  weekly recap. What they show is decided in `Resurfacing`; these only draw it.
//

import CoreData
import DailyVoxTwinEngine
import SwiftUI

// MARK: - What Today shows

/// Everything the Today screen resurfaces, computed together so one pass over
/// the entries feeds all three cards.
struct ResurfaceSnapshot: Equatable {
    var weekAgo: Resurfaced?
    var onThisDay: [Resurfaced] = []
    var recap: WeeklyRecap?

    static let empty = ResurfaceSnapshot()

    /// At most this many "on this day" cards, nearest first. Today is a
    /// screen for speaking; the past gets a corner of it, not the page.
    static let onThisDayLimit = 2

    static func make(from entries: [PastEntry], now: Date,
                     calendar: Calendar = .current) -> ResurfaceSnapshot {
        let weekAgo = Resurfacing.weekAgo(in: entries, now: now, calendar: calendar)
        let onThisDay = Resurfacing.onThisDay(in: entries, now: now, calendar: calendar)
            .filter { $0.entryID != weekAgo?.entryID }
            .prefix(onThisDayLimit)
        let recap = Resurfacing.recapWeekIfDue(now: now, calendar: calendar).flatMap {
            Resurfacing.recap(of: entries, week: $0, calendar: calendar,
                              candidates: Resurfacing.engineCandidates)
        }
        return ResurfaceSnapshot(weekAgo: weekAgo, onThisDay: Array(onThisDay), recap: recap)
    }
}

extension Resurfacing {
    /// The engine's per-entry tagger, read with `learn: false`: proposing
    /// names for the recap must not count the week into the profile again.
    /// The counts themselves come from the entries' words, never from here.
    static func engineCandidates(_ text: String) -> Candidates {
        let analysis = LocalAIEngine.shared.analyze(text: text, learn: false)
        return Candidates(people: analysis.people, places: analysis.places, topics: analysis.topics)
    }
}

// MARK: - Labels

extension Resurfaced {
    /// "A week ago you said", "A year ago today" — when the words are from,
    /// and nothing about what they mean.
    var label: String {
        switch kind {
        case .daysAgo(7):
            return String(localized: "A week ago you said",
                          comment: "Header of the Today card quoting the user's entry from 7 days ago.")
        case .daysAgo(let n):
            return String(localized: "\(n) days ago you said",
                          comment: "Header of the Today card quoting the user's entry from 6 or 8 days ago.")
        case .monthsAgo:
            return String(localized: "A month ago today",
                          comment: "Header of the On-this-day card for an entry from the same date last month.")
        case .yearsAgo(1):
            return String(localized: "A year ago today",
                          comment: "Header of the On-this-day card for an entry from the same date last year.")
        case .yearsAgo(let n):
            return String(localized: "\(n) years ago today",
                          comment: "Header of the On-this-day card for an entry from the same date n years ago.")
        case .fromWeek:
            return String(localized: "From your week",
                          comment: "Label above the one verbatim line quoted in the weekly recap.")
        }
    }
}

// MARK: - Past line card

/// One past entry, quoted. Calm by design: no badge, no count, no prompt to
/// do anything — the words, when they were said, and a tap to read the rest.
struct PastLineCard: View {
    let item: Resurfaced
    @Environment(\.dvTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.dv(.caption, weight: .semibold))
                Text(item.label)
                    .font(.dv(.caption, design: .rounded, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.dv(.caption2, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .foregroundColor(theme.goldText)

            Text(verbatim: LocaleFormat.quoted(item.excerpt))
                .font(.dv(.callout))
                .lineSpacing(3)
                .foregroundColor(theme.textColor.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.date.formatted(date: .complete, time: .omitted))
                .font(.dv(.caption2))
                .foregroundColor(theme.secondaryTextColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackgroundColor)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(item.label): \(item.excerpt). \(item.date.formatted(date: .long, time: .omitted))"))
        .accessibilityHint(Text("Opens the entry."))
        .accessibilityAddTraits(.isButton)
    }

    private var icon: String {
        switch item.kind {
        case .daysAgo, .fromWeek: return "clock.arrow.circlepath"
        case .monthsAgo, .yearsAgo: return "calendar"
        }
    }
}

// MARK: - Weekly recap card

/// The week, counted: entries, days spoken, the one name that kept coming up
/// (only if it really did), and one line in the user's own words.
struct WeeklyRecapCard: View {
    let recap: WeeklyRecap
    let title: String
    /// Where the quoted line's entry is looked up to open it.
    let entries: FetchedResults<DiaryEntry>
    @Environment(\.dvTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.dv(.caption, weight: .semibold))
                    Text(title)
                        .font(.dv(.caption, design: .rounded, weight: .bold))
                }
                .foregroundColor(theme.goldText)
                Text(verbatim: weekRange)
                    .font(.dv(.caption2))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .accessibilityElement(children: .combine)

            Text("^[\(recap.entryCount) entry](inflect: true) \u{00B7} ^[\(recap.daysSpoken) day](inflect: true) spoken")
                .font(.dv(.headline, design: .rounded, weight: .bold))
                .foregroundColor(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)

            if let mention = recap.topMention {
                Text("You mentioned \(mention.name) ^[\(mention.count) time](inflect: true).")
                    .font(.dv(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(theme.textColor.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let line = recap.line {
                ResurfacedEntryLink(entryID: line.entryID, entries: entries) {
                    quote(line)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DS.Palette.gold.opacity(0.28), lineWidth: 1)
        )
    }

    private func quote(_ line: Resurfaced) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: LocaleFormat.quoted(line.excerpt))
                .font(.dv(.callout))
                .lineSpacing(3)
                .foregroundColor(theme.textColor.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.dv(.caption2, weight: .semibold))
                .foregroundColor(theme.secondaryTextColor)
        }
        .padding(.top, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(line.label): \(line.excerpt)"))
        .accessibilityHint(Text("Opens the entry."))
        .accessibilityAddTraits(.isButton)
    }

    private var weekRange: String {
        let f = DateIntervalFormatter()
        f.dateTemplate = "MMMd"
        // The interval's end is the next week's first instant; the range a
        // person reads ends on the week's last day.
        return f.string(from: recap.interval.start,
                        to: recap.interval.end.addingTimeInterval(-1))
    }
}

// MARK: - Opening the entry

/// A past card that opens its entry, if the entry still exists. Looked up by
/// id at render time, so a card can never open — or show — a deleted entry.
struct ResurfacedEntryLink<Label: View>: View {
    let entryID: UUID
    let entries: FetchedResults<DiaryEntry>
    @ViewBuilder let label: () -> Label

    var body: some View {
        if let entry = entries.first(where: { $0.id == entryID && !$0.isDeleted }) {
            NavigationLink {
                EntryDetailView(entry: entry)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }
}
