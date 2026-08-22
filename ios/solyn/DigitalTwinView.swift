//
//  DigitalTwinView.swift
//  solyn
//
//  Your Digital Twin - a visual mirror of your inner world.
//  All data stays on-device. Your twin is yours alone.
//

import SwiftUI
import DailyVoxTwinEngine

struct DigitalTwinView: View {
    @ObservedObject private var twin = DigitalTwinEngine.shared
    /// NIGHT, UNDER BOTH THEMES (FINAL-SPEC §1 colour rules, §2.5, §8.4).
    ///
    /// Not `ThemeManager.shared`: this screen has no day variant. The same
    /// value is handed to the subtree below so the sky, the cards and every
    /// system-semantic colour agree with it.
    private let themeManager = DVTheme.night
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Matches the launch arguments ScreenshotTests passes. Repeat-forever
    /// animations keep the run loop busy, so XCUITest never sees the app idle.
    private static let animationsDisabledForTesting =
        ProcessInfo.processInfo.arguments.contains("-UITesting") ||
        ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")
    @State private var selectedSection: TwinSection = .overview
    @State private var showInsights = ScreenshotScene.current == .insights
    /// Whether the non-C2 cards are expanded. Collapsed by default; the Twin
    /// screen's job is the sky, not a dashboard.
    @State private var showDepth = false
    @State private var showShare = false
    @State private var showingDetail = false
    @State private var animateOrb = false
    @State private var showTwinShareSheet = false
    @State private var twinShareImage: UIImage?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    private var isIPad: Bool { horizontalSizeClass == .regular }

