//
//  DailyQuestion.swift
//  solyn
//
//  The question above the mic: a different one each day, the same one all day.
//

import CoreData
import DailyVoxTwinEngine
import Foundation

/// What the Today screen asks.
///
/// It asked "How was your day, really?" every day, forever. A good question
/// the first week; wallpaper by the third. There was a rotating prompt list,
/// but the section that drew it was never composed into the screen, so the
/// one thing that rotated was invisible.
///
/// Answering it is never required. The mic records whatever you say, and the
/// question is a starting thought, not a form field.
struct DailyQuestion: Equatable {
    enum Kind: Equatable {
        /// One of the everyday questions.
        case everyday
        /// A research-pilot "just log it" day (see `DailyQuestions.pilotNeutral`).
        case neutral
        /// Asks after someone the user named in a recent entry.
        case person(String)
        /// Asks after a place the user named in a recent entry.
        case place(String)
    }

    /// The headline.
    let text: String
    /// A quieter line above the headline: why this question, today — "You
    /// mentioned Priya a few days ago." Only grounded questions have one.
    var lead: String? = nil
    /// A quieter line below it: the pilot's neutral prompts carry guidance.
    var detail: String? = nil
    let kind: Kind

    /// Everything VoiceOver should read, in reading order.
    var spoken: String {
        [lead, text, detail].compactMap { $0 }.joined(separator: " ")
    }
}

/// A past entry reduced to what grounding reads. A value, not the managed
/// object, so the choice is a pure function of its inputs.
struct QuestionSource: Equatable {
    let id: UUID
    let date: Date
    let text: String
    /// The mood on the entry — the user's, or one suggested from its words.
    let mood: Mood
    /// The suggestion, kept separately: a suggested sad still counts against
    /// grounding after the user has cleared the mood.
    var suggestedMood: Mood = .none
}

extension QuestionSource {
    /// Snapshots of entries grounding may read. A deleted entry — pending in a
    /// fetched-results array, or already detached — is never one of them: the
    /// app must not ask after a name from words someone threw away.
    static func snapshots<S: Sequence>(of entries: S) -> [QuestionSource] where S.Element == DiaryEntry {
        entries.compactMap { entry in
            guard !entry.isDeleted, entry.managedObjectContext != nil,
                  let id = entry.id, let date = entry.date,
                  let text = entry.text, !text.isEmpty
            else { return nil }
            return QuestionSource(id: id, date: date, text: text,
                                  mood: Mood(rawValue: entry.mood ?? "") ?? .none,
                                  suggestedMood: Mood(rawValue: entry.suggestedMood ?? "") ?? .none)
        }
    }
}

enum DailyQuestions {

    // MARK: - The questions

    /// The everyday set. Index 0 is the original question and the fallback.
    ///
    /// Varied on purpose, and ordered so that neighbouring days pull in
    /// different directions: a moment, then people, then the body, a small
    /// win, something curious, a plain log of the day. None of them assumes
    /// the day was good or bad, and none of them asks what you failed to do.
    static var everyday: [String] {
        [
            String(localized: "How was your day, really?",
                   comment: "Question of the day on the Today screen. The original, and the fallback."),
            String(localized: "What\u{2019}s one moment from today you\u{2019}d like to keep?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Who did you spend time with today?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "How does your body feel right now?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What went a little better than expected?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What made you curious today?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Walk through today, start to finish.",
                   comment: "Question of the day on the Today screen. A plain log of the day."),
            String(localized: "What\u{2019}s still on your mind from today?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Who made you laugh lately?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "How did you sleep last night?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What\u{2019}s one small thing you finished?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What did you learn today, even something tiny?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Where did you go today?",
                   comment: "Question of the day on the Today screen. A plain log of the day."),
            String(localized: "What was the quietest part of your day?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Is there a conversation from today you keep coming back to?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "Where did your energy go today?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What did you notice on your way somewhere?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What are a few small things you\u{2019}re glad about?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What did you eat today, and with whom?",
                   comment: "Question of the day on the Today screen. A plain log of the day."),
            String(localized: "What did you hear, read or watch that stayed with you?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What are you looking forward to?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What did you work on today?",
                   comment: "Question of the day on the Today screen. A plain log of the day."),
            String(localized: "If you spoke to yourself like a friend, what would you say?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What did the weather do to your day?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What\u{2019}s something you\u{2019}re in the middle of?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What would you tell a friend about today?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What\u{2019}s one worry you could put down for tonight?",
                   comment: "Question of the day on the Today screen."),
            String(localized: "What\u{2019}s one gentle intention for tomorrow?",
                   comment: "Question of the day on the Today screen."),
        ]
    }

