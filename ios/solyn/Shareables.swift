//
//  Shareables.swift
//  solyn
//
//  The six cards worth posting (design §F). Swift port of the Android
//  `Shareables`, rendering the same six artifacts from the same rules so a card
//  posted from either phone is recognisably the same object.
//

import SwiftUI
import UIKit
import DailyVoxTwinEngine

/// The strategy the design states, and the reason this file can exist at all:
/// DailyVox makes zero network calls, so every share is user-made, on-device,
/// through the OS share sheet. The app never uploads a card; it renders a PNG
/// and hands it to whatever the user picks. The constraint is the campaign.
///
/// NAMES ARE REDACTED BY DEFAULT on every card that could carry one. A journal
/// app that makes it one tap to publish "Sarah · 61 nights" has built a privacy
/// incident with a share button, and the default has to be the safe one because
/// the unsafe one is irreversible the moment it is posted.
enum Shareables {

    static let side: CGFloat = 1080

    /// Nights that mint a one-time card. Scarcity without gamification guilt.
    static let milestones = [42, 100, 365]

    enum Card: String, CaseIterable, Identifiable {
        /// The DAILY one.
        ///
        /// Everything else here is occasional — Year One is annual, Milestone
        /// fires at 42/100/365, the receipt is an argument you make once. There
        /// was nothing to post on an ordinary Tuesday, which for a product whose
        /// only growth channel is people posting is the whole problem.
        ///
        /// Tonight is different every night by construction: the sky places
        /// stars by when they were spoken, so a new one lands in a new place and
        /// the field grows outward. No words, no names — the same rule as My Sky.
        case tonight
        case mySky, receipt, yearOne, milestone, wallpaper, gift
        /// Sleep against mood, and ONLY when the user turns it on.
        ///
        /// Health is held to a stricter rule than names: names are redacted by
        /// default and this is absent by default, because a name is something
        /// other people already know about you and your sleep is not. It reads
        /// only kept snapshots, shows no HRV or heart rate — those read as
        /// medical and belong nowhere near a feed — and states a noticing
        /// rather than a prescription.
        case body
        var id: String { rawValue }

        var title: String {
            switch self {
            case .tonight: return String(localized: "Tonight", comment: "Share sheet, the card picker: name of the daily (tonight's star) card. About 14 characters.")
            case .mySky: return String(localized: "My Sky", comment: "Share sheet, the card picker: name of the whole-sky card. About 14 characters.")
            case .receipt: return String(localized: "Receipt", comment: "Share sheet, the card picker: name of the privacy receipt card. About 14 characters.")
            case .yearOne: return String(localized: "Year One", comment: "Share sheet, the card picker: name of the year-in-review card. About 14 characters.")
            case .milestone: return String(localized: "Milestone", comment: "Share sheet, the card picker: name of the 42/100/365-night milestone card. About 14 characters.")
            case .wallpaper: return String(localized: "Wallpaper", comment: "Share sheet, the card picker: name of the lock-screen wallpaper card. About 14 characters.")
            case .gift: return String(localized: "Gift a star", comment: "Share sheet, the card picker: name of the invite-a-friend card. About 14 characters.")
            case .body: return String(localized: "Body", comment: "Share sheet, the card picker: name of the sleep-and-mood card. About 14 characters.")
            }
        }

        var caption: String {
            switch self {
            case .tonight:
                return String(localized: "The one you made today, in the sky it landed in. A new place every night — no words on it, ever.", comment: "Share sheet, the card picker: one-line description under the Tonight card's name. Up to two lines.")
            case .mySky:
                return String(localized: "Stars, no words. The sky is the only journal artifact that is beautiful and private at the same time.", comment: "Share sheet, the card picker: one-line description under the My Sky card's name. Up to two lines.")
            case .receipt:
                return String(localized: "Everything costs zero, itemised. It argues better than a feature list.", comment: "Share sheet, the card picker: one-line description under the Receipt card's name. Up to two lines.")
            case .yearOne:
                return String(localized: "Your year, computed by this phone alone.", comment: "Share sheet, the card picker: one-line description under the Year One card's name. Up to two lines.")
            case .milestone:
                return String(localized: "Minted once, at nights 42, 100 and 365. You cannot buy it or rush it — you can only have spoken that many times.", comment: "Share sheet, the card picker: one-line description under the Milestone card's name. Up to two lines. Keep the numbers 42, 100 and 365.")
            case .wallpaper:
                return String(localized: "Your constellation, sized for a lock screen. The one surface you look at forty times a day, and nobody else can read it.", comment: "Share sheet, the card picker: one-line description under the Wallpaper card's name. Up to two lines.")
            case .gift:
                return String(localized: "A referral card with no tracking link, because there is nothing here that could carry one.", comment: "Share sheet, the card picker: one-line description under the Gift a star card's name. Up to two lines.")
            case .body:
                return String(localized: "How you slept against how you wrote. Off unless you turn it on, and it never leaves out that this is a noticing, not a prescription.", comment: "Share sheet, the card picker: one-line description under the Body card's name. Up to two lines. 'A noticing, not a prescription' is a fixed phrase in the app; translate it the same way everywhere.")
            }
        }

        /// Portrait for the lock screen, square for feeds.
        var size: CGSize {
            self == .wallpaper ? CGSize(width: 1080, height: 1920)
                               : CGSize(width: Shareables.side, height: Shareables.side)
        }
    }

    // MARK: - Facts the cards state

    /// One entry, flattened so the renderers never touch Core Data.
    struct Fact {
        let date: Date
        let text: String
        let mood: Double
        let people: [String]
        /// Hours slept the night before, IF the user kept that snapshot.
        ///
        /// Only kept snapshots are ever read. Body signals go through a
        /// review-before-learning queue precisely so nothing the user has not
        /// looked at can end up anywhere — least of all on a card they might
        /// post.
        var sleepHours: Double? = nil
    }

