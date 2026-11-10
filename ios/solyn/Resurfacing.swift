//
//  Resurfacing.swift
//  solyn
//
//  Bringing the user's own past back to them: a week ago, on this day, and
//  the week in one look.
//

import CoreData
import Foundation
import DailyVoxTwinEngine

/// A past entry reduced to what resurfacing reads: which entry, when, and
/// what it says. A value, not the managed object, so every decision below is
/// a pure function of its inputs and can be tested without Core Data.
struct PastEntry: Equatable {
    let id: UUID
    let date: Date
    let text: String
    /// The entry's stored `transcriptLocale`, nil when unknown (then the
    /// language is read from the text). Only the recap's mention reads it.
    var language: String? = nil
}

extension PastEntry {
    /// Snapshots of the entries that may be resurfaced. An entry that has been
    /// deleted — still in a fetched-results array, or already detached from
    /// its context — is never one of them: bringing back words someone chose
    /// to throw away would be the worst thing this feature could do.
    static func snapshots<S: Sequence>(of entries: S) -> [PastEntry] where S.Element == DiaryEntry {
        entries.compactMap { entry in
            guard !entry.isDeleted, entry.managedObjectContext != nil,
                  let id = entry.id, let date = entry.date,
                  let text = entry.text, !text.isEmpty
            else { return nil }
            return PastEntry(id: id, date: date, text: text, language: entry.transcriptLocale)
        }
    }
}

/// One past entry brought back, with the words quoted from it.
struct Resurfaced: Equatable {
    enum Kind: Hashable {
        /// The entry `days` local days before today: 7, or 6 or 8 when the
        /// week-ago day itself is empty.
        case daysAgo(Int)
        /// Same day of the month, one month back.
        case monthsAgo(Int)
        /// Same calendar date, `n` years back.
        case yearsAgo(Int)
        /// A line from the week a recap covers.
        case fromWeek
    }

    let entryID: UUID
    let date: Date
    /// Verbatim from the entry, trimmed at a sentence (or, failing that, a
    /// word) boundary. Never reworded.
    let excerpt: String
    let kind: Kind
}

/// The week in one look, counted from the entries themselves — never from
/// the engine's learned profile, which has seen some text more than once and
/// some not at all.
struct WeeklyRecap: Equatable {
    struct Mention: Equatable {
        enum Kind: Int, Comparable {
            case person, place, topic
            static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
        }
        /// As it is written in the entry where it first appears.
        let name: String
        let count: Int
        let kind: Kind
    }

    /// The local week covered, `[start, end)`.
    let interval: DateInterval
    let entryCount: Int
    let daysSpoken: Int
    /// Only when it really appears at least `Resurfacing.minimumMentions`
    /// times across the week's words.
    let topMention: Mention?
    /// One verbatim line from the week.
    let line: Resurfaced?
}

enum Resurfacing {

    /// Below this many words there is nothing worth bringing back — "Test",
    /// "ok", a mis-tap that transcribed one word.
    static let minimumWords = 4
    /// Long enough for a thought, short enough to read at a glance.
    static let excerptLimit = 160
    /// Lock-screen previews truncate early; keep the quote inside them.
    static let notificationExcerptLimit = 90
    /// A name said once is not a theme of the week.
    static let minimumMentions = 2
    /// The week-ago day, then its neighbours. Nearest first, earlier before
    /// later on a tie, so the choice never depends on fetch order.
    static let weekAgoOffsets = [7, 6, 8]
    /// The recap opens at this hour on the last day of the local week.
    static let recapEveningHour = 18

    // MARK: - Excerpt

    /// A short verbatim excerpt: whole sentences from the start while they fit
    /// in `limit` characters; if even the first sentence does not, it is cut
    /// after the last whole word that fits and marked with an ellipsis.
    ///
    /// Characters are grapheme clusters, so an emoji or a combining mark is
    /// never split, and nothing assumes left-to-right: the ellipsis goes at
    /// the logical end, which is where an RTL renderer draws it. Returns nil
    /// when the text has fewer than `minimumWords` words.
    static func excerpt(from text: String, limit: Int = excerptLimit) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, wordCount(trimmed) >= minimumWords else { return nil }

        var sentences: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { s, _, _, _ in
            let sentence = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
        }
        guard let first = sentences.first else { return nil }

