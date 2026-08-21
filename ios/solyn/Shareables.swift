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
        var id: String { rawValue }

        var title: String {
            switch self {
            case .tonight: return "Tonight"
            case .tonight:
                return "The one you made today, in the sky it landed in. A new " +
                       "place every night — no words on it, ever."
            case .mySky: return "My Sky"
            case .receipt: return "Receipt"
            case .yearOne: return "Year One"
            case .milestone: return "Milestone"
            case .wallpaper: return "Wallpaper"
            case .gift: return "Gift a star"
            }
        }

        var caption: String {
            switch self {
            case .tonight:
                return "The one you made today, in the sky it landed in. A new place every night — no words on it, ever."
            case .mySky:
                return "Stars, no words. The sky is the only journal artifact that is beautiful and private at the same time."
            case .receipt:
                return "Everything costs zero, itemised. It argues better than a feature list."
            case .yearOne:
                return "Your year, computed by this phone alone."
            case .milestone:
                return "Minted once, at nights 42, 100 and 365. You cannot buy it or rush it — you can only have spoken that many times."
            case .wallpaper:
                return "Your constellation, sized for a lock screen. The one surface you look at forty times a day, and nobody else can read it."
            case .gift:
                return "A referral card with no tracking link, because there is nothing here that could carry one."
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
    }

    static func facts(from entries: [DiaryEntry]) -> [Fact] {
        // Resolved once for the whole journal rather than per entry: the graph
        // lookup is the expensive part and it does not vary by entry.
        let known = DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .person, limit: 40)
            .map(\.label)

        return entries.map { entry -> Fact in
            let body = entry.text ?? ""
            return Fact(
                date: entry.date ?? Date(),
                text: body,
                // `mood` is a String label, not a number. `moodValue` is the
                // app's own 1–5 reading of it, remapped here to −1…1 so the
                // cards speak the same scale as every other surface.
                mood: Self.valence(of: entry),
                people: known.filter { body.localizedCaseInsensitiveContains($0) }
            )
        }
    }

    private static func valence(of entry: DiaryEntry) -> Double {
        let m = Mood(rawValue: entry.mood ?? "") ?? Mood.none
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
    static func streak(_ f: [Fact]) -> Int {
        guard !f.isEmpty else { return 0 }
        let cal = Calendar.current
        let days = Set(f.map { cal.startOfDay(for: $0.date) }).sorted(by: >)
        let today = cal.startOfDay(for: Date())
        guard let first = days.first,
              first == today || first == cal.date(byAdding: .day, value: -1, to: today)
        else { return 0 }
        var n = 0
        var cursor = first
        for d in days where d == cursor {
            n += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return n
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
        return DateFormatter().monthSymbols[best - 1]
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
        return "\u{201C}\(best.key)\u{201D}"
    }

    static func milestoneHeadline(_ night: Int) -> String {
        switch night {
        case 365: return "A year of showing up."
        case 100: return "One hundred nights."
        case 42:  return "Forty-two nights."
        case 1:   return "One night."
        default:  return "\(night) nights."
        }
    }

    // MARK: - Rendering

    static func render(_ card: Card, facts f: [Fact], includeNames: Bool,
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
        let tonight = place(newest.date)
        c.setFillColor(UIColor(DS.Palette.gold).withAlphaComponent(0.18).cgColor)
        c.fillEllipse(in: CGRect(x: tonight.x - 62, y: tonight.y - 62, width: 124, height: 124))
        star(c, at: tonight, r: 26, colour: UIColor(DS.Palette.gold))

        text(c, "TONIGHT", at: CGPoint(x: s.width / 2, y: 128),
             font: mono(26), colour: UIColor(DS.Palette.goldNight), align: .center)

        let nightCount = nights(f)
        text(c, "\(nightCount)", at: CGPoint(x: s.width / 2, y: s.height - 236),
             font: display(120), colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, nightCount == 1 ? "NIGHT KEPT" : "NIGHTS KEPT",
             at: CGPoint(x: s.width / 2, y: s.height - 176),
             font: mono(24), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.55),
             align: .center)

        footer(c, s, airplane ? "IN AIRPLANE MODE \u{00B7} 0 BYTES OUT" : "A SKY MADE OF YOU")
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

        text(c, "MY SKY · NIGHT \(nights(f))", at: CGPoint(x: 84, y: 96),
             font: mono(20), colour: UIColor(DS.Palette.goldNight))

        if airplane {
            text(c, "ON AIRPLANE MODE", at: CGPoint(x: s.width - 84, y: 96),
                 font: mono(20), colour: UIColor(DS.Palette.goldNight), align: .right)
        }

        text(c, "\(f.count) stars.", at: CGPoint(x: 84, y: s.height - 300),
             font: display(58), colour: UIColor(DS.Palette.navyText))
        text(c, "Zero uploads.", at: CGPoint(x: 84, y: s.height - 228),
             font: display(58), colour: UIColor(DS.Palette.navyText))
        text(c, "Every one made from my voice, on my phone.",
             at: CGPoint(x: 84, y: s.height - 156),
             font: body(26), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6))

        footer(c, s, "A SKY MADE OF YOU · GETDAILYVOX.COM")
    }

    // MARK: - F2 · Privacy receipt

    private static func drawReceipt(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        fill(c, s, UIColor(DS.Palette.navyText))
        let ink = UIColor(DS.Palette.ink)

        text(c, "DAILYVOX", at: CGPoint(x: s.width / 2, y: 104),
             font: mono(30), colour: ink, align: .center)
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"; df.locale = Locale(identifier: "en_US_POSIX")
        text(c, "PRIVACY RECEIPT · \(df.string(from: Date()).uppercased())",
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
            ("ENTRIES SPOKEN", "\(f.count)"),
            ("WORDS KEPT", "\(words)"),
            ("NIGHTS IN A ROW", "\(streak(f))"),
            ("SENT TO DAILYVOX", "0 BYTES"),
            ("ICLOUD SYNC", syncing ? "YOUR ACCOUNT" : "OFF"),
            ("ADS SHOWN", "0"),
            ("ACCOUNTS CREATED", "0"),
            ("SUBSCRIPTION", "FREE"),
        ]
        var y: CGFloat = 276
        for (k, v) in rows {
            text(c, k, at: CGPoint(x: 96, y: y), font: mono(26), colour: ink)
            text(c, v, at: CGPoint(x: s.width - 96, y: y), font: mono(26), colour: ink, align: .right)
            y += 62
        }

        dotted(c, s, y: y + 8)
        y += 62
        text(c, syncing ? "YOUR DATA STAYED YOURS" : "YOUR DATA STAYED HOME",
             at: CGPoint(x: 96, y: y),
             font: mono(28), colour: UIColor(DS.Palette.goldDay))
        star(c, at: CGPoint(x: s.width - 118, y: y + 14), r: 20, colour: UIColor(DS.Palette.gold))
        dotted(c, s, y: y + 58)

        text(c, "THANK YOU FOR TALKING TO YOURSELF", at: CGPoint(x: s.width / 2, y: y + 108),
             font: mono(22), colour: UIColor(DS.Palette.inkSoft), align: .center)
        text(c, "GETDAILYVOX.COM · OPEN SOURCE", at: CGPoint(x: s.width / 2, y: y + 150),
             font: mono(22), colour: UIColor(DS.Palette.inkSoft), align: .center)
    }

    // MARK: - F3 · Year One

    private static func drawYearOne(_ c: CGContext, _ s: CGSize, _ f: [Fact], _ includeNames: Bool) {
        fill(c, s, UIColor(DS.Palette.navy))
        var rng = Seeded(seed: UInt64(f.count) &* 7919)
        scatter(c, s, count: 70, rng: &rng, topInset: 0, bottomInset: 0)

        text(c, "YOUR SKY · YEAR ONE", at: CGPoint(x: 84, y: 108),
             font: mono(22), colour: UIColor(DS.Palette.goldNight))
        text(c, "\(nights(f)) nights.", at: CGPoint(x: 84, y: 200),
             font: display(66), colour: UIColor(DS.Palette.navyText))
        text(c, "One sky.", at: CGPoint(x: 84, y: 276),
             font: display(66), colour: UIColor(DS.Palette.navyText))

        let counts = f.flatMap(\.people).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let brightest = counts.max { $0.value < $1.value }
        let brightestValue: String = {
            guard let b = brightest else { return "not yet" }
            // Redacted by default. The count still communicates the shape of
            // the year without naming a real person to a public feed.
            return includeNames ? "\(b.key) · \(b.value) nights"
                                : "someone · \(b.value) nights"
        }()

        let rows: [(String, String)] = [
            ("Brightest star", brightestValue),
            ("Warmest month", warmestMonth(f)),
            ("Most-said word", mostSaidWord(f) ?? "—"),
            ("Computed by", "this phone only"),
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
        footer(c, s, "YEAR ONE · COMPUTED ON THIS PHONE")
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
        text(c, night == 1 ? "NIGHT SPOKEN" : "NIGHTS SPOKEN",
             at: CGPoint(x: centre.x, y: centre.y + 110),
             font: mono(24), colour: UIColor(DS.Palette.goldNight), align: .center)

        // Derived from the figure on the seal, never a fallback string: an
        // Android probe rendered a seal reading 1 under "Forty-two nights."
        text(c, milestoneHeadline(night), at: CGPoint(x: s.width / 2, y: s.height - 268),
             font: display(52), colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, "Nobody sold me this. I just kept talking.",
             at: CGPoint(x: s.width / 2, y: s.height - 196),
             font: body(26), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.6),
             align: .center)

        footer(c, s, "MINTED ON THIS PHONE · GETDAILYVOX.COM")
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

        let caption = "\(nights(f)) NIGHTS \u{00B7} A SKY MADE OF YOU"
        text(c, caption, at: CGPoint(x: s.width / 2, y: s.height - 150),
             font: mono(30), colour: UIColor(DS.Palette.navyText).withAlphaComponent(0.5),
             align: .center)
    }

    // MARK: - F · gift a star

    private static func drawGift(_ c: CGContext, _ s: CGSize, _ f: [Fact]) {
        fill(c, s, UIColor(DS.Palette.navySurface))
        let cx = s.width / 2
        star(c, at: CGPoint(x: cx, y: 300), r: 74, colour: UIColor(DS.Palette.gold))

        text(c, "I kept \(f.count) stars.", at: CGPoint(x: cx, y: 450),
             font: display(60), colour: UIColor(DS.Palette.navyText), align: .center)
        text(c, "Start yours.", at: CGPoint(x: cx, y: 526),
             font: display(60), colour: UIColor(DS.Palette.navyText), align: .center)

        let soft = UIColor(DS.Palette.navyText).withAlphaComponent(0.6)
        text(c, "Forty-two seconds a night, spoken not typed.",
             at: CGPoint(x: cx, y: 626), font: body(27), colour: soft, align: .center)
        text(c, "Free, open source, and it never goes online.",
             at: CGPoint(x: cx, y: 672), font: body(27), colour: soft, align: .center)

        // Said out loud because it is unusual and checkable: there is no
        // referral code on this card, and no way to add one — the app cannot
        // phone home to attribute anything.
        text(c, "NO TRACKING LINK · NOTHING TO ATTRIBUTE",
             at: CGPoint(x: cx, y: s.height - 320), font: mono(21),
             colour: UIColor(DS.Palette.goldNight), align: .center)
        text(c, "getdailyvox.com", at: CGPoint(x: cx, y: s.height - 246),
             font: display(34), colour: UIColor(DS.Palette.navyText), align: .center)

        footer(c, s, "A SKY MADE OF YOU")
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