    static var fallback: DailyQuestion {
        DailyQuestion(text: everyday[0], kind: .everyday)
    }

    // MARK: - The day

    /// The local day as a running count: the same number from just after
    /// midnight until just before the next one, in the user's own time zone,
    /// whenever the app is opened.
    ///
    /// Counted between local midnights rather than with
    /// `ordinality(of: .day, in: .era)`, which does not follow the calendar's
    /// time zone and turned over mid-afternoon in India.
    static func dayNumber(of date: Date, calendar: Calendar = .current) -> Int {
        guard let epoch = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }

    // MARK: - Research pilot

    /// Every third day of the year, pilot participants' question leads with a
    /// plain "log your day" prompt — the neutral-rich slice the affect research
    /// needs (R1 §10 item 5); the everyday questions mostly pull toward an
    /// emotional register. Day-of-year cadence keeps it deterministic.
    ///
    /// This is the rule `TodayView.orderedPrompts` applied, unchanged: the same
    /// days, and the same prompt on each of them.
    static func pilotNeutral(on date: Date, pilotEnabled: Bool,
                             calendar: Calendar = .current) -> EntryPrompt? {
        guard pilotEnabled,
              let day = calendar.ordinality(of: .day, in: .year, for: date),
              day % 3 == 0
        else { return nil }
        return EntryPrompt.neutralPrompts[(day / 3) % EntryPrompt.neutralPrompts.count]
    }

    // MARK: - Grounding

    /// How far back a name may come from, in local days before today.
    static let groundingWindowDays = 14
    /// At most this many days in any seven ask after a name.
    static let groundingDaysPerWeek: Set<Int> = [2, 5]
    /// An entry that leans this negative is not one to ask after.
    static let negativeSentimentFloor = -0.4
    /// Moods that rule an entry out, whether the user chose them or the app
    /// suggested them.
    static let sensitiveMoods: Set<Mood> = [.sad, .anxious, .angry]

    /// Words that make an entry one to leave alone. "Last week you mentioned
    /// Priya" is a kindness after a dinner and a wound after a funeral, and the
    /// tagger cannot tell which. When in doubt, the app asks something else.
    static let sensitiveWords: [String] = [
        "died", "dying", "death", "dead", "funeral", "passed away", "grief", "grieving",
        "hospital", "ICU", "cancer", "diagnosis", "diagnosed", "surgery", "sick", "ill",
        "illness", "divorce", "divorced", "breakup", "broke up", "separated", "miscarriage",
        "abuse", "abused", "assault", "fight", "fought", "argument", "argued", "cheated",
        "fired", "laid off", "suicide", "depressed", "depression", "panic", "lost", "loss",
        "miss", "missed", "missing", "ex", "hurt", "hate", "cried", "crying", "scared",
    ]

    /// Never a person or a place, whatever the tagger thinks.
    static let neverNames: Set<String> = [
        "i", "god", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
        "sunday", "january", "february", "march", "april", "may", "june", "july",
        "august", "september", "october", "november", "december", "today", "tomorrow",
        "yesterday", "christmas", "diwali",
    ]

    /// Names that are also ordinary words. Capitalised at the start of a
    /// sentence they prove nothing — "Will you be there?" — so these need one
    /// capitalised use mid-sentence before they count as a name.
    static let wordLikeNames: Set<String> = [
        "will", "bill", "mark", "grace", "hope", "joy", "faith", "rose", "art", "frank",
        "sunny", "dawn", "summer", "autumn", "rich", "pat", "jack", "ray", "max", "sky",
        "hunter", "page", "chase", "river", "guy", "sue", "drew", "miles", "rob", "nick",
        "holly", "ivy", "iris", "lily", "angel", "honey", "rusty", "penny", "sandy", "bob",
        "carol", "gene", "don", "earl", "sterling", "reed",
        "home", "work", "school", "office", "gym", "park",
    ]

    /// What the on-device tagger proposes for one entry.
    struct Reading: Equatable {
        var people: [String] = []
        var places: [String] = []
        /// The engine's whole-entry sentiment, in [-1, 1].
        var sentiment: Double = 0
    }

