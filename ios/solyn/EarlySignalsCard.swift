//
//  EarlySignalsCard.swift
//  solyn
//
//  The first-week card on Insights and the Twin tab.
//

import SwiftUI

extension EarlySignals.Entry {
    /// Nil for an entry with no date, which no signal could place.
    init?(_ entry: DiaryEntry) {
        guard let date = entry.date else { return nil }
        let chosen = entry.userMood.flatMap { $0.isEmpty ? nil : $0 }
        self.init(date: date,
                  text: entry.text ?? "",
                  chosenMood: chosen,
                  suggestedMood: entry.isMoodSuggested ? entry.mood : nil)
    }
}

extension EarlySignals {
    /// The report for the card, or nil outside the early window — before the
    /// third entry, and from the point the real patterns take over.
    static func report(for entries: some Collection<DiaryEntry>) -> Report? {
        // Dates first: a long journal is turned away without its text being read.
        guard isEarly(entryCount: entries.lazy.filter { $0.date != nil }.count) else { return nil }
        let report = report(entries.compactMap(Entry.init))
        return report.isEmpty ? nil : report
    }
}

/// Labelled as early in its title, and every line carries its own count, so
/// nothing on it reads as a finding.
struct EarlySignalsCard: View {
    @Environment(\.dvTheme) private var theme
    let report: EarlySignals.Report

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Early signals \u{00B7} from \(report.entryCount) entries",
                            comment: "Title of the first-week card on Insights and the Twin tab. The number is how many entries it is read from (3 to 7)."))
                    .font(.dv(.headline, design: .rounded))
                    .foregroundColor(theme.textColor)
                Text(String(localized: "These will firm up as you keep going. Patterns arrive at \(EarlySignals.firmEntries) entries.",
                            comment: "Subtitle of the early signals card. The number is the entry count at which the full patterns appear."))
                    .font(.dv(.footnote))
                    .foregroundColor(theme.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let time = report.timeOfDay {
                row(symbol: "clock", lead: Self.lead(for: time), detail: Self.detail(for: time))
            }
            if let length = report.length {
                row(symbol: "text.alignleft", lead: Self.lead(for: length), detail: Self.detail(for: length))
            }
            if !report.repeats.isEmpty {
                row(symbol: "quote.opening",
                    lead: String(localized: "Words you came back to",
                                 comment: "Early signals: heading for words that appear in two or more entries."),
                    detail: report.repeats.map(Self.line(for:)).joined(separator: "\n"))
            }
            if !report.chosenMoods.isEmpty || !report.suggestedMoods.isEmpty {
                moodRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.cardBackgroundColor))
    }

    private func row(symbol: String, lead: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.dv(size: 13, weight: .semibold))
                .foregroundColor(theme.secondaryTextColor)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.secondaryTextColor.opacity(0.12)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead)
                    .font(.dv(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textColor)
                if let detail {
                    Text(detail)
                        .font(.dv(size: 13))
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Picked and suggested on separate lines, and the suggested line says so
    /// in words — a lighter colour alone would not survive VoiceOver.
    private var moodRow: some View {
        let picked = report.chosenMoods.isEmpty
            ? String(localized: "You haven't picked a mood yet.",
                     comment: "Early signals: shown when the user has not chosen a mood on any entry.")
            : String(localized: "You picked: \(Self.moodList(report.chosenMoods))",
                     comment: "Early signals: moods the user chose, with counts, e.g. 'Calm ×2 · Tired ×1'.")
        let suggested = report.suggestedMoods.isEmpty ? nil
            : String(localized: "Suggested from your words, not picked: \(Self.moodList(report.suggestedMoods))",
                     comment: "Early signals: moods the app suggested and the user left unchanged, with counts. Must say they were suggested.")
        return row(symbol: "circle.lefthalf.filled",
                   lead: String(localized: "Moods so far",
                                comment: "Early signals: heading for the mood counts."),
                   detail: [picked, suggested].compactMap { $0 }.joined(separator: "\n"))
    }

    // MARK: - Copy

    static func lead(for time: EarlySignals.TimeOfDay) -> String {
        switch time.part {
        case .morning:
            return String(localized: "You mostly speak in the morning.", comment: "Early signals: most entries are between 5 am and noon.")
        case .afternoon:
            return String(localized: "You mostly speak in the afternoon.", comment: "Early signals: most entries are between noon and 5 pm.")
        case .evening:
            return String(localized: "You mostly speak in the evening.", comment: "Early signals: most entries are between 5 pm and 10 pm.")
        case .night:
            return String(localized: "You mostly speak late at night.", comment: "Early signals: most entries are between 10 pm and 5 am.")
        }
    }

    static func detail(for time: EarlySignals.TimeOfDay) -> String {
        String(localized: "\(time.count) of your \(time.total) entries.",
               comment: "Early signals: how many entries fall in that part of the day, out of all of them.")
    }

    static func lead(for length: EarlySignals.Length) -> String {
        String(localized: "About \(length.averageWords) words an entry.",
               comment: "Early signals: average words per entry.")
    }

    static func detail(for length: EarlySignals.Length) -> String? {
        guard let trend = length.trend, let earlier = length.earlierWords, let recent = length.recentWords else { return nil }
        switch trend {
        case .longer:
            return String(localized: "Your recent entries run longer: \(recent) words on average, up from \(earlier).",
                          comment: "Early signals: the later half of entries is longer than the earlier half. Numbers are average words.")
        case .shorter:
            return String(localized: "Your recent entries run shorter: \(recent) words on average, down from \(earlier).",
                          comment: "Early signals: the later half of entries is shorter than the earlier half. Numbers are average words.")
        case .steady:
            return String(localized: "About the same length from the first to the latest.",
                          comment: "Early signals: entry length has not changed much.")
        }
    }

    static func line(for item: EarlySignals.Repeat) -> String {
        String(localized: "\u{201C}\(item.word)\u{201D} \u{2014} in \(item.entries) entries",
               comment: "Early signals: a word the user said, quoted exactly, and how many entries it appears in (always 2 or more).")
    }

    static func moodList(_ moods: [EarlySignals.MoodCount]) -> String {
        moods.map { "\((Mood(rawValue: $0.raw) ?? .none).displayName) \u{00D7}\($0.count)" }
            .joined(separator: " \u{00B7} ")
    }
}