    enum TwinSection: String, CaseIterable {
        case overview = "Overview"
        case personality = "Personality"
        case emotions = "Emotions"
        case world = "My World"
        case patterns = "Patterns"
    }

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                firstTimeTwinView
            } else {
                VStack(spacing: 24) {
                    Text("Your sky")
                        .font(.dv(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Digital Twin Orb Header
                    twinOrbHeader

                    // C2, complete and in the spec's order: the sky, one
                    // sentence about who you are, the dimension stats, and the
                    // way in to ask. That is the whole screen the design draws.
                    twinSummaryCard

                    dimensionStats

                    // Insights and Share, as NAMED actions.
                    //
                    // They were two 34pt unlabelled glyphs in the top corner of
                    // one tab. Insights is a whole section of the product — the
                    // spec calls it a segment of this tab — and Share is §F, the
                    // entire virality thesis. Nobody was going to find either
                    // one there. They sit under the summary now, at full width,
                    // with their names on them.
                    HStack(spacing: 10) {
                        twinAction("Insights", "chart.line.uptrend.xyaxis") {
                            showInsights = true
                        }
                        twinAction("Share your sky", "square.and.arrow.up") {
                            showShare = true
                        }
                    }

                    // No "Ask Your Twin" button here.
                    //
                    // Ask is a TAB. A decorated full-width control that goes
                    // where the bottom bar already goes is weight with no
                    // destination of its own — and it was the largest object on
                    // the screen after the sky.

                    // Everything the design has no slot for lives behind this.
                    //
                    // NOT deleted. The resolution card, the pilot invite, the
                    // Body queue and the five sections are shipped features with
                    // people using them — removing them to satisfy a layout is
                    // the wrong trade. But C2 is a sky and a sentence, and a
                    // screen that opened with six stacked dashboards was not
                    // that screen no matter what the top of it said.
                    twinDepthDisclosure

                    if showDepth {
                        // Maturity indicator
                        maturityBadge

                        // How well the Twin actually knows you (self-prediction fidelity)
                        TwinResolutionCard()

                        // Consented-pilot invitation (high-engagement users only;
                        // once-ever, dismissible — see PilotInviteCard for gates)
                        PilotInviteCard(entryCount: entries.count,
                                        firstEntryDate: entries.last?.date)

                        // The Body dimension + review-before-learning queue
                        BodyTwinCard()

                        // Section Picker
                        sectionPicker

                        // Content based on selection
                        switch selectedSection {
                        case .overview:
                            overviewSection
                        case .personality:
                            personalitySection
                        case .emotions:
                            emotionsSection
                        case .world:
                            worldSection
                        case .patterns:
                            patternsSection
                        }
                    }

                    // No privacy badge here either. The claim is made on the
                    // Record screen, under the mic, and again in Settings' Data
                    // Shield. Saying it a third time on the one screen that
                    // contains no words does not make it more true.

                    // The C2 content grew (summary card, dimension stats) and
                    // the old clearance was computed from a bar height that was
                    // wrong by 20pt, so MIND/HEART/GRAPH sat under the pill with
                    // their captions poking out below it.
                    Spacer(minLength: DS.Space.lg)
                }
                .padding()
                .dailyVoxBarClearance()
                .frame(maxWidth: isIPad ? 700 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        // No system navigation bar: the screen draws "Your sky" itself, and the
        // bar was reserving an empty band above it. Insights and Share move
        // onto that same row.
        .toolbar(.hidden, for: .navigationBar)
        .dailyVoxStatusBarScrim()
        .background { WarmBackground() }
        // The whole subtree is night. Two overrides, because the screen mixes
        // two colour systems: `dvTheme` covers everything drawn from the
        // DailyVox palette, and `colorScheme` covers the cards still built on
        // system semantics (.primary, .secondary, secondarySystemGroupedBackground)
        // which would otherwise render light-on-light over the navy.
        .environment(\.dvTheme, .night)
        .environment(\.colorScheme, .dark)
        // Insights and the share sheet are NOT the constellation screen — the
        // spec makes only the sky unconditional — so they are handed the user's
        // real theme back. Sheets inherit the presenter's environment, so
        // without this they would come up dark on a cream app.
        .sheet(isPresented: $showInsights) {
            NavigationStack { StatsView() }.appThemedSheet()
        }
        .sheet(isPresented: $showShare) {
            ShareSheetView().appThemedSheet()
        }
    }

    // MARK: - First-Time Twin Introduction

    private var firstTimeTwinView: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: 20)

            // Mini constellation (empty sky with core star)
            ZStack {
                // Dark celestial background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.Palette.navy,
                                DS.Palette.navy
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: isIPad ? 260 : 200)

                // Scattered dim stars
                ForEach(0..<15, id: \.self) { i in
                    let seed = UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(Double((seed >> 16) % 10000) / 10000.0) * (isIPad ? 600 : 340) - (isIPad ? 300 : 170)
                    let y = CGFloat(Double((seed >> 32) % 10000) / 10000.0) * (isIPad ? 220 : 160) - (isIPad ? 110 : 80)
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2, height: 2)
                        .offset(x: x, y: y)
                }

                // Central core star (waiting)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.gold.opacity(animateOrb ? 0.12 : 0.06))
                            .frame(width: 60, height: 60)
                        Circle()
                            .fill(DS.Palette.gold.opacity(0.3))
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(DS.Palette.tintGold.opacity(0.7))
                            .frame(width: 8, height: 8)
                    }

                    Text("Your sky is empty — for now")
                        .font(.dv(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(DS.Palette.tintGold.opacity(0.5))
                }
            }
            .padding(.horizontal)

            // Introduction steps
            VStack(spacing: 20) {
                Text("Meet your Digital Twin")
                    .font(.dv(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.textColor)

                Text("A private AI that learns who you are — entirely on your device.")
                    .font(.dv(.subheadline, design: .rounded, weight: .regular))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            // How it works — 4 steps
            VStack(spacing: 0) {
                twinIntroStep(
                    number: "1",
                    icon: "mic.circle.fill",
                    title: "You speak",
                    description: "Speak an entry on the Speak tab. 42 seconds is the sweet spot — take as long as you need.",
                    color: DS.Palette.sage,
                    isLast: false
                )
                twinIntroStep(
                    number: "2",
                    icon: "sparkle",
                    title: "Stars appear",
                    description: "Each entry becomes a star in your constellation, colored by mood.",
                    color: DS.Palette.gold,
                    isLast: false
                )
                twinIntroStep(
                    number: "3",
                    icon: "brain.head.profile",
                    title: "Your Twin learns",
                    description: "Four models — Mind, Heart, Voice, Graph — build your personality profile.",
                    color: DS.Palette.coral,
                    isLast: false
                )
                twinIntroStep(
                    number: "4",
                    icon: "lock.shield.fill",
                    title: "Always private",
                    description: "Everything stays on your device. No servers. No cloud AI. No accounts.",
                    color: DS.Palette.forest,
                    isLast: true
                )
            }
            .padding(.horizontal, 20)

            // The tab is labelled "Speak". This said "Record tab" — naming a
            // destination that does not exist — beside a hand pointing LEFT at
            // nothing, while the bar it means is at the bottom.
            HStack(spacing: 10) {
                Image(systemName: "arrow.down")
                    .font(.dv(.callout, weight: .semibold))
                    .foregroundColor(DS.Palette.gold)
                Text("Start on the Speak tab, below")
                    .font(.dv(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(themeManager.textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DS.Palette.gold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)

            // This screen made the same promise THREE times — "entirely on your
            // device", "Everything stays on your device. No servers. No cloud
            // AI. No accounts.", and here "Your Twin never leaves your device".
            // Said once it is a fact; said three times on one scroll it reads as
            // protesting. The middle one, which is the specific one, stays.

            // The first-run branch never had bar clearance — it is applied on
            // the populated branch only — so this footer sat under the floating
            // pill. Same failure this file records having already fixed once,
            // on the other branch.
            Color.clear.frame(height: DailyVoxTabBar.reservedHeight)
        }
        .onAppear {
            // The pulsing core star is decorative. A repeat-forever animation
            // never lets the run loop idle, so skip it under UI testing and
            // respect Reduce Motion; the star simply stays at its dim state.
            guard !Self.animationsDisabledForTesting && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateOrb = true
            }
        }
    }

    private func twinIntroStep(number: String, icon: String, title: String, description: String, color: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Vertical line + dot
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.dv(.subheadline, weight: .semibold))
                        .foregroundColor(color)
                }
                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.15))
                        .frame(width: 2, height: 32)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.dv(.callout, design: .rounded, weight: .semibold))
                    .foregroundColor(themeManager.textColor)
                Text(description)
                    .font(.dv(.footnote, design: .rounded, weight: .regular))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineSpacing(3)
            }
            .padding(.top, 6)

            Spacer()
        }
    }

    // MARK: - Twin Constellation Header

    private var twinOrbHeader: some View {
        VStack(spacing: 16) {
            // The sky, full-bleed and animated — the same object Android
            // draws (SkyView is a port of its `drawSky`). ConstellationView
            // put it in a bordered navy card that did not move, which made the
            // two platforms visibly different products on their hero screen.
            SkyView(entries: skyEntries, named: skyNamed)
                .frame(height: isIPad ? 520 : 430)
                // Escapes the column's 16pt padding so the sky runs edge to
                // edge. Inset, its glow ended on a straight vertical line down
                // both sides — which is exactly what a border looks like.
                .padding(.horizontal, -DS.Space.md)

            // Spec C2: a STAR COUNT, not a percentage. The number is what the
            // user made; a completion figure invites them to finish something
            // that has no end, and reads as a progress bar on their own life.
            HStack(spacing: 8) {
                Text("\(starCount) \u{2726}")
                    .font(.dv(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.goldText)
                Text("\u{00B7}")
                    .foregroundColor(themeManager.secondaryTextColor)
                Text(skyDepth.uppercased())
                    .font(.dv(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(themeManager.goldText)
            }

            // One line of key. The encoding is legible once you know it and
            // invisible until you do, and a sky that needs a paragraph is not
            // worth having.
            Text("NEWEST AT THE CENTRE \u{00B7} AROUND BY HOUR \u{00B7} BRIGHTER IS BETTER")
                .font(.dv(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(0.9)
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.75))
                .multilineTextAlignment(.center)

            Text(constellationSubtitle)
                .font(.dv(.subheadline, design: .rounded, weight: .regular))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Depth disclosure

    private var twinDepthDisclosure: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                showDepth.toggle()
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 8) {
                Text(showDepth ? "HIDE THE DETAIL" : "HOW IT KNOWS")
                    .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                Image(systemName: showDepth ? "chevron.up" : "chevron.down")
                    .font(.dv(size: 10, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(themeManager.secondaryTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.cardBackgroundColor.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showDepth ? "Hide Twin detail" : "Show how your Twin knows you")
    }

    private func twinAction(_ title: String, _ symbol: String,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.dv(size: 14, weight: .semibold))
                Text(title)
                    .font(.dv(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(themeManager.goldText)
            .frame(maxWidth: .infinity, minHeight: 48)
            // A hairline, not a fill. Two tinted blocks under a constellation
            // competed with it; the sky should be the only lit thing on this
            // screen.
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DS.Palette.gold.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - C2: the summary card

    /// One sentence, and the count it rests on.
    ///
    /// The count is not decoration. It is the difference between "you are warm
    /// and expansive" — which is a horoscope — and "warm and expansive, from 84
    /// entries", which is a claim with its own sample size attached. The Twin is
    /// never allowed to sound more certain than its evidence.
    private var twinSummaryCard: some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                Circle().fill(DS.Palette.gold).frame(width: 34, height: 34)
                Text("\u{2726}")
                    .font(.dv(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(DS.Palette.navy)
            }
            Text(twinSummary)
                .font(.dv(size: 12, weight: .medium))
                .foregroundColor(themeManager.textColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(themeManager.cardBackgroundColor))
    }

    /// Ported from Android's `summary(entries:)`, thresholds included, so the
    /// two platforms describe the same journal the same way.
    private var twinSummary: String {
        let scored = entries.compactMap { entry -> Double? in
            guard entry.date != nil else { return nil }
            let mood = Mood(rawValue: entry.mood ?? "") ?? Mood.none
            return (Double(mood.moodValue) - 3.0) / 2.0
        }
        guard scored.count >= 5 else {
            return "Still listening. A few more nights and there will be something to say."
        }
        let v = scored.reduce(0, +) / Double(scored.count)
        let tone: String
        switch v {
        case 0.25...:      tone = "warm, steady"
        case 0.05..<0.25:  tone = "even-handed"
        case -0.15..<0.05: tone = "measured"
        default:           tone = "candid, unsparing"
        }
        let words = entries.reduce(0) { $0 + ($1.text ?? "").split(whereSeparator: \.isWhitespace).count }
        let average = entries.isEmpty ? 0 : words / entries.count
        let length = average > 40 ? "expansive" : "economical"
        // No count in this sentence at all.
        //
        // It used to end "— from 45 entries" while a badge two inches above
        // read "137 ✦" — two numbers for one thing, disagreeing. That was fixed
        // by making both read `starCount`, which left the SAME integer printed
        // four times on one screen: the badge, this sentence, the MIND column,
        // and Writing Stats. A sentence about who someone is does not need to
        // cite its sample size; the badge already states it, once, in gold.
        return "Who you are: \(tone), \(length)."
    }

    // MARK: - C2: dimension stats

    /// Mind · Heart · Graph, as the spec's stat row.
    ///
    /// Body is deliberately NOT a fourth column here: it is the one dimension
    /// that can be empty for a legitimate reason (no Health permission), and a
    /// column reading "—" next to three real numbers reads as a broken feature
    /// rather than a choice the user made. It keeps its own card below, which is
    /// also where the review queue lives.
    private var dimensionStats: some View {
        HStack(spacing: 10) {
            dimensionStat(label: "MIND",
                          value: "\(twin.behavioralPatterns.totalEntries)",
                          caption: "entries kept")
            dimensionStat(label: "HEART",
                          value: heartValue,
                          caption: "average tone")
            dimensionStat(label: "GRAPH",
                          value: "\(graphNodeCount)",
                          caption: "people & topics")
        }
    }

    /// Three numbers, on the page. They were three cards with three fills and
    /// three shadows to carry three integers — the heaviest possible way to say
    /// the lightest possible thing.
    private func dimensionStat(label: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.dv(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.1)
                .foregroundColor(themeManager.secondaryTextColor)
            Text(value)
                .font(.dv(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(themeManager.goldText)
            Text(caption)
                .font(.dv(size: 10.5))
                .foregroundColor(themeManager.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heartValue: String {
        let scored = entries.compactMap { entry -> Double? in
            let mood = Mood(rawValue: entry.mood ?? "") ?? Mood.none
            guard mood != .none else { return nil }
            return (Double(mood.moodValue) - 3.0) / 2.0
        }
        guard !scored.isEmpty else { return "\u{2014}" }
        return String(format: "%+.2f", scored.reduce(0, +) / Double(scored.count))
    }

    private var graphNodeCount: Int {
        let graph = twin.knowledgeGraph
        return graph.topNodes(ofType: .person, limit: 500).count
            + graph.topNodes(ofType: .topic, limit: 500).count
    }

    /// The same thresholds the Android sky uses, so a screenshot from either
    /// phone reports the same depth for the same journal.
    /// The Twin's own count, not `entries.count`. Those disagree — the badge
    /// showed 35 while the line directly beneath it showed 140 stars, because
    /// one counted Core Data rows and the other the Twin's accumulated state.
    /// A header that contradicts its own subtitle is worse than either number.
    private var starCount: Int { twin.behavioralPatterns.totalEntries }

    private var skyDepth: String {
        switch starCount {
        case 200...: return "Deep"
        case 100..<200: return "Established"
        case 40..<100: return "Forming"
        case 10..<40: return "Early"
        default: return "Seed"
        }
    }

    /// Newest first, as the sky expects: the four biggest become named stars
    /// and the rest twinkle.
    private var skyEntries: [SkyEntry] {
        entries.prefix(SkyView.maxDrawnTwinkles).enumerated().map { i, entry in
            let mood = Mood(rawValue: entry.value(forKey: "mood") as? String ?? "") ?? Mood.none
            let when = entry.date ?? Date()
            return SkyEntry(
                id: entry.objectID.uriRepresentation().absoluteString,
                valence: (Double(mood.moodValue) - 3) / 2,
                date: when,
                duration: entry.duration,
                // The seed is only a ±14° jitter now — position itself comes
                // from when the entry was spoken. Still derived from the date so
                // the same journal draws the same sky every launch.
                seed: UInt64(bitPattern: Int64(when.timeIntervalSince1970))
                    ^ UInt64(i &* 7919)
            )
        }
    }

    /// The people the sky names, with what it needs to place them.
    private var skyNamed: [SkyNamed] {
        twin.knowledgeGraph.topNodes(ofType: .person, limit: 4).map {
            SkyNamed(label: $0.label, mentions: $0.mentions, lastSeen: $0.lastSeen)
        }
    }

    private var recentMoods: [Double] {
        entries.prefix(50).map { entry in
            let moodString = entry.value(forKey: "mood") as? String ?? ""
            switch moodString.lowercased() {
            case "happy": return 0.8
            case "excited": return 0.9
            case "grateful": return 0.7
            case "calm": return 0.4
            case "tired": return -0.1
            case "anxious": return -0.4
            case "sad": return -0.6
            case "angry": return -0.8
            default: return 0.0
            }
        }
    }

    private var topKnowledgeNodes: [(String, Int)] {
        let people = twin.knowledgeGraph.topNodes(ofType: .person, limit: 2)
        let topics = twin.knowledgeGraph.topNodes(ofType: .topic, limit: 2)
        return (people + topics).map { ($0.label, $0.mentions) }
    }

    /// No count here any more — the badge above owns the number, and printing
    /// it twice in two type sizes made the header look like a data problem.
    private var constellationSubtitle: String {
        let count = starCount
        if count == 0 { return "Speak to plant your first star" }
        if count < 5 { return "Your constellation is forming" }
        if count < 15 { return "Patterns emerging" }
        if count < 30 { return "Your inner sky deepens" }
        return "A sky made of you"
    }

    // MARK: - Ask Your Twin Button

    private var askTwinButton: some View {
        NavigationLink(destination: TwinChatView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.accentColor.opacity(0.7),
                                    themeManager.accentColor.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 16
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.dv(.footnote))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Your Twin")
                        .font(.dv(.subheadline, weight: .bold))
                        .foregroundColor(themeManager.textColor)
                    Text("Get insights from your journal data")
                        .font(.dv(.caption))
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.dv(.caption))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Orb Color (reflects emotional state)

    private var orbColor: Color {
        let valence = twin.emotionalSignature.baselineValence
        if valence > 0.3 { return DS.Palette.forest }
        if valence > 0.1 { return DS.Palette.sage }
        if valence > -0.1 { return DS.Palette.terracotta }
        if valence > -0.3 { return DS.Palette.gold }
        return DS.Palette.coral
    }

    // MARK: - Maturity Badge

    private var maturityBadge: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.cardBackgroundColor)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, DS.Palette.gold, themeManager.accentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * twin.summary.maturityLevel.progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(twin.summary.dataPointsCollected) data points")
                    .font(.dv(.caption))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(twin.summary.maturityLevel.rawValue.capitalized)
                    .font(.dv(.caption, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
            }
        }
        // No extra horizontal padding: the parent VStack already carries the
        // 16pt grid inset, so the bar aligns flush with the cards around it.
    }

    // MARK: - Section Picker

    /// Chips snap to alignment so the row never comes to rest showing a half-cut word, and the
    /// selected chip is scrolled into view — previously selecting a middle section left the row
    /// clipped mid-word at both edges, which reads as a rendering bug rather than a scroll hint.
    private var sectionPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TwinSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedSection = section
                            }
                        } label: {
                            Text(section.rawValue)
                                .font(.dv(.subheadline, weight: selectedSection == section ? .bold : .regular))
                                .foregroundColor(selectedSection == section ? .white : themeManager.textColor)
                                .padding(.horizontal, 16)
                                // ~36pt against the 44pt floor, on the control
                                // that navigates this entire screen.
                                .frame(minHeight: 44)
                                .background(
                                    Capsule()
                                        .fill(selectedSection == section ? themeManager.accentColor : themeManager.cardBackgroundColor)
                                )
                                .contentShape(Capsule())
                        }
                        .id(section)
                        // VoiceOver otherwise reads these as six identical unlabelled buttons
                        // with no indication of which section is active.
                        .accessibilityLabel(section.rawValue)
                        .accessibilityAddTraits(selectedSection == section ? [.isSelected] : [])
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: selectedSection) { _, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 16) {
            // Twin Predictions — "Your Twin Thinks..."
            TwinPredictionsSection(entries: Array(entries))

            // Shareable Personality Card
            TwinProfileCardSection()

            if !twin.summary.personalitySnapshot.isEmpty {
                twinCard(title: "Who You Are", icon: "person.fill", content: twin.summary.personalitySnapshot)
            }
            if !twin.summary.communicationSnapshot.isEmpty {
                twinCard(title: "How You Express", icon: "text.bubble.fill", content: twin.summary.communicationSnapshot)
            }
            if !twin.summary.emotionalSnapshot.isEmpty {
                twinCard(title: "How You Feel", icon: "heart.fill", content: twin.summary.emotionalSnapshot)
            }
            if !twin.summary.lifeSnapshot.isEmpty {
                twinCard(title: "Your World", icon: "globe", content: twin.summary.lifeSnapshot)
            }
            if !twin.summary.growthSnapshot.isEmpty {
                twinCard(title: "Your Growth", icon: "arrow.up.right", content: twin.summary.growthSnapshot)
            }

            if twin.summary.dataPointsCollected < 5 {
                emptyStateCard
            }
        }
    }

    // MARK: - Personality Section

    /// The v1.6 learned openness estimate, if the head is past its population
    /// floor. Read once per render from the engine — deterministic, on-device.
    private var learnedOpenness: TraitEstimate? {
        DigitalTwinEngine.shared.personalityEstimates().first { $0.trait == "openness" }
    }

    private func confidenceWord(_ confidence: Double) -> String {
        switch confidence {
        case ..<0.2:  return "low"
        case ..<0.4:  return "growing"
        default:      return "moderate"
        }
    }

    private var personalitySection: some View {
        VStack(spacing: 16) {
            // Communication Style
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Communication Style", icon: "text.quote")

                traitBar(label: "Expressiveness", value: twin.communicationStyle.expressiveness, lowLabel: "Reserved", highLabel: "Expressive")
                traitBar(label: "Directness", value: twin.communicationStyle.directness, lowLabel: "Nuanced", highLabel: "Direct")
                traitBar(label: "Formality", value: twin.communicationStyle.formalityLevel, lowLabel: "Casual", highLabel: "Formal")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Learned trait (v1.6) — a small on-device model, trained on real
            // consented human writing, that estimates openness from your entries.
            // Shown only once your diary is deep enough for it to speak.
            if let openness = learnedOpenness, openness.basis == .learnedHead {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Learned Trait", icon: "sparkles")
                    traitBar(label: "Openness", value: openness.value, lowLabel: "Grounded", highLabel: "Open")
                    Text("A learned estimate — \(confidenceWord(openness.confidence)) confidence. It grows more sure as you write.")
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            // Thinking Style
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Thinking Style", icon: "brain")

                traitBar(label: "Processing", value: twin.thoughtPatterns.analyticalScore, lowLabel: "Intuitive", highLabel: "Analytical")
                traitBar(label: "Abstraction", value: twin.thoughtPatterns.abstractScore, lowLabel: "Concrete", highLabel: "Abstract")
                traitBar(label: "Time Focus", value: twin.thoughtPatterns.futureOriented, lowLabel: "Past", highLabel: "Future")
                traitBar(label: "Perspective", value: twin.thoughtPatterns.selfFocused, lowLabel: "Others", highLabel: "Self")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Growth Indicators
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Growth Indicators", icon: "arrow.up.heart.fill")

                traitBar(label: "Growth Mindset", value: twin.thoughtPatterns.growthMindsetScore, lowLabel: "Fixed", highLabel: "Growth")
                traitBar(label: "Self-Awareness", value: twin.thoughtPatterns.selfAwarenessLevel, lowLabel: "Developing", highLabel: "Deep")
                traitBar(label: "Gratitude", value: twin.thoughtPatterns.gratitudeTendency, lowLabel: "Occasional", highLabel: "Frequent")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Signature Words
            if !twin.communicationStyle.signatureWords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Your Vocabulary", icon: "textformat")

                    let topWords = twin.communicationStyle.signatureWords
                        .sorted { $0.value > $1.value }
                        .prefix(15)

                    FlowLayout(spacing: 8) {
                        ForEach(Array(topWords), id: \.key) { word, count in
                            Text(word)
                                .font(.dv(.caption, weight: count > 3 ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(themeManager.accentColor.opacity(Double(min(count, 10)) / 15.0 + 0.1))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            // Share Your Twin — only show with enough data
            if twin.behavioralPatterns.totalEntries >= 10 {
                shareYourTwinButton
            }
        }
        .sheet(isPresented: $showTwinShareSheet, onDismiss: { ReviewManager.shared.recordPositiveMoment() }) {
            if let image = twinShareImage {
                ShareSheet(activityItems: [
                    image,
                    PersonalityCardRenderer.shareText
                ])
                .appThemedSheet()
            }
        }
    }

    // MARK: - Share Your Twin Button

    private var shareYourTwinButton: some View {
        Button {
            shareTwinCard()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.dv(.callout, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Your Twin")
                        .font(.dv(.subheadline, weight: .bold))
                    Text("Show the world your personality card")
                        .font(.dv(.caption2, weight: .regular))
                        .opacity(0.6)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.dv(.footnote, weight: .semibold))
                    .opacity(0.4)
            }
            .foregroundColor(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.Palette.sage.opacity(0.4), DS.Palette.terracotta.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.Palette.sage.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func shareTwinCard() {
        Task { @MainActor in
            let profile = TwinProfileGenerator.generate()
            if let image = PersonalityCardRenderer.renderCard(profile: profile, format: .story) {
                twinShareImage = image
                showTwinShareSheet = true
            }
        }
    }

    // MARK: - Emotions Section

    private var emotionsSection: some View {
        VStack(spacing: 16) {
            // Emotional Baseline
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Emotional Baseline", icon: "heart.circle.fill")

                HStack(spacing: 20) {
                    emotionMeter(label: "Valence", value: (twin.emotionalSignature.baselineValence + 1) / 2, color: twin.emotionalSignature.baselineValence > 0 ? DS.Palette.forest : DS.Palette.gold)
                    emotionMeter(label: "Arousal", value: twin.emotionalSignature.baselineArousal, color: DS.Palette.sage)
                    emotionMeter(label: "Range", value: twin.emotionalSignature.emotionalRange, color: DS.Palette.sage)
                }

                if twin.emotionalSignature.sentimentTrend != 0 {
                    HStack {
                        Image(systemName: twin.emotionalSignature.sentimentTrend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(twin.emotionalSignature.sentimentTrend > 0 ? DS.Palette.forest : DS.Palette.gold)
                        Text("Emotional trajectory is \(twin.emotionalSignature.sentimentTrend > 0 ? "improving" : "declining")")
                            .font(.dv(.caption))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Time-Based Mood
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Mood Rhythms", icon: "clock.fill")

                HStack(spacing: 0) {
                    moodTimeBlock(label: "Morning", sentiment: twin.emotionalSignature.morningMood, icon: "sunrise.fill")
                    moodTimeBlock(label: "Evening", sentiment: twin.emotionalSignature.eveningMood, icon: "sunset.fill")
                    moodTimeBlock(label: "Weekday", sentiment: twin.emotionalSignature.weekdayMood, icon: "briefcase.fill")
                    moodTimeBlock(label: "Weekend", sentiment: twin.emotionalSignature.weekendMood, icon: "figure.walk")
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Mood Frequency
            if !twin.emotionalSignature.emotionFrequency.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Emotion Frequency", icon: "chart.bar.fill")

                    let sorted = twin.emotionalSignature.emotionFrequency.sorted { $0.value > $1.value }
                    let maxVal = sorted.first?.value ?? 1

                    ForEach(sorted.prefix(6), id: \.key) { mood, count in
                        HStack {
                            Image(systemName: moodEmoji(mood))
                                .font(.dv(.caption))
                            Text(mood.capitalized)
                                .font(.dv(.caption))
                                .frame(width: 60, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(moodColor(mood))
                                    .frame(width: geo.size.width * (count / maxVal))
                            }
                            .frame(height: 16)
                            Text("\(Int(count))")
                                .font(.dv(.caption2))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            // Positive & Negative Triggers
            if !twin.emotionalSignature.positiveTriggersTopics.isEmpty || !twin.emotionalSignature.negativeTriggersTopics.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Emotional Triggers", icon: "bolt.heart.fill")

                    if !twin.emotionalSignature.positiveTriggersTopics.isEmpty {
                        Text("Lifts your mood")
                            .font(.dv(.caption, weight: .bold))
                            .foregroundColor(DS.Palette.forest)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.positiveTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.dv(.caption))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DS.Palette.forest.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    if !twin.emotionalSignature.negativeTriggersTopics.isEmpty {
                        Text("Weighs on you")
                            .font(.dv(.caption, weight: .bold))
                            .foregroundColor(DS.Palette.gold)
                            .padding(.top, 4)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.negativeTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.dv(.caption))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DS.Palette.gold.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: - World Section (Knowledge Graph)

    private var worldSection: some View {
        VStack(spacing: 16) {
            // People
            knowledgeSection(title: "People In Your Life", icon: "person.2.fill", type: .person)

            // Places
            knowledgeSection(title: "Places That Matter", icon: "mappin.circle.fill", type: .place)

            // Topics
            knowledgeSection(title: "Themes & Topics", icon: "tag.fill", type: .topic)

            // Goals
            knowledgeSection(title: "Your Goals", icon: "star.fill", type: .goal)

            // Fears
            knowledgeSection(title: "What Concerns You", icon: "exclamationmark.triangle.fill", type: .fear)

            if twin.knowledgeGraph.nodes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.dv(size: 40))
                        .foregroundColor(themeManager.accentColor.opacity(0.5))
                    Text("Your world map will build as you journal")
                        .font(.dv(.subheadline))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: - Patterns Section

    private var patternsSection: some View {
        VStack(spacing: 16) {
            // Activity Heatmap
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("When You Write", icon: "clock.fill")

                // Hourly distribution
                let maxHourly = Double(twin.behavioralPatterns.hourlyActivity.values.max() ?? 1)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        let count = Double(twin.behavioralPatterns.hourlyActivity[hour] ?? 0)
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.Palette.sage.opacity(count / max(1, maxHourly)))
                                .frame(height: max(4, 60 * (count / max(1, maxHourly))))

                            if hour % 6 == 0 {
                                Text("\(hour)")
                                    .font(.dv(.caption2))
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                        }
                    }
                }
                .frame(height: 80)

                if let peak = twin.behavioralPatterns.peakHour {
                    Text("Peak writing time: \(formatHour(peak))")
                        .font(.dv(.caption))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Day of Week
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Your Week", icon: "calendar")

                let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                let maxDaily = Double(twin.behavioralPatterns.dayOfWeekActivity.values.max() ?? 1)

                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        let count = Double(twin.behavioralPatterns.dayOfWeekActivity[day] ?? 0)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Palette.sage.opacity(count / max(1, maxDaily) * 0.8 + 0.1))
                                .frame(height: max(8, 50 * (count / max(1, maxDaily))))

                            Text(days[day - 1])
                                .font(.dv(.caption2))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
                .frame(height: 70)
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Writing Stats
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Writing Stats", icon: "doc.text.fill")

                HStack(spacing: 20) {
                    // "Entries" is not here: it is the badge at the top of this
                    // same screen, and the MIND column between the two.
                    statItem(value: formatNumber(twin.behavioralPatterns.totalWords), label: "Words")
                    statItem(value: "\(Int(twin.communicationStyle.averageSentenceLength))", label: "Avg Sentence")
                    statItem(value: String(format: "%.0f%%", twin.communicationStyle.vocabularyRichness * 100), label: "Vocab Richness")
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Preferences
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Your Preferences", icon: "slider.horizontal.3")

                traitBar(label: "Input Mode", value: twin.behavioralPatterns.prefersVoice, lowLabel: "Text", highLabel: "Voice")
                traitBar(label: "Entry Length", value: 1 - twin.behavioralPatterns.prefersShortEntries, lowLabel: "Brief", highLabel: "Detailed")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Reusable Components

    private func twinCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(themeManager.accentColor)
                Text(title)
                    .font(.dv(.headline))
                    .foregroundColor(themeManager.textColor)
            }
            Text(content)
                .font(.dv(.subheadline))
                .foregroundColor(themeManager.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.accentColor)
            Text(title)
                .font(.dv(.headline))
                .foregroundColor(themeManager.textColor)
        }
    }

    private func traitBar(label: String, value: Double, lowLabel: String, highLabel: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.dv(.caption))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Palette.inkMute.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, DS.Palette.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0.05, min(1, value)))
                }
            }
            .frame(height: 8)
            HStack {
                Text(lowLabel)
                    .font(.dv(.caption2))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(highLabel)
                    .font(.dv(.caption2))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
    }

    private func emotionMeter(label: String, value: Double, color: Color) -> some View {
        let meterSize: CGFloat = isIPad ? 70 : 50
        let lineWidth: CGFloat = isIPad ? 6 : 4
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(DS.Palette.inkMute.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.05, value))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f%%", value * 100))
                    .font(.dv(size: isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(themeManager.textColor)
            }
            .frame(width: meterSize, height: meterSize)

            Text(label)
                .font(.dv(size: isIPad ? 12 : 10))
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }

    private func moodTimeBlock(label: String, sentiment: Double, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(sentimentColor(sentiment))
                .font(.dv(.title3))

            Text(sentimentLabel(sentiment))
                .font(.dv(.caption2, weight: .medium))
                .foregroundColor(sentimentColor(sentiment))

            Text(label)
                .font(.dv(.caption2))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func knowledgeSection(title: String, icon: String, type: PersonalKnowledgeGraph.KnowledgeNode.NodeType) -> some View {
        let nodes = twin.knowledgeGraph.topNodes(ofType: type, limit: 8)
        return Group {
            if !nodes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title, icon: icon)

                    ForEach(nodes, id: \.id) { node in
                        HStack {
                            Circle()
                                .fill(sentimentColor(node.sentimentAssociation))
                                .frame(width: 8, height: 8)

                            Text(node.label)
                                .font(.dv(.subheadline))
                                .foregroundColor(themeManager.textColor)

                            Spacer()

                            Text("\(node.mentions)x")
                                .font(.dv(.caption))
                                .foregroundColor(themeManager.secondaryTextColor)

                            // Importance indicator
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(Double(i) / 5.0 < node.importance ? themeManager.accentColor : DS.Palette.inkMute.opacity(0.2))
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.dv(.title3, weight: .bold))
                .foregroundColor(themeManager.accentColor)
            Text(label)
                .font(.dv(.caption2))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.dv(size: 40))
                .foregroundColor(DS.Palette.gold.opacity(0.6))

            Text("Your constellation awaits")
                .font(.dv(.body, design: .rounded, weight: .semibold))
                .foregroundColor(themeManager.textColor)

            Text("Every journal entry becomes a star. Speak for 42 seconds — or longer — and watch your inner sky take shape.")
                .font(.dv(.subheadline, design: .rounded, weight: .regular))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 16) {
                Label("Voice entries", systemImage: "mic.fill")
                Label("Written entries", systemImage: "square.and.pencil")
            }
            .font(.dv(.caption))
            .foregroundColor(themeManager.accentColor)
        }
        .padding(24)
        .background(themeManager.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var privacyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(DS.Palette.forest)
            Text("100% on-device. Your twin never leaves your device.")
                .font(.dv(.caption))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DS.Palette.forest.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func sentimentColor(_ sentiment: Double) -> Color {
        if sentiment > 0.3 { return DS.Palette.forest }
        if sentiment > 0.1 { return DS.Palette.sage }
        if sentiment > -0.1 { return DS.Palette.inkMute }
        if sentiment > -0.3 { return DS.Palette.gold }
        return DS.Palette.coral
    }

    private func sentimentLabel(_ sentiment: Double) -> String {
        if sentiment > 0.3 { return "Great" }
        if sentiment > 0.1 { return "Good" }
        if sentiment > -0.1 { return "Neutral" }
        if sentiment > -0.3 { return "Low" }
        return "Tough"
    }

    private func moodEmoji(_ mood: String) -> String {
        switch mood.lowercased() {
        case "happy": return "sun.max.fill"
        case "calm": return "leaf.fill"
        case "grateful": return "heart.fill"
        case "excited": return "star.fill"
        case "tired": return "moon.zzz.fill"
        case "anxious": return "wind"
        case "sad": return "cloud.rain.fill"
        case "angry": return "flame.fill"
        default: return "circle.fill"
        }
    }

    private func moodColor(_ mood: String) -> Color {
        switch mood.lowercased() {
        case "happy": return DS.Palette.gold
        case "calm": return DS.Palette.sage
        case "grateful": return DS.Palette.forest
        case "excited": return DS.Palette.gold
        case "tired": return .gray
        case "anxious": return DS.Palette.terracotta
        case "sad": return DS.Palette.terracotta
        case "angry": return .red
        default: return .gray
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12am" }
        if hour < 12 { return "\(hour)am" }
        if hour == 12 { return "12pm" }
        return "\(hour - 12)pm"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}

// MARK: - Flow Layout (for word clouds)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    NavigationView {
        DigitalTwinView()
    }
}

// MARK: - Predictions View (consumes the DailyVoxTwinEngine prediction engine)

/// "Your Twin Thinks..." section. The prediction *engine* lives in the
/// DailyVoxTwinEngine package; this view maps the app's DiaryEntry values into
/// TwinEntryInput and renders the results.
struct TwinPredictionsSection: View {
    let entries: [DiaryEntry]
    @State private var predictions: [TwinPrediction] = []

    var body: some View {
        Group {
            if !predictions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(DS.Palette.terracotta)
                        Text("Your Twin Thinks...")
                            .font(.dv(.headline))
                    }

                    ForEach(predictions) { prediction in
                        predictionCard(prediction)
                    }
                }
            }
        }
        .onAppear { predictions = TwinPredictionEngine.generatePredictions(entries: entries.map(\.twinInput)) }
    }

    private func predictionCard(_ prediction: TwinPrediction) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(prediction.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: prediction.icon)
                    .font(.dv(.subheadline))
                    .foregroundColor(prediction.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.message)
                    .font(.dv(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = prediction.detail {
                    Text(detail)
                        .font(.dv(.caption))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // v1.6: honest confidence — the Twin says how sure it is.
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.dv(.caption2))
                    Text(prediction.confidenceBand.label)
                        .font(.dv(.caption2, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