    /// A name the user really wrote, and when.
    struct Subject: Equatable {
        enum Kind: Equatable { case person, place }
        /// Exactly as written in the entry.
        let name: String
        let kind: Kind
        let entryID: UUID
        let date: Date
    }

    /// Whether `date` is a day that may ask after a name: two days in every
    /// seven, never two in a row.
    static func isGroundingDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        groundingDaysPerWeek.contains(dayNumber(of: date, calendar: calendar) % 7)
    }

    /// `name` as it is written in `text`, or nil when it is not there as a
    /// name: whole word, capitalised, and — for names that are also ordinary
    /// words, or that this very entry also uses in lower case — capitalised
    /// somewhere other than the start of a sentence.
    ///
    /// So "will" never becomes Will, "Samsung" never yields Sam, and "Will you
    /// come?" proves nothing about anyone called Will.
    static func writtenName(_ proposal: String, in text: String) -> String? {
        let name = proposal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2, name.first?.isLetter == true,
              !neverNames.contains(name.lowercased())
        else { return nil }

        let proper = EntityMatch.properNounRanges(of: name, in: text)
        guard let first = proper.first else { return nil }

        let alsoAWord = wordLikeNames.contains(name.lowercased())
            || EntityMatch.ranges(of: name, in: text).count > proper.count
        if alsoAWord {
            guard let mid = proper.first(where: { !isSentenceInitial($0, in: text) }) else { return nil }
            return String(text[mid])
        }
        return String(text[first])
    }

    /// Whether the range opens a sentence: nothing but whitespace and opening
    /// quotes between it and the start of the text or the last . ! ? or line.
    static func isSentenceInitial(_ range: Range<String.Index>, in text: String) -> Bool {
        var i = range.lowerBound
        while i > text.startIndex {
            i = text.index(before: i)
            let c = text[i]
            if c.isWhitespace && !c.isNewline { continue }
            if "\"'\u{201C}\u{2018}(".contains(c) { continue }
            return c.isNewline || ".!?\u{2026}".contains(c)
        }
        return true
    }

    /// Whether an entry is one the app may ask after at all.
    static func isGentle(_ entry: QuestionSource, reading: Reading) -> Bool {
        guard !sensitiveMoods.contains(entry.mood),
              !sensitiveMoods.contains(entry.suggestedMood),
              reading.sentiment > negativeSentimentFloor
        else { return false }
        return !sensitiveWords.contains { EntityMatch.mentions($0, in: entry.text) }
    }

    /// The names worth asking after: from entries in the local days
    /// `[today − groundingWindowDays, today)`, gentle ones only, newest entry
    /// first, people before places within an entry and each in the order it
    /// was said, each name once.
    ///
    /// Today's own entries are left out, so recording does not change the
    /// question mid-day. `read` is the tagger; it only proposes — a proposal
    /// counts only where `writtenName` finds it in the words.
    static func subjects(in entries: [QuestionSource], now: Date,
                         calendar: Calendar = .current,
                         read: (String) -> Reading) -> [Subject] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -groundingWindowDays, to: today) else { return [] }
        let recent = entries
            .filter { $0.date >= start && $0.date < today }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.id.uuidString < $1.id.uuidString }

        var seen: Set<String> = []
        var out: [Subject] = []
        for entry in recent {
            let reading = read(entry.text)
            guard isGentle(entry, reading: reading) else { continue }
            // The engine's names come out of a Set, in an order that changes
            // between launches; put them in the order they were said so the
            // day's question does not.
            let accepted = (reading.people.map { ($0, Subject.Kind.person) }
                            + reading.places.map { ($0, Subject.Kind.place) })
                .compactMap { proposal, kind -> (name: String, kind: Subject.Kind, at: String.Index)? in
                    guard let name = writtenName(proposal, in: entry.text),
                          let at = EntityMatch.properNounRanges(of: name, in: entry.text).first?.lowerBound
                    else { return nil }
                    return (name, kind, at)
                }
                .sorted {
                    if $0.kind != $1.kind { return $0.kind == .person }
                    return $0.at != $1.at ? $0.at < $1.at : $0.name < $1.name
                }
            for (name, kind, _) in accepted where seen.insert(name.lowercased()).inserted {
                out.append(Subject(name: name, kind: kind, entryID: entry.id, date: entry.date))
            }
        }
        return out
    }

    /// The grounded question for a subject. No pronouns: the app does not know
    /// who Priya is, so it says Priya — and asks after a place as "there".
    static func question(about subject: Subject, now: Date,
                         calendar: Calendar = .current) -> DailyQuestion {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: subject.date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        let name = subject.name
        let lead: String
        switch days {
        case ...1:
            lead = String(localized: "You mentioned \(name) yesterday.",
                          comment: "Line above a question of the day that asks after a name from yesterday's entry. %@ is the name exactly as the user said it.")
        case 2...6:
            lead = String(localized: "You mentioned \(name) a few days ago.",
                          comment: "Line above a question of the day that asks after a name from an entry 2-6 days ago. %@ is the name exactly as the user said it.")
        case 7:
            lead = String(localized: "You mentioned \(name) a week ago.",
                          comment: "Line above a question of the day that asks after a name from an entry 7 days ago. %@ is the name exactly as the user said it.")
        default:
            lead = String(localized: "You mentioned \(name) recently.",
                          comment: "Line above a question of the day that asks after a name from an entry 8-14 days ago. %@ is the name exactly as the user said it.")
        }
        switch subject.kind {
        case .person:
            return DailyQuestion(
                text: String(localized: "How are things with \(name)?",
                             comment: "Question of the day asking after a person the user named recently. %@ is the name. Do not add pronouns."),
                lead: lead, kind: .person(name))
        case .place:
            return DailyQuestion(
                text: String(localized: "How are things there?",
                             comment: "Question of the day asking after a place the user named recently; the place is named in the line above."),
                lead: lead, kind: .place(name))
        }
    }

    // MARK: - The day's lineup

    /// The day's questions in order: the first is today's, and "a different
    /// question" steps through the rest.
    ///
    /// - A pilot neutral day leads with its neutral prompt, exactly as before.
    /// - Otherwise, on a grounding day with a name to ask after, that leads.
    /// - Then every everyday question, starting from the day's own.
    ///
    /// Same inputs, same lineup: it depends on the local day, never the hour,
    /// so the question survives a relaunch and changes at midnight.
    static func lineup(on now: Date,
                       entries: [QuestionSource],
                       pilotEnabled: Bool,
                       calendar: Calendar = .current,
                       read: (String) -> Reading) -> [DailyQuestion] {
        let pool = everyday
        let start = dayNumber(of: now, calendar: calendar) % pool.count
        var out = (pool[start...] + pool[..<start]).map { DailyQuestion(text: $0, kind: .everyday) }

        if let neutral = pilotNeutral(on: now, pilotEnabled: pilotEnabled, calendar: calendar) {
            out.insert(DailyQuestion(text: neutral.title, detail: neutral.detail, kind: .neutral), at: 0)
        } else if isGroundingDay(now, calendar: calendar) {
            let found = subjects(in: entries, now: now, calendar: calendar, read: read)
            if !found.isEmpty {
                // A little variety between the two grounding days of a week,
                // among the few most recent names.
                let pick = found[(dayNumber(of: now, calendar: calendar) / 7) % min(found.count, 3)]
                out.insert(question(about: pick, now: now, calendar: calendar), at: 0)
            }
        }
        return out
    }

    /// The question showing after `turn` taps of "a different question".
    static func question(in lineup: [DailyQuestion], turn: Int) -> DailyQuestion {
        guard !lineup.isEmpty else { return fallback }
        let i = ((turn % lineup.count) + lineup.count) % lineup.count
        return lineup[i]
    }

    /// The tagger in the app: the engine's per-entry reading, `learn: false`
    /// so asking a question never counts an entry into the profile again.
    static func engineReading(_ text: String) -> Reading {
        let analysis = LocalAIEngine.shared.analyze(text: text, learn: false)
        return Reading(people: analysis.people, places: analysis.places, sentiment: analysis.sentiment)
    }

    // MARK: - Turns

    /// "dayNumber:turn" — how many times today's question has been changed.
    /// A per-device convenience; losing it only brings back today's first.
    static func turn(from stored: String, on now: Date, calendar: Calendar = .current) -> Int {
        let parts = stored.split(separator: ":")
        guard parts.count == 2, let day = Int(parts[0]), let turn = Int(parts[1]),
              day == dayNumber(of: now, calendar: calendar)
        else { return 0 }
        return max(turn, 0)
    }

    static func stored(turn: Int, on now: Date, calendar: Calendar = .current) -> String {
        "\(dayNumber(of: now, calendar: calendar)):\(turn)"
    }
}