        if first.count > limit {
            return cutAtWord(first, limit: limit)
        }
        var out = first
        for next in sentences.dropFirst() {
            guard out.count + 1 + next.count <= limit else { break }
            out += " " + next
        }
        return out
    }

    private static func cutAtWord(_ sentence: String, limit: Int) -> String? {
        // Room for the ellipsis.
        let budget = max(limit - 1, 1)
        var end: String.Index?
        sentence.enumerateSubstrings(in: sentence.startIndex..., options: .byWords) { _, range, _, stop in
            if sentence.distance(from: sentence.startIndex, to: range.upperBound) <= budget {
                end = range.upperBound
            } else {
                stop = true
            }
        }
        // One word longer than the whole budget — a pasted URL. Nothing
        // honest to show.
        guard let end else { return nil }
        var head = String(sentence[..<end])
        while let last = head.last, last.isPunctuation || last.isWhitespace { head.removeLast() }
        guard wordCount(head) >= minimumWords else { return nil }
        return head + "\u{2026}"
    }

    static func wordCount(_ text: String) -> Int {
        var n = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            n += 1
        }
        return n
    }

    // MARK: - A week ago

    /// The entry from a week ago, or a day either side when that day is
    /// empty. Days are the user's local days in `calendar`, so an entry at
    /// 23:50 belongs to the day it was spoken on, and a daylight-saving change
    /// in between does not shift the window by an hour.
    static func weekAgo(in entries: [PastEntry], now: Date,
                        calendar: Calendar = .current,
                        offsets: [Int] = weekAgoOffsets,
                        limit: Int = excerptLimit) -> Resurfaced? {
        let today = calendar.startOfDay(for: now)
        for offset in offsets {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let onDay = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            if let pick = firstQuotable(onDay, limit: limit) {
                return Resurfaced(entryID: pick.0.id, date: pick.0.date, excerpt: pick.1, kind: .daysAgo(offset))
            }
        }
        return nil
    }

    // MARK: - On this day

    /// Entries from today's calendar date in earlier periods: the same day one
    /// month back, and the same date in every earlier year, nearest first.
    ///
    /// The day has to match exactly. On 31 March there is no "one month ago"
    /// because February has no 31st — clamping to 28 February would show the
    /// same entry four days running. The one exception is the leap day: on
    /// 28 February of a year without one, a 29 February entry from an earlier
    /// year comes back, or it would wait four years.
    static func onThisDay(in entries: [PastEntry], now: Date,
                          calendar: Calendar = .current,
                          limit: Int = excerptLimit) -> [Resurfaced] {
        let t = calendar.dateComponents([.year, .month, .day], from: now)
        guard let ty = t.year, let tm = t.month, let td = t.day else { return [] }
        let isLastDayOfMonth = calendar.range(of: .day, in: .month, for: now)?.last == td

        var buckets: [Resurfaced.Kind: [PastEntry]] = [:]
        for entry in entries {
            let e = calendar.dateComponents([.year, .month, .day], from: entry.date)
            guard let ey = e.year, let em = e.month, let ed = e.day else { continue }

            if em == tm, ey < ty, ed == td || (isLastDayOfMonth && ed > td) {
                buckets[.yearsAgo(ty - ey), default: []].append(entry)
            } else if ed == td, (ty * 12 + tm) - (ey * 12 + em) == 1 {
                buckets[.monthsAgo(1), default: []].append(entry)
            }
        }

        return buckets
            .compactMap { kind, group -> Resurfaced? in
                guard let pick = firstQuotable(group, limit: limit) else { return nil }
                return Resurfaced(entryID: pick.0.id, date: pick.0.date, excerpt: pick.1, kind: kind)
            }
            .sorted { $0.date > $1.date }
    }

    /// The latest entry in `group` with something worth quoting. Ties broken
    /// by id, so it is the same entry on every launch.
    private static func firstQuotable(_ group: [PastEntry], limit: Int) -> (PastEntry, String)? {
        let ordered = group.sorted {
            $0.date != $1.date ? $0.date > $1.date : $0.id.uuidString < $1.id.uuidString
        }
        for entry in ordered {
            if let ex = excerpt(from: entry.text, limit: limit) { return (entry, ex) }
        }
        return nil
    }

    // MARK: - Weekly recap

    /// The local week (`calendar.firstWeekday`, so the user's locale) whose
    /// recap is showing at `now`, or nil when it is not recap time.
    ///
    /// Recap time is the evening of the week's last day — Sunday evening
    /// where weeks start on Monday — through the whole of the next first
    /// weekday, so someone who does not open the app that evening still finds
    /// it the next day.
    static func recapWeekIfDue(now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        if let evening = recapEvening(of: week, calendar: calendar), now >= evening {
            return week
        }
        if calendar.isDate(now, inSameDayAs: week.start) {
            return previousWeek(before: week, calendar: calendar)
        }
        return nil
    }

    /// The week the Insights recap covers at any time: the current week once
    /// its recap is due, otherwise the last full week.
    static func latestRecapWeek(now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        if let evening = recapEvening(of: week, calendar: calendar), now >= evening {
            return week
        }
        return previousWeek(before: week, calendar: calendar)
    }

    private static func recapEvening(of week: DateInterval, calendar: Calendar) -> Date? {
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) else { return nil }
        return calendar.date(bySettingHour: recapEveningHour, minute: 0, second: 0,
                             of: calendar.startOfDay(for: lastDay))
    }

    private static func previousWeek(before week: DateInterval, calendar: Calendar) -> DateInterval? {
        calendar.date(byAdding: .day, value: -1, to: week.start)
            .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
    }

    /// Names worth counting in one entry, as the on-device tagger reads them.
    struct Candidates: Equatable {
        var people: [String] = []
        var places: [String] = []
        var topics: [String] = []
    }

    /// The recap for `week`, or nil when nothing was said in it.
    ///
    /// `candidates` proposes names for each entry (the engine's per-entry
    /// tagger in the app, fixed lists in tests); a proposal only counts where
    /// the week's own words contain it as a whole word — people and places
    /// written as names, topics in any case — so the tagger can suggest but
    /// never invent.
    static func recap(of entries: [PastEntry], week: DateInterval,
                      calendar: Calendar = .current,
                      candidates: (String) -> Candidates) -> WeeklyRecap? {
        let inWeek = entries
            .filter { $0.date >= week.start && $0.date < week.end }
            .sorted { $0.date > $1.date }
        guard !inWeek.isEmpty else { return nil }

        let days = Set(inWeek.map { calendar.startOfDay(for: $0.date) })
        let top = topMention(in: inWeek, candidates: candidates)

        var line: Resurfaced?
        if let top {
            for entry in inWeek {
                if let sentence = sentence(mentioning: top, in: entry.text) {
                    line = Resurfaced(entryID: entry.id, date: entry.date, excerpt: sentence, kind: .fromWeek)
                    break
                }
            }
        }
        if line == nil, let pick = firstQuotable(inWeek, limit: excerptLimit) {
            line = Resurfaced(entryID: pick.0.id, date: pick.0.date, excerpt: pick.1, kind: .fromWeek)
        }

        return WeeklyRecap(interval: week, entryCount: inWeek.count, daysSpoken: days.count,
                           topMention: top, line: line)
    }

    static func topMention(in entries: [PastEntry],
                           candidates: (String) -> Candidates) -> WeeklyRecap.Mention? {
        // Every proposal once, case-insensitively, keeping its strongest kind.
        var proposals: [String: (name: String, kind: WeeklyRecap.Mention.Kind)] = [:]
        func propose(_ names: [String], _ kind: WeeklyRecap.Mention.Kind) {
            for raw in names {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.count >= 2, name.first?.isLetter == true else { continue }
                let key = name.lowercased()
                if let existing = proposals[key], existing.kind <= kind { continue }
                proposals[key] = (name, kind)
            }
        }
        for entry in entries {
            // Each kind of proposal only from an entry whose language can be
            // read for it (LanguageGate). Names come from the OS tagger, which
            // reads en, es, fr, de and it; topics are the engine's English
            // keyword topics, read with its reflection. Elsewhere the tagger
            // still answers — every capitalised German noun a "person", an
            // English topic word found by chance — so the entry proposes
            // nothing, and the recap falls back to a quoted line.
            let language = FeatureLanguage.reading(entry.text, stored: entry.language)
            let readsNames = LanguageGate.supports(.names, languageCode: language)
            let readsTopics = LanguageGate.supports(.reflection, languageCode: language)
            guard readsNames || readsTopics else { continue }
            let c = candidates(entry.text)
            if readsNames {
                propose(c.people, .person)
                propose(c.places, .place)
            }
            if readsTopics { propose(c.topics, .topic) }
        }

        var best: WeeklyRecap.Mention?
        for (name, kind) in proposals.values {
            var count = 0
            var asWritten: String?
            // Oldest first, so the name is spelled as it was first said.
            for entry in entries.reversed() {
                let ranges = kind == .topic
                    ? EntityMatch.ranges(of: name, in: entry.text)
                    : EntityMatch.properNounRanges(of: name, in: entry.text)
                count += ranges.count
                if asWritten == nil, let r = ranges.first { asWritten = String(entry.text[r]) }
            }
            guard count >= minimumMentions, let written = asWritten else { continue }
            let mention = WeeklyRecap.Mention(name: written, count: count, kind: kind)
            if let b = best {
                let better = mention.count != b.count ? mention.count > b.count
                    : mention.kind != b.kind ? mention.kind < b.kind
                    : mention.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                if !better { continue }
            }
            best = mention
        }
        return best
    }

    /// The first sentence of `text` that says the name, trimmed like any
    /// excerpt — so the line under "you mentioned Sarah" is one where you did.
    static func sentence(mentioning mention: WeeklyRecap.Mention, in text: String) -> String? {
        var found: String?
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { s, _, _, stop in
            guard let s else { return }
            let hit = mention.kind == .topic
                ? EntityMatch.mentions(mention.name, in: s)
                : !EntityMatch.properNounRanges(of: mention.name, in: s).isEmpty
            if hit, let ex = excerpt(from: s) {
                found = ex
                stop = true
            }
        }
        return found
    }
}