    /// Sleep by day, from the snapshots the user KEPT. Nothing pending, nothing
    /// discarded, nothing the user has not seen.
    @MainActor
    private static func keptSleepByDay() -> [Date: Double] {
        var out: [Date: Double] = [:]
        for kept in KeptSnapshotStore.shared.loadAll() {
            guard let hours = kept.snapshot.sleepHours else { continue }
            // Keyed on `capturedAt` — the day the body was in that state —
            // NOT `keptAt`. Review is batched: keeping five pending snapshots
            // in one sitting stamps them all with the same `keptAt`, which
            // would collapse a week of sleep onto today and join it to the
            // wrong entries.
            out[Calendar.current.startOfDay(for: kept.snapshot.capturedAt)] = hours
        }
        return out
    }

    @MainActor
    static func facts(from entries: [DiaryEntry]) -> [Fact] {
        // Resolved once for the whole journal rather than per entry: the graph
        // lookup is the expensive part and it does not vary by entry.
        let sleep = keptSleepByDay()
        let known = DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .person, limit: 40)
            .map(\.label)

        return entries.map { entry -> Fact in
            let body = entry.text ?? ""
            let when = entry.date ?? Date()
            return Fact(
                date: when,
                text: body,
                // `mood` is a String label, not a number. `moodValue` is the
                // app's own 1–5 reading of it, remapped here to −1…1 so the
                // cards speak the same scale as every other surface.
                mood: Self.valence(of: entry),
                // Word boundaries: `contains` put "Mom" on a card because the
                // entry said "moments".
                people: EntityMatch.present(known, in: body),
                // Nil unless the user kept a body snapshot for that day.
                sleepHours: sleep[Calendar.current.startOfDay(for: when)]
            )
        }
    }

    /// Chosen moods only — a shared card should not state a suggested one.
    private static func valence(of entry: DiaryEntry) -> Double {
        let m = Mood(rawValue: entry.userMood ?? "") ?? Mood.none
        return (Double(m.moodValue) - 3.0) / 2.0
    }

    static func nights(_ f: [Fact]) -> Int {
        Set(f.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    /// The highest milestone this journal has passed, or nil. Nights, not
    /// entries: two entries in one evening is one night of showing up.
    static func milestoneReached(_ f: [Fact]) -> Int? {
        let n = nights(f)
        return milestones.filter { $0 <= n }.max()
    }

    /// Airplane mode cannot be read on iOS without private API, so the stamp is
    /// user-declared here rather than detected — and the sheet says so. On
    /// Android it is checked, because `Settings.Global` allows it. Claiming a
    /// check we cannot perform would poison the one format built to be filmed.
    ///
    /// The same rule as every other streak in the app, grace day included, so
    /// a card cannot print a number the Today header disagrees with.
    static func streak(_ f: [Fact]) -> Int {
        Streak.current(dates: f.map(\.date))
    }

    /// A single glorious day in an otherwise empty month is not a warm month,
    /// so a month needs three entries before it can win.
    static func warmestMonth(_ f: [Fact]) -> String {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: f) { cal.component(.month, from: $0.date) }
        let eligible = grouped.filter { $0.value.count >= 3 }
        guard !eligible.isEmpty else { return "—" }

        // Averages computed first: inline, this was one expression the compiler
        // reported as unable to type-check in reasonable time.
        var means: [Int: Double] = [:]
        for (month, items) in eligible {
            let total = items.reduce(0.0) { $0 + $1.mood }
            means[month] = total / Double(items.count)
        }
        guard let best = means.max(by: { $0.value < $1.value })?.key else { return "—" }
        // Standalone: the month named on its own, which in some languages is
        // a different form from the one inside a date.
        return DateFormatter().standaloneMonthSymbols[best - 1]
    }

    /// The word this person reaches for. Gated at three uses so a single
    /// memorable entry cannot define someone's year, and fillers are excluded
    /// because "nothing" is genuinely the most frequent word in some journals
    /// and a card announcing it as your word of the year is a worse brag than
    /// no card at all.
    static func mostSaidWord(_ f: [Fact]) -> String? {
        let stop: Set<String> = [
            "the","and","for","was","were","have","has","had","with","that","this",
            "there","then","than","from","they","them","their","what","when","which",
            "would","could","should","about","been","being","just","like","some",
            "more","most","much","very","into","over","again","still","even","also",
            "back","down","but","not","now","out","our","you","your","she","him",
            "his","her","its","one","all","any","are","can","did","get","got","how",
            "too","who","why","way","day","days","today","myself","really","think",
            "know","went","said","made","time","good","bad",
            "nothing","something","anything","everything","thing","things","little",
            "kind","sort","stuff","lot","bit","many",
        ]
        var counts: [String: Int] = [:]
        for fact in f {
            for w in fact.text.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                where w.count >= 4 && !stop.contains(w) {
                counts[w, default: 0] += 1
            }
        }
        guard let best = counts.filter({ $0.value >= 3 }).max(by: { $0.value < $1.value })
        else { return nil }
        return LocaleFormat.quoted(best.key)
    }

    static func milestoneHeadline(_ night: Int) -> String {
        switch night {
        case 365: return String(localized: "A year of showing up.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Headline under the seal at 365 nights. Display face, about 24 characters.")
        case 100: return String(localized: "One hundred nights.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Headline under the seal at 100 nights; the number spelled out. About 24 characters.")
        case 42:  return String(localized: "Forty-two nights.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Headline under the seal at 42 nights; the number spelled out. About 24 characters.")
        case 1:   return String(localized: "One night.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Headline under the seal at the first night. About 24 characters.")
        default:  return String(localized: "\(String(night)) nights.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Headline under the seal; the placeholder is the number of nights spoken (2 or more). About 24 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
        }
    }

    // MARK: - Rendering

    static func render(_ card: Card, facts f: [Fact], includeNames: Bool, includeBody: Bool = false,
                       airplane: Bool) -> UIImage {
        let size = card.size
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            switch card {
            case .tonight:   drawTonight(c, size, f, airplane)
            case .mySky:     drawMySky(c, size, f, airplane)
            case .receipt:   drawReceipt(c, size, f)
            case .yearOne:   drawYearOne(c, size, f, includeNames)
            case .milestone: drawMilestone(c, size, f)
            case .wallpaper: drawWallpaper(c, size, f)
            case .gift:      drawGift(c, size, f)
            case .body:      drawBody(c, size, f, include: includeBody)
            }
        }
    }

    static func pngURL(_ card: Card, image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dailyvox-\(card.rawValue).png")
        try? data.write(to: url)
        return url
    }

    // MARK: - F0 · Tonight — the daily card

    /// Tonight's star, in the sky it landed in.
    ///
    /// Deliberately not a summary of the day: no transcript, no mood word, no
    /// names. What makes it worth posting twice is that it is visibly YOURS and
    /// visibly new — the field is denser than last night and the bright one has
    /// moved. The only text is a count and a duration.
    private static func drawTonight(_ c: CGContext, _ s: CGSize, _ f: [Fact], _ airplane: Bool) {
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.first?.date.timeIntervalSince1970 ?? 42))
        scatter(c, s, count: 300, rng: &rng, topInset: 140, bottomInset: 260)

        let centre = CGPoint(x: s.width / 2, y: s.height * 0.46)
        let sorted = f.sorted { $0.date > $1.date }
        guard let newest = sorted.first else { return }

        // The same encoding the app draws — literally the same code. A card that
        // placed stars by its own copy of the rule would stop matching the
        // screen it claims to be a picture of.
        let skySpan = SkyEncoding.Span(dates: sorted.map(\.date))
        func place(_ date: Date) -> CGPoint {
            SkyEncoding.entryPoint(date: date, in: skySpan, jitter: 0,
                                   centre: centre,
                                   near: s.width * 0.10, far: s.width * 0.40)
        }

        // The journal so far, quiet.
        for fact in sorted.dropFirst().prefix(200) {
            let p = place(fact.date)
            let age = SkyEncoding.age(fact.date, in: skySpan)
            let r: CGFloat = 4 + CGFloat(1 - age) * 3
            c.setFillColor(UIColor(DS.Palette.navyText)
                .withAlphaComponent(0.20 + 0.35 * (1 - age)).cgColor)
            c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }

        // Tonight: the bright one.
        //
        // The halo used to be a single 18%-alpha gold disc, which on navy is not
        // a glow — it is a dull olive coin with a hard edge, and the star sat in
        // the middle of it looking like a badge. Stacked rings fading outward
        // read as light instead.
        let tonight = place(newest.date)
        for step in stride(from: 5, through: 1, by: -1) {
            let r = CGFloat(step) * 17
            c.setFillColor(UIColor(DS.Palette.gold)
                .withAlphaComponent(0.05 * (1.15 - CGFloat(step) / 6)).cgColor)
            c.fillEllipse(in: CGRect(x: tonight.x - r, y: tonight.y - r,
                                     width: r * 2, height: r * 2))
        }
        star(c, at: tonight, r: 30, colour: UIColor(DS.Palette.gold))

        text(c, String(localized: "TONIGHT", comment: "Share card image (Tonight), drawn on a 1080px square and posted publicly. Label at the top. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."), at: CGPoint(x: s.width / 2, y: 128),
             font: mono(26), colour: UIColor(DS.Palette.goldNight), align: .center)

        // `text(at:)` positions the TOP of the line, not its baseline. The
        // count was drawn at 120pt with 60pt of room before its caption, so
        // "35" sat directly on top of "NIGHTS KEPT". The figure needs its own
        // line height plus air.
        let nightCount = nights(f)
        let countFont = display(120)
        let countTop = s.height - 330
        text(c, "\(nightCount)", at: CGPoint(x: s.width / 2, y: countTop),
             font: countFont, colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, nightCount == 1
                ? String(localized: "NIGHT KEPT", comment: "Share card image (Tonight), drawn on a 1080px square and posted publicly. Caption under the count when it is 1. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card.")
                : String(localized: "NIGHTS KEPT", comment: "Share card image (Tonight), drawn on a 1080px square and posted publicly. Caption under the count of nights (any count but 1; add plural variations if your language needs them). Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."),
             at: CGPoint(x: s.width / 2, y: countTop + countFont.lineHeight + 14),
             font: mono(24), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.55),
             align: .center)

        footer(c, s, airplane
               ? String(localized: "IN AIRPLANE MODE \u{00B7} 0 BYTES OUT", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. Shown when the user stamps the card as made in airplane mode.")
               : String(localized: "A SKY MADE OF YOU", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. The app's tagline; translate it the same way on every card."))
    }

    // MARK: - F1 · My Sky

    /// The constellation, with no words on it at all — no transcript, no entity
    /// label, no mood, regardless of the redaction toggle. People post art, not
    /// diaries. There is nothing here to redact, which is the entire idea.
    private static func drawMySky(_ c: CGContext, _ s: CGSize, _ f: [Fact], _ airplane: Bool) {
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.first?.date.timeIntervalSince1970 ?? 42))
        scatter(c, s, count: 140, rng: &rng, topInset: 120, bottomInset: 300)

        let centre = CGPoint(x: s.width / 2, y: s.height * 0.44)
        orbits(c, centre: centre, radii: [s.width * 0.17, s.width * 0.28])
        constellation(c, centre: centre, s: s, count: min(4, max(f.count, 1)), spread: 0.23)

        text(c, String(localized: "MY SKY · NIGHT \(String(nights(f)))", comment: "Share card image (My Sky), drawn on a 1080px square and posted publicly. Label at the top left; the placeholder is how many nights the user has spoken. Upper case, monospaced, about 22 characters."), at: CGPoint(x: 84, y: 96),
             font: mono(20), colour: UIColor(DS.Palette.goldNight))

        if airplane {
            text(c, String(localized: "ON AIRPLANE MODE", comment: "Share card image (My Sky), drawn on a 1080px square and posted publicly. Label at the top right when the user stamps the card as made in airplane mode. Upper case, monospaced, about 18 characters."), at: CGPoint(x: s.width - 84, y: 96),
                 font: mono(20), colour: UIColor(DS.Palette.goldNight), align: .right)
        }

        text(c, String(localized: "\(String(f.count)) stars.", comment: "Share card image (My Sky), drawn on a 1080px square and posted publicly. First of two headline lines; the placeholder is the number of entries (stars). Display face, about 16 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count."), at: CGPoint(x: 84, y: s.height - 300),
             font: display(58), colour: UIColor(DS.Palette.navyText))
        text(c, String(localized: "Zero uploads.", comment: "Share card image (My Sky), drawn on a 1080px square and posted publicly. Second headline line. Display face, about 16 characters."), at: CGPoint(x: 84, y: s.height - 228),
             font: display(58), colour: UIColor(DS.Palette.navyText))
        text(c, String(localized: "Every one made from my voice, on my phone.", comment: "Share card image (My Sky), drawn on a 1080px square and posted publicly. Line under the headline, first person: the user is posting it. About 45 characters."),
             at: CGPoint(x: 84, y: s.height - 156),
             font: body(26), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6))

        footer(c, s, String(localized: "A SKY MADE OF YOU · GETDAILYVOX.COM", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. The address stays as it is."))
    }

    // MARK: - F2 · Privacy receipt

    private static func drawReceipt(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        fill(c, s, UIColor(DS.Palette.navyText))
        let ink = UIColor(DS.Palette.ink)

        text(c, "DAILYVOX", at: CGPoint(x: s.width / 2, y: 104),
             font: mono(30), colour: ink, align: .center)
        // The reader's own date, not en_US_POSIX: a receipt dated in someone
        // else's convention is a small lie on a card about honesty.
        let receiptDate = LocaleFormat.date(Date(), template: LocaleFormat.monthDayYear)
        text(c, String(localized: "PRIVACY RECEIPT · \(receiptDate.uppercased(with: .current))", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Line under the DAILYVOX heading; the placeholder is today's date in the reader's format, upper-cased. Monospaced, about 34 characters."),
             at: CGPoint(x: s.width / 2, y: 156), font: mono(20),
             colour: UIColor(DS.Palette.inkSoft), align: .center)
        dotted(c, s, y: 214)

        let words = f.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        let syncing = PersistenceController.isCloudSyncActive
        // Every figure is counted from the journal, structurally zero, or read
        // from the setting it describes.
        //
        // The rows used to be "NETWORK CALLS 0" and "BYTES UPLOADED 0", printed
        // unconditionally on a build that links CloudKit and offers a sync
        // toggle. This is a card people post as PROOF, so a number on it that
        // the app cannot vouch for is worse than no card at all. "Sent to
        // DailyVox" is zero forever because there is nowhere to send it; iCloud
        // is a row now instead of an omission.
        let rows: [(String, String)] = [
            (String(localized: "ENTRIES SPOKEN", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced; with its value it must fit one line, about 20 characters."), "\(f.count)"),
            (String(localized: "WORDS KEPT", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced, about 20 characters."), "\(words)"),
            (String(localized: "NIGHTS IN A ROW", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column: the current streak. Upper case, monospaced, about 20 characters."), "\(streak(f))"),
            (String(localized: "SENT TO DAILYVOX", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced, about 20 characters."), String(localized: "0 BYTES", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt value, right column: nothing was sent. Upper case, monospaced, about 10 characters.")),
            (String(localized: "ICLOUD SYNC", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. 'iCloud' is Apple's name. Upper case, monospaced, about 20 characters."), syncing
                ? String(localized: "YOUR ACCOUNT", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt value for iCloud sync when it is on: it syncs to the user's own iCloud account. Upper case, monospaced, about 12 characters.")
                : String(localized: "OFF", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt value for iCloud sync when it is off. Upper case, monospaced, about 12 characters.")),
            (String(localized: "ADS SHOWN", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced, about 20 characters."), "0"),
            (String(localized: "ACCOUNTS CREATED", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced, about 20 characters."), "0"),
            (String(localized: "SUBSCRIPTION", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt line label, left column. Upper case, monospaced, about 20 characters."), String(localized: "FREE", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Receipt value: the app costs nothing. Upper case, monospaced, about 10 characters.")),
        ]
        var y: CGFloat = 276
        for (k, v) in rows {
            text(c, k, at: CGPoint(x: 96, y: y), font: mono(26), colour: ink)
            text(c, v, at: CGPoint(x: s.width - 96, y: y), font: mono(26), colour: ink, align: .right)
            y += 62
        }

        dotted(c, s, y: y + 8)
        y += 62
        text(c, syncing
                ? String(localized: "YOUR DATA STAYED YOURS", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Total line when iCloud sync is on (data went only to the user's own account). Upper case, monospaced, about 24 characters.")
                : String(localized: "YOUR DATA STAYED HOME", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Total line when iCloud sync is off (data never left the phone). Upper case, monospaced, about 24 characters."),
             at: CGPoint(x: 96, y: y),
             font: mono(28), colour: UIColor(DS.Palette.goldDay))
        star(c, at: CGPoint(x: s.width - 118, y: y + 14), r: 20, colour: UIColor(DS.Palette.gold))
        dotted(c, s, y: y + 58)

        text(c, String(localized: "THANK YOU FOR TALKING TO YOURSELF", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Sign-off at the foot, like a shop receipt. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."), at: CGPoint(x: s.width / 2, y: y + 108),
             font: mono(22), colour: UIColor(DS.Palette.inkSoft), align: .center)
        text(c, String(localized: "GETDAILYVOX.COM · OPEN SOURCE", comment: "Share card image (Receipt), drawn on a 1080px square and posted publicly. Last line. The address stays as it is. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."), at: CGPoint(x: s.width / 2, y: y + 150),
             font: mono(22), colour: UIColor(DS.Palette.inkSoft), align: .center)
    }

    // MARK: - F3 · Year One

    private static func drawYearOne(_ c: CGContext, _ s: CGSize, _ f: [Fact], _ includeNames: Bool) {
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.count) &* 7919)
        scatter(c, s, count: 70, rng: &rng, topInset: 0, bottomInset: 0)

        text(c, String(localized: "YOUR SKY · YEAR ONE", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Label at the top left. Upper case, monospaced, about 22 characters."), at: CGPoint(x: 84, y: 108),
             font: mono(22), colour: UIColor(DS.Palette.goldNight))
        text(c, String(localized: "\(String(nights(f))) nights.", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. First headline line; the placeholder is the number of nights spoken. Display face, about 16 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count."), at: CGPoint(x: 84, y: 200),
             font: display(66), colour: UIColor(DS.Palette.navyText))
        text(c, String(localized: "One sky.", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Second headline line. Display face, about 16 characters."), at: CGPoint(x: 84, y: 276),
             font: display(66), colour: UIColor(DS.Palette.navyText))

        let counts = f.flatMap(\.people).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let brightest = counts.max { $0.value < $1.value }
        let brightestValue: String = {
            guard let b = brightest else { return String(localized: "not yet", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Value for 'Brightest star' when no person has been named. Lower case, about 12 characters.") }
            // Redacted by default. The count still communicates the shape of
            // the year without naming a real person to a public feed.
            return includeNames
                ? String(localized: "\(b.key) · \(String(b.value)) nights", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Value for 'Brightest star': the person the user mentioned most, then on how many nights. First placeholder: a name from the journal. Second: the count. About 22 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
                : String(localized: "someone · \(String(b.value)) nights", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Value for 'Brightest star' with names hidden: 'someone' stands in for the person; the placeholder is on how many nights. Gender-neutral. About 22 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
        }()

        let rows: [(String, String)] = [
            (String(localized: "Brightest star", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Row label, left column: the person mentioned most. About 16 characters."), brightestValue),
            (String(localized: "Warmest month", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Row label, left column: the month with the best moods; the value is a month name. About 16 characters."), warmestMonth(f)),
            (String(localized: "Most-said word", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Row label, left column: the user's most frequent word, shown quoted. About 16 characters."), mostSaidWord(f) ?? "—"),
            (String(localized: "Computed by", comment: "Share card image (Year One), drawn on a 1080px square and posted publicly. Row label, left column; the value is 'this phone only'. About 16 characters."), String(localized: "this phone only", comment: "Share card image: row value meaning nothing left the phone, after 'Computed by' or 'Read by'. Lower case, about 18 characters.")),
        ]
        var y: CGFloat = 430
        for (k, v) in rows {
            text(c, k, at: CGPoint(x: 84, y: y), font: body(26),
                 colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6))
            text(c, v, at: CGPoint(x: s.width - 84, y: y), font: displayBody(26),
                 colour: UIColor(DS.Palette.navyText), align: .right)
            c.setStrokeColor(UIColor(DS.Palette.navyText).withAlphaComponent(0.1).cgColor)
            c.setLineWidth(2)
            c.move(to: CGPoint(x: 84, y: y + 44)); c.addLine(to: CGPoint(x: s.width - 84, y: y + 44))
            c.strokePath()
            y += 92
        }
        // Not "0 NETWORK CALLS": the figures on this card ARE computed here and
        // nowhere else, which is the honest version of the same boast and does
        // not depend on whether the user turned iCloud sync on.
        footer(c, s, String(localized: "YEAR ONE · COMPUTED ON THIS PHONE", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters."))
    }

    // MARK: - F · milestone stamp

    private static func drawMilestone(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        let night = milestoneReached(f) ?? 42
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(night) &* 7919)
        scatter(c, s, count: 110, rng: &rng, topInset: 0, bottomInset: 0)

        let centre = CGPoint(x: s.width / 2, y: s.height * 0.40)
        for (r, w) in [(CGFloat(230), CGFloat(3)), (265, 2), (300, 1.5)] {
            c.setStrokeColor(UIColor(DS.Palette.gold).withAlphaComponent(0.35).cgColor)
            c.setLineWidth(w)
            c.strokeEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        }
        c.setFillColor(UIColor(DS.Palette.gold).withAlphaComponent(0.11).cgColor)
        c.fillEllipse(in: CGRect(x: centre.x - 196, y: centre.y - 196, width: 392, height: 392))

        text(c, "\(night)", at: CGPoint(x: centre.x, y: centre.y - 74),
             font: display(150), colour: UIColor(DS.Palette.gold), align: .center)
        text(c, night == 1
                ? String(localized: "NIGHT SPOKEN", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Caption under the number on the seal when it is 1. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card.")
                : String(localized: "NIGHTS SPOKEN", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Caption under the number of nights on the seal (any count but 1; add plural variations if your language needs them). Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."),
             at: CGPoint(x: centre.x, y: centre.y + 110),
             font: mono(24), colour: UIColor(DS.Palette.goldNight), align: .center)

        // Derived from the figure on the seal, never a fallback string: an
        // Android probe rendered a seal reading 1 under "Forty-two nights."
        text(c, milestoneHeadline(night), at: CGPoint(x: s.width / 2, y: s.height - 268),
             font: display(52), colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, String(localized: "Nobody sold me this. I just kept talking.", comment: "Share card image (Milestone), drawn on a 1080px square and posted publicly. Line under the headline, first person: the user is posting it. About 45 characters."),
             at: CGPoint(x: s.width / 2, y: s.height - 196),
             font: body(26), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6),
             align: .center)

        footer(c, s, String(localized: "MINTED ON THIS PHONE · GETDAILYVOX.COM", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. The address stays as it is."))
    }

    // MARK: - F · wallpaper

    /// Quieter than the share card by design: this one lives behind a clock and
    /// a notification stack, so the constellation sits low and there is no
    /// headline to be covered up — and no wordmark, because a wallpaper that
    /// advertises at its owner comes off within a week.
    private static func drawWallpaper(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        // A 1080x1920 field with a 280px constellation in the middle of it read
        // as an empty wallpaper — which is what it was. The sky now fills the
        // frame: a denser star field, wider arms, and a caption you can read.
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.first?.date.timeIntervalSince1970 ?? 42))
        scatter(c, s, count: 520, rng: &rng, topInset: 0, bottomInset: 0)

        // Sits low: the lock screen puts the clock at the top, and a wallpaper
        // whose subject is behind the time is a wallpaper you never see.
        let centre = CGPoint(x: s.width / 2, y: s.height * 0.60)
        orbits(c, centre: centre, radii: [s.width * 0.30, s.width * 0.46, s.width * 0.62])
        constellation(c, centre: centre, s: s,
                      count: min(9, max(f.count, 3)), spread: 0.58)

        let caption = String(localized: "\(String(nights(f))) NIGHTS \u{00B7} A SKY MADE OF YOU",
                             comment: "Lock-screen wallpaper image: caption near the bottom. The placeholder is the number of nights spoken; the rest is the app's tagline. Upper case, monospaced, about 34 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count.")
        text(c, caption, at: CGPoint(x: s.width / 2, y: s.height - 150),
             font: mono(30), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.5),
             align: .center)
    }

    // MARK: - F · body

    /// Sleep against mood, in the same ledger F3 uses.
    ///
    /// Deliberately narrow. Sleep and mood only: HRV and resting heart rate are
    /// in the snapshot and stay there, because a number a stranger could read as
    /// a medical fact does not belong on something built to be posted. No
    /// causal language — the app's own framing for this is "a noticing, not a
    /// prescription", and a card is the worst place to start claiming more.
    /// The body card.
    ///
    /// `include` is not a style flag — it decides whether any health number is
    /// drawn at all. Off is the default and draws a card that says so, which is
    /// both the honest preview and the reason a mis-tap cannot leak sleep.
    ///
    /// The headline is the FINDING, not the count. A card captioned "a noticing"
    /// whose largest words are "12 nights" has not noticed anything; the reason
    /// anyone would post this is the sentence about themselves, so that is what
    /// gets the display face and the count drops to a ledger row.
    private static func drawBody(_ c: CGContext, _ s: CGSize, _ f: [Fact], include: Bool) {
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.first?.date.timeIntervalSince1970 ?? 7))
        scatter(c, s, count: 150, rng: &rng, topInset: 80, bottomInset: 300)

        let measured = f.filter { $0.sleepHours != nil }
        let rested = measured.filter { ($0.sleepHours ?? 0) >= 7 }
        let short = measured.filter { ($0.sleepHours ?? 0) < 7 }

        text(c, String(localized: "HOW YOU SLEPT \u{00B7} HOW YOU WROTE", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Label at the top left. Upper case, monospaced, about 34 characters."), at: CGPoint(x: 84, y: 130),
             font: mono(22), colour: UIColor(DS.Palette.goldNight))

        // Both sides need a real sample before a comparison means anything, and
        // a gap smaller than a tenth is not a difference — it is the scorer's
        // own noise wearing the clothes of a finding.
        let restedMood = rested.count >= 3 ? average(rested.map(\.mood)) : nil
        let shortMood = short.count >= 3 ? average(short.map(\.mood)) : nil
        var gap: Double? = nil
        if let r = restedMood, let sh = shortMood, abs(r - sh) >= 0.1 { gap = r - sh }

        let headline: [String]
        if !include {
            headline = [String(localized: "Your body", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 1 of 2, when health data is off: 'Your body / stays here.' Display face, about 18 characters per line."),
                        String(localized: "stays here.", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 2 of 2, when health data is off: 'Your body / stays here.' Display face, about 18 characters per line.")]
        } else if let g = gap {
            let warmer = String(localized: "You write warmer", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 1 of 2: 'You write warmer / after a long night.' (or '/ after a short one.'). Warmer means more positive. Display face, about 18 characters per line.")
            headline = g > 0
                ? [warmer, String(localized: "after a long night.", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 2 of 2, after 'You write warmer': on days after seven hours of sleep or more. About 18 characters.")]
                : [warmer, String(localized: "after a short one.", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 2 of 2, after 'You write warmer': on days after less than seven hours of sleep ('one' is a night). About 18 characters.")]
        } else if restedMood != nil && shortMood != nil {
            headline = [String(localized: "Sleep barely moved", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 1 of 2: 'Sleep barely moved / how you wrote.' About 18 characters per line."),
                        String(localized: "how you wrote.", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 2 of 2: 'Sleep barely moved / how you wrote.' About 18 characters per line.")]
        } else {
            headline = [String(localized: "\(String(measured.count)) nights", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 1 of 2: '12 nights / your body kept.' The placeholder is the number of nights with sleep data. About 18 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count."),
                        String(localized: "your body kept.", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Headline, line 2 of 2: '12 nights / your body kept.' About 18 characters.")]
        }
        text(c, headline[0], at: CGPoint(x: 84, y: 250), font: display(66),
             colour: UIColor(DS.Palette.navyText))
        text(c, headline[1], at: CGPoint(x: 84, y: 330), font: display(66),
             colour: UIColor(DS.Palette.navyText))

        // The ledger is built first and then anchored ABOVE the footer, so a
        // card with two rows and a card with five both sit on the same baseline
        // instead of leaving a third of the frame empty navy.
        var rows: [(String, String, Bool)] = []
        if include {
            rows.append((String(localized: "Nights measured", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column: nights with sleep data. About 18 characters."), "\(measured.count)", false))
            if let avg = average(measured.compactMap(\.sleepHours)) {
                rows.append((String(localized: "Slept, on average", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column; the value is hours and minutes such as 7h05. About 18 characters."), LocaleFormat.sleepHours(avg), false))
            }
            if let r = restedMood, let sh = shortMood {
                // Labelled with the scale, because "+0.4" alone is a number
                // nobody outside this app can read.
                let moodValue = { (v: Double) in
                    String(localized: "\(LocaleFormat.decimal(v, fractionDigits: 1, signed: true)) mood",
                           comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row value: the average mood score on those days, such as '+0.4 mood'. The placeholder is the signed score, already formatted. About 10 characters.")
                }
                rows.append((String(localized: "After seven hours", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column: days after seven hours of sleep or more. About 18 characters."), moodValue(r), gap ?? 0 > 0))
                rows.append((String(localized: "After less", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column, under 'After seven hours': days after less sleep than that. About 18 characters."), moodValue(sh), gap ?? 0 < 0))
            }
        } else {
            rows.append((String(localized: "Sleep", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column, when health data is off. About 18 characters."), String(localized: "not included", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row value when health data is off: no sleep data is on the card. Lower case, about 14 characters."), false))
        }
        rows.append((String(localized: "Read by", comment: "Share card image (Body), drawn on a 1080px square and posted publicly. Row label, left column; the value is 'this phone only'. About 18 characters."), String(localized: "this phone only", comment: "Share card image: row value meaning nothing left the phone, after 'Computed by' or 'Read by'. Lower case, about 18 characters."), true))

        let rowHeight: CGFloat = 78
        var y = s.height - 230 - rowHeight * CGFloat(rows.count - 1)
        for (label, value, gold) in rows {
            text(c, label, at: CGPoint(x: 84, y: y), font: body(27),
                 colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.62))
            text(c, value, at: CGPoint(x: s.width - 84, y: y), font: body(27),
                 colour: UIColor(gold ? DS.Palette.goldNight : DS.Palette.navyText),
                 align: .right)
            dotted(c, s, y: y + 34)
            y += rowHeight
        }

        footer(c, s, include
               ? String(localized: "A NOTICING, NOT A PRESCRIPTION", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. A fixed phrase in the app: never medical advice. Translate it the same way everywhere.")
               : String(localized: "NOTHING OF YOUR BODY IS ON THIS CARD", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. Shown when health data is off."))
    }

    private static func average(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        return xs.reduce(0, +) / Double(xs.count)
    }

    // MARK: - F · gift a star

    private static func drawGift(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        fill(c, s, UIColor(DS.Palette.navySurface))
        let cx = s.width / 2
        star(c, at: CGPoint(x: cx, y: 300), r: 74, colour: UIColor(DS.Palette.gold))

        text(c, String(localized: "I kept \(String(f.count)) stars.", comment: "Share card image (Gift a star), drawn on a 1080px square and posted publicly. Headline, line 1 of 2, first person: the user is inviting a friend. The placeholder is the number of entries (stars). Display face, about 18 characters. The number arrives as digits in a string placeholder, exactly as the English has always printed it (never grouped), so the catalog cannot vary it by count: phrase it so one form reads right for every count."), at: CGPoint(x: cx, y: 450),
             font: display(60), colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, String(localized: "Start yours.", comment: "Share card image (Gift a star), drawn on a 1080px square and posted publicly. Headline, line 2 of 2: an invitation to the friend reading it. About 18 characters."), at: CGPoint(x: cx, y: 526),
             font: display(60), colour: UIColor(DS.Palette.navyText), align: .center)

        let soft = UIColor(DS.Palette.navyText).withAlphaComponent(0.6)
        text(c, String(localized: "Forty-two seconds a night, spoken not typed.", comment: "Share card image (Gift a star), drawn on a 1080px square and posted publicly. Line under the headline. Forty-two is a soft target, never a limit: never 'at least' or 'maximum'. About 45 characters."),
             at: CGPoint(x: cx, y: 626), font: body(27), colour: soft, align: .center)
        text(c, String(localized: "Free, open source, and it never goes online.", comment: "Share card image (Gift a star), drawn on a 1080px square and posted publicly. Second line under the headline. About 45 characters."),
             at: CGPoint(x: cx, y: 672), font: body(27), colour: soft, align: .center)

        // Said out loud because it is unusual and checkable: there is no
        // referral code on this card, and no way to add one — the app cannot
        // phone home to attribute anything.
        text(c, String(localized: "NO TRACKING LINK · NOTHING TO ATTRIBUTE", comment: "Share card image (Gift a star), drawn on a 1080px square and posted publicly. Line above the address: the card has no referral code. Upper case, monospaced, centred; keep it under about 34 characters or it runs off the card."),
             at: CGPoint(x: cx, y: s.height - 320), font: mono(21),
             colour: UIColor(DS.Palette.goldNight), align: .center)
        text(c, "getdailyvox.com", at: CGPoint(x: cx, y: s.height - 246),
             font: display(34), colour: UIColor(DS.Palette.navyText), align: .center)

        footer(c, s, String(localized: "A SKY MADE OF YOU", comment: "Share card image: footer line along the bottom edge, upper case, monospaced. Keep it under about 40 characters. The app's tagline; translate it the same way on every card."))
    }

    // MARK: - Drawing helpers

    private static func fill(_ c: CGContext, _ s: CGSize, _ colour: UIColor) {
        c.setFillColor(colour.cgColor)
        c.fill(CGRect(origin: .zero, size: s))
    }

    /// Deterministic, so the same journal always renders the same card. A card
    /// that changes between shares looks broken.
    private struct Seeded {
        var seed: UInt64
        mutating func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 10000) / 10000
        }
    }

    private static func scatter(_ c: CGContext, _ s: CGSize, count: Int,
                                rng: inout Seeded, topInset: CGFloat, bottomInset: CGFloat) {
        for _ in 0..<count {
            let a = 0.07 + Double(rng.next()) * 0.28
            c.setFillColor(UIColor(DS.Palette.navyText).withAlphaComponent(a).cgColor)
            let x = rng.next() * s.width
            let y = topInset + rng.next() * (s.height - topInset - bottomInset)
            let r = 1 + rng.next() * 2.2
            c.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
        }
    }

    private static func orbits(_ c: CGContext, centre: CGPoint, radii: [CGFloat]) {
        c.saveGState()
        c.setStrokeColor(UIColor(DS.Palette.navyText).withAlphaComponent(0.13).cgColor)
        c.setLineWidth(2)
        c.setLineDash(phase: 0, lengths: [3, 18])
        for r in radii {
            c.strokeEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        }
        c.restoreGState()
    }

    /// Curved links out of the core. Control points are pushed PERPENDICULAR to
    /// each core→star line — placed on the line they produce a mathematically
    /// valid quadratic that is visually a straight segment, which is the bug
    /// the Android sky shipped with first.
    private static func constellation(_ c: CGContext, centre: CGPoint, s: CGSize,
                                      count: Int, spread: CGFloat) {
        for i in 0..<count {
            // Spread whatever count is asked for evenly round the circle,
            // rather than assuming five arms at 72 degrees.
            let angle = (-58.0 + Double(i) * (360.0 / Double(max(count, 1)))) * .pi / 180
            let r = s.width * (spread + CGFloat(i % 3) * 0.055)
            let p = CGPoint(x: centre.x + r * CGFloat(cos(angle)),
                            y: centre.y + r * CGFloat(sin(angle)))
            let m = CGPoint(x: (centre.x + p.x) / 2, y: (centre.y + p.y) / 2)
            let d = CGPoint(x: p.x - centre.x, y: p.y - centre.y)
            let len = max(sqrt(d.x * d.x + d.y * d.y), 1)
            let bow: CGFloat = i % 2 == 0 ? 0.20 : -0.16
            let ctrl = CGPoint(x: m.x + (-d.y / len) * len * bow,
                               y: m.y + (d.x / len) * len * bow)

            // Floor the alpha: past the eighth arm the old formula went
            // negative and the strokes vanished.
            c.setStrokeColor(UIColor(DS.Palette.gold)
                .withAlphaComponent(max(0.18, 0.48 - Double(i) * 0.035)).cgColor)
            c.setLineWidth(3)
            c.move(to: centre)
            c.addQuadCurve(to: p, control: ctrl)
            c.strokePath()

            let node = i == 1 ? UIColor(DS.Palette.starBlue) : UIColor(DS.Palette.navyText)
            c.setFillColor(node.cgColor)
            let nr = max(7, 17 - CGFloat(i) * 1.1)
            c.fillEllipse(in: CGRect(x: p.x - nr, y: p.y - nr, width: nr * 2, height: nr * 2))
        }
        c.setFillColor(UIColor(DS.Palette.gold).withAlphaComponent(0.24).cgColor)
        c.fillEllipse(in: CGRect(x: centre.x - 46, y: centre.y - 46, width: 92, height: 92))
        c.setFillColor(UIColor(DS.Palette.gold).cgColor)
        c.fillEllipse(in: CGRect(x: centre.x - 26, y: centre.y - 26, width: 52, height: 52))
    }

    private static func footer(_ c: CGContext, _ s: CGSize, _ claim: String) {
        text(c, "DailyVox", at: CGPoint(x: 84, y: s.height - 78),
             font: display(30), colour: UIColor(DS.Palette.navyText))
        star(c, at: CGPoint(x: 232, y: s.height - 62), r: 13, colour: UIColor(DS.Palette.gold))
        text(c, claim, at: CGPoint(x: s.width - 84, y: s.height - 72), font: mono(19),
             colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6), align: .right)
    }

    private static func dotted(_ c: CGContext, _ s: CGSize, y: CGFloat) {
        c.saveGState()
        c.setStrokeColor(UIColor(DS.Palette.inkMute).cgColor)
        c.setLineWidth(3)
        c.setLineDash(phase: 0, lengths: [4, 10])
        c.move(to: CGPoint(x: 96, y: y)); c.addLine(to: CGPoint(x: s.width - 96, y: y))
        c.strokePath()
        c.restoreGState()
    }

    /// The four-point mark, as a path, so no card needs an asset.
    private static func star(_ c: CGContext, at p: CGPoint, r: CGFloat, colour: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: p.x, y: p.y - r))
        path.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y),
                          controlPoint: CGPoint(x: p.x + r * 0.18, y: p.y - r * 0.18))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r),
                          controlPoint: CGPoint(x: p.x + r * 0.18, y: p.y + r * 0.18))
        path.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y),
                          controlPoint: CGPoint(x: p.x - r * 0.18, y: p.y + r * 0.18))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r),
                          controlPoint: CGPoint(x: p.x - r * 0.18, y: p.y - r * 0.18))
        path.close()
        c.setFillColor(colour.cgColor)
        c.addPath(path.cgPath)
        c.fillPath()
    }

    private static func mono(_ s: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: s, weight: .semibold)
    }
    private static func display(_ s: CGFloat) -> UIFont {
        let f = UIFont.systemFont(ofSize: s, weight: .bold)
        return UIFont(descriptor: f.fontDescriptor.withDesign(.rounded) ?? f.fontDescriptor, size: s)
    }
    private static func displayBody(_ s: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: s, weight: .bold)
    }
    private static func body(_ s: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: s, weight: .regular)
    }

    private static func text(_ c: CGContext, _ string: String, at p: CGPoint,
                             font: UIFont, colour: UIColor,
                             align: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: colour, .paragraphStyle: style,
        ]
        let attributed = NSAttributedString(string: string, attributes: attrs)
        let size = attributed.size()
        let x: CGFloat
        switch align {
        case .center: x = p.x - size.width / 2
        case .right:  x = p.x - size.width
        default:      x = p.x
        }
        attributed.draw(at: CGPoint(x: x, y: p.y))
    }
}
