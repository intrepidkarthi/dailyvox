//
//  DigitalTwinView.swift
//  solyn
//
//  Your Digital Twin - a visual mirror of your inner world.
//  All data stays on-device. Your twin is yours alone.
//

import SwiftUI

struct DigitalTwinView: View {
    @ObservedObject private var twin = DigitalTwinEngine.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedSection: TwinSection = .overview
    @State private var showingDetail = false
    @State private var animateOrb = false

    enum TwinSection: String, CaseIterable {
        case overview = "Overview"
        case personality = "Personality"
        case emotions = "Emotions"
        case world = "My World"
        case patterns = "Patterns"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Digital Twin Orb Header
                twinOrbHeader

                // Maturity indicator
                maturityBadge

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
        }
        .navigationTitle("Your Digital Twin")
        .background(themeManager.backgroundColor.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateOrb = true
            }
        }
    }

    // MARK: - Twin Orb Header

    private var twinOrbHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(0.3),
                                orbColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateOrb ? 1.1 : 0.95)

                // Inner orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(0.8),
                                orbColor.opacity(0.4),
                                orbColor.opacity(0.2)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: orbColor.opacity(0.5), radius: 20)
                    .scaleEffect(animateOrb ? 1.05 : 0.98)

                // Center icon
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            Text("Your Digital Twin")
                .font(.title2.bold())
                .foregroundColor(themeManager.textColor)

            Text(twin.summary.maturityLevel.description)
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }

    // MARK: - Orb Color (reflects emotional state)

    private var orbColor: Color {
        let valence = twin.emotionalSignature.baselineValence
        if valence > 0.3 { return .green }
        if valence > 0.1 { return .blue }
        if valence > -0.1 { return .purple }
        if valence > -0.3 { return .orange }
        return .pink
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
                                colors: [themeManager.accentColor, .teal, themeManager.accentColor.opacity(0.6)],
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
            .cornerRadius(16)

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
            .cornerRadius(16)

            // Growth Indicators
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Growth Indicators", icon: "arrow.up.heart.fill")

                traitBar(label: "Growth Mindset", value: twin.thoughtPatterns.growthMindsetScore, lowLabel: "Fixed", highLabel: "Growth")
                traitBar(label: "Self-Awareness", value: twin.thoughtPatterns.selfAwarenessLevel, lowLabel: "Developing", highLabel: "Deep")
                traitBar(label: "Gratitude", value: twin.thoughtPatterns.gratitudeTendency, lowLabel: "Occasional", highLabel: "Frequent")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(16)

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
                .cornerRadius(16)
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
                    emotionMeter(label: "Valence", value: (twin.emotionalSignature.baselineValence + 1) / 2, color: twin.emotionalSignature.baselineValence > 0 ? .green : .orange)
                    emotionMeter(label: "Arousal", value: twin.emotionalSignature.baselineArousal, color: .blue)
                    emotionMeter(label: "Range", value: twin.emotionalSignature.emotionalRange, color: .teal)
                }

                if twin.emotionalSignature.sentimentTrend != 0 {
                    HStack {
                        Image(systemName: twin.emotionalSignature.sentimentTrend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(twin.emotionalSignature.sentimentTrend > 0 ? .green : .orange)
                        Text("Emotional trajectory is \(twin.emotionalSignature.sentimentTrend > 0 ? "improving" : "declining")")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(16)

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
            .cornerRadius(16)

            // Mood Frequency
            if !twin.emotionalSignature.emotionFrequency.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Emotion Frequency", icon: "chart.bar.fill")

                    let sorted = twin.emotionalSignature.emotionFrequency.sorted { $0.value > $1.value }
                    let maxVal = sorted.first?.value ?? 1

                    ForEach(sorted.prefix(6), id: \.key) { mood, count in
                        HStack {
                            Text(moodEmoji(mood))
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
                .cornerRadius(16)
            }

            // Positive & Negative Triggers
            if !twin.emotionalSignature.positiveTriggersTopics.isEmpty || !twin.emotionalSignature.negativeTriggersTopics.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Emotional Triggers", icon: "bolt.heart.fill")

                    if !twin.emotionalSignature.positiveTriggersTopics.isEmpty {
                        Text("Lifts your mood")
                            .font(.caption.bold())
                            .foregroundColor(.green)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.positiveTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    if !twin.emotionalSignature.negativeTriggersTopics.isEmpty {
                        Text("Weighs on you")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                            .padding(.top, 4)

                        FlowLayout(spacing: 6) {
                            ForEach(Array(twin.emotionalSignature.negativeTriggersTopics.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { topic, _ in
                                Text(topic.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .cornerRadius(16)
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
                .cornerRadius(16)
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
                                .fill(Color.teal.opacity(count / max(1, maxHourly)))
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
            .cornerRadius(16)

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
                                .fill(Color.blue.opacity(count / max(1, maxDaily) * 0.8 + 0.1))
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
            .cornerRadius(16)

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
            .cornerRadius(16)

            // Preferences
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Your Preferences", icon: "slider.horizontal.3")

                traitBar(label: "Input Mode", value: twin.behavioralPatterns.prefersVoice, lowLabel: "Text", highLabel: "Voice")
                traitBar(label: "Entry Length", value: 1 - twin.behavioralPatterns.prefersShortEntries, lowLabel: "Brief", highLabel: "Detailed")
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(16)
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
        .cornerRadius(16)
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
                                colors: [themeManager.accentColor, .teal],
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
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.05, value))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.textColor)
            }
            .frame(width: 50, height: 50)

            Text(label)
                .font(.system(size: 10))
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
                .cornerRadius(16)
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
                .foregroundColor(themeManager.accentColor.opacity(0.5))

            Text("Your Digital Twin is being born")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            Text("Keep journaling with DailyVox. Your twin learns from every entry, building a private mirror of your inner world.")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label("Voice entries", systemImage: "mic.fill")
                Label("Written entries", systemImage: "square.and.pencil")
            }
            .font(.caption)
            .foregroundColor(themeManager.accentColor)
        }
        .padding(24)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
    }

    private var privacyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.green)
            Text("100% on-device. Your twin never leaves your phone.")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func sentimentColor(_ sentiment: Double) -> Color {
        if sentiment > 0.3 { return .green }
        if sentiment > 0.1 { return .blue }
        if sentiment > -0.1 { return .gray }
        if sentiment > -0.3 { return .orange }
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
        case "happy": return "😊"
        case "calm": return "😌"
        case "grateful": return "🙏"
        case "excited": return "🤩"
        case "tired": return "😴"
        case "anxious": return "😰"
        case "sad": return "😢"
        case "angry": return "😤"
        default: return "😐"
        }
    }

    private func moodColor(_ mood: String) -> Color {
        switch mood.lowercased() {
        case "happy": return .yellow
        case "calm": return .blue
        case "grateful": return .green
        case "excited": return .orange
        case "tired": return .gray
        case "anxious": return .purple
        case "sad": return .indigo
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
