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
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Matches the launch arguments ScreenshotTests passes. Repeat-forever
    /// animations keep the run loop busy, so XCUITest never sees the app idle.
    private static let animationsDisabledForTesting =
        ProcessInfo.processInfo.arguments.contains("-UITesting") ||
        ProcessInfo.processInfo.arguments.contains("-ScreenshotMode")
    @State private var selectedSection: TwinSection = .overview
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
                    // Digital Twin Orb Header
                    twinOrbHeader

                    // Ask Your Twin
                    askTwinButton

                    // Maturity indicator
                    maturityBadge

                    // How well the Twin actually knows you (self-prediction fidelity)
                    TwinResolutionCard()

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

                    // Privacy badge
                    privacyBadge
                }
                .padding()
                .frame(maxWidth: isIPad ? 700 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Your Digital Twin")
        .background { WarmBackground() }
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
                                Color(red: 0.075, green: 0.075, blue: 0.175),
                                Color(red: 0.10, green: 0.08, blue: 0.20)
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
                            .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(animateOrb ? 0.12 : 0.06))
                            .frame(width: 60, height: 60)
                        Circle()
                            .fill(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.3))
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(Color(red: 0.957, green: 0.933, blue: 0.878).opacity(0.7))
                            .frame(width: 8, height: 8)
                    }

                    Text("Your sky is empty — for now")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.957, green: 0.933, blue: 0.878).opacity(0.5))
                }
            }
            .padding(.horizontal)

            // Introduction steps
            VStack(spacing: 20) {
                Text("Meet your Digital Twin")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.textColor)

                Text("A private AI that learns who you are — entirely on your device.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
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
                    description: "Record a voice entry on the Record tab. 42 seconds is the sweet spot — take as long as you need.",
                    color: Color(red: 0.357, green: 0.486, blue: 0.420),
                    isLast: false
                )
                twinIntroStep(
                    number: "2",
                    icon: "sparkle",
                    title: "Stars appear",
                    description: "Each entry becomes a star in your constellation, colored by mood.",
                    color: Color(red: 0.831, green: 0.647, blue: 0.278),
                    isLast: false
                )
                twinIntroStep(
                    number: "3",
                    icon: "brain.head.profile",
                    title: "Your Twin learns",
                    description: "Four models — Mind, Heart, Voice, Graph — build your personality profile.",
                    color: Color(red: 0.769, green: 0.451, blue: 0.420),
                    isLast: false
                )
                twinIntroStep(
                    number: "4",
                    icon: "lock.shield.fill",
                    title: "Always private",
                    description: "Everything stays on your device. No servers. No cloud AI. No accounts.",
                    color: Color(red: 0.420, green: 0.620, blue: 0.482),
                    isLast: true
                )
            }
            .padding(.horizontal, 20)

            // CTA hint
            HStack(spacing: 10) {
                Image(systemName: "hand.point.left.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.831, green: 0.647, blue: 0.278))
                Text("Switch to the Record tab to begin")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)

            // Privacy assurance
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.420, green: 0.620, blue: 0.482))
                Text("Your Twin never leaves your device")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
            }
            .padding(.bottom, 20)
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
                        .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.textColor)
                Text(description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
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
            // Constellation visualization
            ConstellationView.fromTwin(
                entryCount: twin.behavioralPatterns.totalEntries,
                moods: recentMoods,
                knowledgeNodes: topKnowledgeNodes
            )
            .frame(height: isIPad ? 360 : 280)

            Text("Your Digital Twin")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.textColor)

            Text(constellationSubtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(themeManager.secondaryTextColor)
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

    private var constellationSubtitle: String {
        let count = twin.behavioralPatterns.totalEntries
        if count == 0 { return "Speak to plant your first star" }
        if count < 5 { return "\(count) stars · your constellation is forming" }
        if count < 15 { return "\(count) stars · patterns emerging" }
        if count < 30 { return "\(count) stars · your inner sky deepens" }
        return "\(count) stars · \(twin.summary.maturityLevel.rawValue.lowercased())"
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
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Your Twin")
                        .font(.subheadline.bold())
                        .foregroundColor(themeManager.textColor)
                    Text("Get insights from your journal data")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
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
                                colors: [themeManager.accentColor, Color(red: 0.831, green: 0.647, blue: 0.278), themeManager.accentColor.opacity(0.6)],
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
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(twin.summary.maturityLevel.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundColor(themeManager.accentColor)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TwinSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSection = section
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(.subheadline.weight(selectedSection == section ? .bold : .regular))
                            .foregroundColor(selectedSection == section ? .white : themeManager.textColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSection == section ? themeManager.accentColor : themeManager.cardBackgroundColor)
                            )
                    }
                }
            }
            .padding(.horizontal)
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
                                .font(.caption.weight(count > 3 ? .bold : .regular))
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
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Your Twin")
                        .font(.system(size: 15, weight: .bold))
                    Text("Show the world your personality card")
                        .font(.system(size: 11, weight: .regular))
                        .opacity(0.6)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
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
                            .font(.caption)
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
                                .font(.caption)
                            Text(mood.capitalized)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(moodColor(mood))
                                    .frame(width: geo.size.width * (count / maxVal))
                            }
                            .frame(height: 16)
                            Text("\(Int(count))")
                                .font(.caption2)
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
                            .font(.caption.bold())
                            .foregroundColor(DS.Palette.forest)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.positiveTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DS.Palette.forest.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    if !twin.emotionalSignature.negativeTriggersTopics.isEmpty {
                        Text("Weighs on you")
                            .font(.caption.bold())
                            .foregroundColor(DS.Palette.gold)
                            .padding(.top, 4)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.negativeTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.caption)
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
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.accentColor.opacity(0.5))
                    Text("Your world map will build as you journal")
                        .font(.subheadline)
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
                                    .font(.system(size: 8))
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                        }
                    }
                }
                .frame(height: 80)

                if let peak = twin.behavioralPatterns.peakHour {
                    Text("Peak writing time: \(formatHour(peak))")
                        .font(.caption)
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
                                .font(.system(size: 10))
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
                    statItem(value: "\(twin.behavioralPatterns.totalEntries)", label: "Entries")
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
                    .font(.headline)
                    .foregroundColor(themeManager.textColor)
            }
            Text(content)
                .font(.subheadline)
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
                .font(.headline)
                .foregroundColor(themeManager.textColor)
        }
    }

    private func traitBar(label: String, value: Double, lowLabel: String, highLabel: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, Color(red: 0.831, green: 0.647, blue: 0.278)],
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
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(highLabel)
                    .font(.system(size: 9))
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.05, value))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(themeManager.textColor)
            }
            .frame(width: meterSize, height: meterSize)

            Text(label)
                .font(.system(size: isIPad ? 12 : 10))
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }

    private func moodTimeBlock(label: String, sentiment: Double, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(sentimentColor(sentiment))
                .font(.title3)

            Text(sentimentLabel(sentiment))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(sentimentColor(sentiment))

            Text(label)
                .font(.system(size: 9))
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
                                .font(.subheadline)
                                .foregroundColor(themeManager.textColor)

                            Spacer()

                            Text("\(node.mentions)x")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)

                            // Importance indicator
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(Double(i) / 5.0 < node.importance ? themeManager.accentColor : Color.gray.opacity(0.2))
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
                .font(.title3.bold())
                .foregroundColor(themeManager.accentColor)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 0.831, green: 0.647, blue: 0.278).opacity(0.6))

            Text("Your constellation awaits")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.textColor)

            Text("Every journal entry becomes a star. Speak for 42 seconds — or longer — and watch your inner sky take shape.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 16) {
                Label("Voice entries", systemImage: "mic.fill")
                Label("Written entries", systemImage: "square.and.pencil")
            }
            .font(.caption)
            .foregroundColor(themeManager.accentColor)
        }
        .padding(24)
        .background(themeManager.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var privacyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(Color(red: 0.420, green: 0.620, blue: 0.482))
            Text("100% on-device. Your twin never leaves your device.")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.420, green: 0.620, blue: 0.482).opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func sentimentColor(_ sentiment: Double) -> Color {
        if sentiment > 0.3 { return DS.Palette.forest }
        if sentiment > 0.1 { return DS.Palette.sage }
        if sentiment > -0.1 { return .gray }
        if sentiment > -0.3 { return DS.Palette.gold }
        return .red
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
                            .font(.headline)
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
                    .font(.system(size: 15))
                    .foregroundColor(prediction.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = prediction.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
