//
//  DigitalTwinEngine.swift
//  solyn
//
//  The Digital Twin - a privacy-first mirror of your mind.
//
//  This engine builds a comprehensive personal model that learns:
//  - Your communication style and vocabulary patterns
//  - Emotional signatures and baseline states
//  - Thought patterns and cognitive tendencies
//  - Personal knowledge graph (people, places, topics, connections)
//  - Behavioral patterns (when you write, what triggers you)
//  - Predictive modeling (anticipating needs, moods, topics)
//
//  Everything stays on-device. Your twin is yours alone.
//
//  Based on:
//  - Mirror Neuron Theory (Rizzolatti, 1996)
//  - Personal Construct Theory (Kelly, 1955)
//  - Spreading Activation (Collins & Loftus, 1975)
//  - Circadian Rhythm Psychology
//

import Foundation
import NaturalLanguage
import CoreData

// MARK: - Communication Style Model

/// Captures how you express yourself - your linguistic fingerprint
struct CommunicationStyle: Codable {
    // Vocabulary metrics
    var uniqueWordCount: Int = 0
    var averageSentenceLength: Double = 0
    var vocabularyRichness: Double = 0  // Type-Token Ratio
    var totalWordsAnalyzed: Int = 0
    var totalSentencesAnalyzed: Int = 0

    // Expression patterns
    var usesExclamations: Double = 0     // 0-1 how often
    var usesQuestions: Double = 0         // 0-1 how often
    var usesEllipsis: Double = 0         // 0-1 trailing off...
    var usesAllCaps: Double = 0          // EMPHASIS
    var averageMessageLength: Double = 0

    // Formality spectrum (0 = very casual, 1 = very formal)
    var formalityLevel: Double = 0.5

    // Emotional expressiveness (0 = reserved, 1 = very expressive)
    var expressiveness: Double = 0.5

    // Directness (0 = indirect/hedging, 1 = very direct)
    var directness: Double = 0.5

    // Top vocabulary - words you use most (beyond common words)
    var signatureWords: [String: Int] = [:]

    // Phrases you repeat
    var signaturePhrases: [String: Int] = [:]

    // How you start messages
    var commonOpenings: [String: Int] = [:]

    // Update count for running averages
    var analysisCount: Int = 0
}

// MARK: - Emotional Signature

/// Your unique emotional fingerprint - how you experience and express feelings
struct EmotionalSignature: Codable {
    // Baseline emotional state (where you naturally settle)
    var baselineValence: Double = 0      // -1 negative to +1 positive
    var baselineArousal: Double = 0.5    // 0 calm to 1 activated
    var baselineDominance: Double = 0.5  // 0 submissive to 1 dominant

    // Emotional range (how much you fluctuate)
    var emotionalRange: Double = 0.5     // 0 = very stable, 1 = highly variable

    // Emotion frequency map (how often each emotion appears)
    var emotionFrequency: [String: Double] = [:]

    // Emotional resilience (how quickly you bounce back)
    var resilienceScore: Double = 0.5

    // Time-based patterns
    var morningMood: Double = 0          // Average morning sentiment
    var eveningMood: Double = 0          // Average evening sentiment
    var weekdayMood: Double = 0          // Average weekday sentiment
    var weekendMood: Double = 0          // Average weekend sentiment

    // Trigger patterns
    var positiveTriggersTopics: [String: Double] = [:]  // Topics that lift mood
    var negativeTriggersTopics: [String: Double] = [:]  // Topics that lower mood

    // Emotional trajectory (are things getting better/worse over time?)
    var sentimentTrend: Double = 0       // -1 declining, 0 stable, +1 improving
    var recentSentiments: [Double] = []  // Last 30 data points

    var analysisCount: Int = 0
}

// MARK: - Thought Pattern Model

/// Maps your cognitive tendencies and thinking style
struct ThoughtPatterns: Codable {
    // Cognitive style
    var analyticalScore: Double = 0.5    // How much you analyze vs feel
    var abstractScore: Double = 0.5      // Abstract vs concrete thinking
    var futureOriented: Double = 0.5     // Past-focused vs future-focused
    var selfFocused: Double = 0.5        // Internal vs external focus

    // Rumination patterns (0 = never, 1 = frequently)
    var ruminationTendency: Double = 0
    var topicPersistence: [String: Int] = [:]  // How long topics stay active

    // Growth indicators
    var selfAwarenessLevel: Double = 0.5
    var growthMindsetScore: Double = 0.5
    var gratitudeTendency: Double = 0.5

    // Decision making style
    var decisiveness: Double = 0.5       // Quick decisions vs deliberation
    var riskTolerance: Double = 0.5      // Risk-averse vs risk-seeking

    // Primary concerns (ranked by frequency)
    var topConcerns: [String: Double] = [:]

    var analysisCount: Int = 0
}

// MARK: - Personal Knowledge Graph

/// Your world - people, places, topics, and their connections
struct PersonalKnowledgeGraph: Codable {
    var nodes: [String: KnowledgeNode] = [:]
    var edges: [KnowledgeEdge] = []

    struct KnowledgeNode: Codable, Identifiable {
        let id: String  // Unique identifier (lowercased name)
        var label: String  // Display name
        var type: NodeType
        var mentions: Int = 0
        var firstSeen: Date
        var lastSeen: Date
        var sentimentAssociation: Double = 0  // How you feel about this
        var importance: Double = 0  // Calculated importance score

        enum NodeType: String, Codable {
            case person, place, topic, activity, goal, fear, value, event
        }
    }

    struct KnowledgeEdge: Codable {
        var from: String
        var to: String
        var weight: Double = 1.0
        var relationship: String?  // e.g., "friend", "coworker", "causes", "related to"
    }

    mutating func addOrUpdate(id: String, label: String, type: KnowledgeNode.NodeType, sentiment: Double = 0) {
        let key = id.lowercased()
        if var node = nodes[key] {
            node.mentions += 1
            node.lastSeen = Date()
            node.sentimentAssociation = node.sentimentAssociation * 0.8 + sentiment * 0.2
            node.importance = calculateImportance(mentions: node.mentions, lastSeen: node.lastSeen, sentiment: node.sentimentAssociation)
            nodes[key] = node
        } else {
            let now = Date()
            nodes[key] = KnowledgeNode(
                id: key,
                label: label,
                type: type,
                mentions: 1,
                firstSeen: now,
                lastSeen: now,
                sentimentAssociation: sentiment,
                importance: 0.1
            )
        }
    }

    mutating func connect(_ from: String, to: String, relationship: String? = nil) {
        let fromKey = from.lowercased()
        let toKey = to.lowercased()

        if let idx = edges.firstIndex(where: { $0.from == fromKey && $0.to == toKey }) {
            edges[idx].weight += 0.1
        } else {
            edges.append(KnowledgeEdge(from: fromKey, to: toKey, weight: 1.0, relationship: relationship))
        }
    }

    private func calculateImportance(mentions: Int, lastSeen: Date, sentiment: Double) -> Double {
        let recency = exp(-Calendar.current.dateComponents([.day], from: lastSeen, to: Date()).day.map { Double($0) / 14.0 }! )
        let frequency = min(1.0, Double(mentions) / 20.0)
        let emotionalWeight = abs(sentiment) * 0.3
        return (frequency * 0.4 + recency * 0.4 + emotionalWeight * 0.2)
    }

    func topNodes(ofType type: KnowledgeNode.NodeType? = nil, limit: Int = 10) -> [KnowledgeNode] {
        let filtered = type == nil ? Array(nodes.values) : nodes.values.filter { $0.type == type }
        return filtered.sorted { $0.importance > $1.importance }.prefix(limit).map { $0 }
    }

    func connections(for nodeId: String) -> [(node: KnowledgeNode, relationship: String?)] {
        let key = nodeId.lowercased()
        let connectedIds = edges.filter { $0.from == key || $0.to == key }
        return connectedIds.compactMap { edge in
            let otherId = edge.from == key ? edge.to : edge.from
            guard let node = nodes[otherId] else { return nil }
            return (node, edge.relationship)
        }
    }
}

// MARK: - Behavioral Patterns

/// When and how you interact with the app
struct BehavioralPatterns: Codable {
    // Time patterns
    var hourlyActivity: [Int: Int] = [:]  // Hour -> entry count
    var dayOfWeekActivity: [Int: Int] = [:]  // 1=Sun, 7=Sat
    var peakHour: Int?
    var peakDay: Int?

    // Session patterns
    var averageSessionLength: Double = 0  // In words
    var sessionsPerWeek: Double = 0

    // Consistency
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var consistencyScore: Double = 0  // 0-1

    // Entry patterns
    var totalEntries: Int = 0
    var totalWords: Int = 0
    var averageWordsPerEntry: Double = 0

    // Interaction preferences
    var prefersVoice: Double = 0.5  // 0 = text only, 1 = voice only
    var prefersShortEntries: Double = 0.5  // 0 = long form, 1 = brief

    // Growth tracking
    var weeklyEntryHistory: [String: Int] = [:]  // "2026-W09" -> count

    var analysisCount: Int = 0
}

// MARK: - Twin Summary

/// A human-readable snapshot of the digital twin
struct TwinSummary: Codable {
    var personalitySnapshot: String = ""
    var communicationSnapshot: String = ""
    var emotionalSnapshot: String = ""
    var lifeSnapshot: String = ""
    var growthSnapshot: String = ""
    var lastUpdated: Date = Date()

    // Twin maturity (how well-formed the twin is)
    var maturityLevel: TwinMaturity = .nascent
    var dataPointsCollected: Int = 0

    enum TwinMaturity: String, Codable {
        case nascent = "nascent"        // < 5 entries
        case emerging = "emerging"      // 5-20 entries
        case developing = "developing"  // 20-50 entries
        case established = "established" // 50-100 entries
        case deep = "deep"              // 100+ entries

        var description: String {
            switch self {
            case .nascent: return "Just getting to know you"
            case .emerging: return "Starting to see patterns"
            case .developing: return "Understanding is growing"
            case .established: return "Your twin knows you well"
            case .deep: return "A deep reflection of you"
            }
        }

        var progress: Double {
            switch self {
            case .nascent: return 0.1
            case .emerging: return 0.3
            case .developing: return 0.55
            case .established: return 0.8
            case .deep: return 1.0
            }
        }
    }
}

// MARK: - The Digital Twin Engine

final class DigitalTwinEngine: ObservableObject {

    static let shared = DigitalTwinEngine()

    // MARK: - Published State

    @Published var communicationStyle = CommunicationStyle()
    @Published var emotionalSignature = EmotionalSignature()
    @Published var thoughtPatterns = ThoughtPatterns()
    @Published var knowledgeGraph = PersonalKnowledgeGraph()
    @Published var behavioralPatterns = BehavioralPatterns()
    @Published var summary = TwinSummary()

    // NLP
    private let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
    private let entityTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    private let tokenizer = NLTokenizer(unit: .word)
    private let sentenceTokenizer = NLTokenizer(unit: .sentence)

    // MARK: - Initialization

    private init() {
        load()
    }

    // MARK: - Core Processing

    /// Process a diary entry to learn from it
    func processEntry(text: String, mood: String?, date: Date, duration: Double) {
        guard !text.isEmpty else { return }

        // Update all models
        analyzeCommunicationStyle(text)
        analyzeEmotionalSignature(text, mood: mood, date: date)
        analyzeThoughtPatterns(text)
        updateKnowledgeGraph(text, date: date)
        updateBehavioralPatterns(text, date: date, duration: duration)

        // Refresh summary
        updateSummary()

        // Persist
        save()
    }

    /// Process a chat message (lighter analysis)
    func processChatMessage(_ text: String) {
        guard !text.isEmpty else { return }
        analyzeCommunicationStyle(text)
        analyzeEmotionalSignature(text, mood: nil, date: Date())
        save()
    }

    // MARK: - Communication Style Analysis

    private func analyzeCommunicationStyle(_ text: String) {
        let n = Double(communicationStyle.analysisCount + 1)
        let alpha = 1.0 / n  // Running average weight

        // Tokenize
        let words = tokenizeWords(text)
        let sentences = tokenizeSentences(text)
        let uniqueWords = Set(words.map { $0.lowercased() })

        // Update word counts
        communicationStyle.totalWordsAnalyzed += words.count
        communicationStyle.totalSentencesAnalyzed += sentences.count
        communicationStyle.uniqueWordCount = max(communicationStyle.uniqueWordCount, uniqueWords.count)

        // Vocabulary richness (Type-Token Ratio)
        if words.count > 0 {
            let ttr = Double(uniqueWords.count) / Double(words.count)
            communicationStyle.vocabularyRichness = lerp(communicationStyle.vocabularyRichness, ttr, alpha)
        }

        // Sentence length
        if sentences.count > 0 {
            let avgLen = Double(words.count) / Double(sentences.count)
            communicationStyle.averageSentenceLength = lerp(communicationStyle.averageSentenceLength, avgLen, alpha)
        }

        // Expression patterns
        let exclamationRate = Double(text.filter { $0 == "!" }.count) / max(1, Double(sentences.count))
        let questionRate = Double(text.filter { $0 == "?" }.count) / max(1, Double(sentences.count))
        let hasEllipsis = text.contains("...") ? 1.0 : 0.0
        let capsWords = words.filter { $0 == $0.uppercased() && $0.count > 1 }.count
        let capsRate = Double(capsWords) / max(1, Double(words.count))

        communicationStyle.usesExclamations = lerp(communicationStyle.usesExclamations, min(1, exclamationRate), alpha)
        communicationStyle.usesQuestions = lerp(communicationStyle.usesQuestions, min(1, questionRate), alpha)
        communicationStyle.usesEllipsis = lerp(communicationStyle.usesEllipsis, hasEllipsis, alpha)
        communicationStyle.usesAllCaps = lerp(communicationStyle.usesAllCaps, min(1, capsRate), alpha)
        communicationStyle.averageMessageLength = lerp(communicationStyle.averageMessageLength, Double(words.count), alpha)

        // Formality detection
        let informalWords = Set(["gonna", "wanna", "kinda", "yeah", "nah", "lol", "haha", "omg", "wtf", "tbh", "idk", "ngl", "fr", "rn", "ugh", "yep", "nope", "hey", "yo", "dude", "bruh"])
        let informalCount = words.filter { informalWords.contains($0.lowercased()) }.count
        let informalRate = Double(informalCount) / max(1, Double(words.count))
        communicationStyle.formalityLevel = lerp(communicationStyle.formalityLevel, max(0, 1.0 - informalRate * 10), alpha)

        // Expressiveness (exclamations + caps + emotion words)
        let expressiveScore = min(1, exclamationRate + capsRate + Double(informalCount) * 0.1)
        communicationStyle.expressiveness = lerp(communicationStyle.expressiveness, expressiveScore, alpha)

        // Directness (short sentences, few hedging words)
        let hedgingWords = Set(["maybe", "perhaps", "might", "could", "sort of", "kind of", "i think", "i guess", "probably", "possibly"])
        let hedgingCount = words.filter { hedgingWords.contains($0.lowercased()) }.count
        let directnessScore = max(0, 1.0 - Double(hedgingCount) / max(1, Double(words.count)) * 20)
        communicationStyle.directness = lerp(communicationStyle.directness, directnessScore, alpha)

        // Track signature words (filter stopwords and common words)
        let significantWords = words.filter { $0.count > 3 && !Self.commonWords.contains($0.lowercased()) }
        for word in significantWords {
            communicationStyle.signatureWords[word.lowercased(), default: 0] += 1
        }
        // Keep only top 100 signature words
        if communicationStyle.signatureWords.count > 150 {
            let sorted = communicationStyle.signatureWords.sorted { $0.value > $1.value }
            communicationStyle.signatureWords = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(100)))
        }

        communicationStyle.analysisCount += 1
    }

    // MARK: - Emotional Signature Analysis

    private func analyzeEmotionalSignature(_ text: String, mood: String?, date: Date) {
        let n = Double(emotionalSignature.analysisCount + 1)
        let alpha = 1.0 / n

        // Sentiment
        sentimentTagger.string = text
        let (tag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentiment = Double(tag?.rawValue ?? "0") ?? 0

        // Update baseline
        emotionalSignature.baselineValence = lerp(emotionalSignature.baselineValence, sentiment, alpha)

        // Track sentiment history
        emotionalSignature.recentSentiments.append(sentiment)
        if emotionalSignature.recentSentiments.count > 30 {
            emotionalSignature.recentSentiments.removeFirst()
        }

        // Calculate trend
        if emotionalSignature.recentSentiments.count >= 5 {
            let recent = Array(emotionalSignature.recentSentiments.suffix(5))
            let older = Array(emotionalSignature.recentSentiments.prefix(min(5, emotionalSignature.recentSentiments.count)))
            let recentAvg = recent.reduce(0, +) / Double(recent.count)
            let olderAvg = older.reduce(0, +) / Double(older.count)
            emotionalSignature.sentimentTrend = recentAvg - olderAvg
        }

        // Emotional range (standard deviation of recent sentiments)
        if emotionalSignature.recentSentiments.count > 2 {
            let mean = emotionalSignature.recentSentiments.reduce(0, +) / Double(emotionalSignature.recentSentiments.count)
            let variance = emotionalSignature.recentSentiments.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(emotionalSignature.recentSentiments.count)
            emotionalSignature.emotionalRange = min(1, sqrt(variance) * 2)
        }

        // Time-based mood
        let hour = Calendar.current.component(.hour, from: date)
        let weekday = Calendar.current.component(.weekday, from: date)

        if hour < 12 {
            emotionalSignature.morningMood = lerp(emotionalSignature.morningMood, sentiment, alpha)
        } else {
            emotionalSignature.eveningMood = lerp(emotionalSignature.eveningMood, sentiment, alpha)
        }

        if weekday >= 2 && weekday <= 6 {
            emotionalSignature.weekdayMood = lerp(emotionalSignature.weekdayMood, sentiment, alpha)
        } else {
            emotionalSignature.weekendMood = lerp(emotionalSignature.weekendMood, sentiment, alpha)
        }

        // Track mood frequency
        if let mood = mood {
            emotionalSignature.emotionFrequency[mood, default: 0] += 1
        }

        // Extract topics and associate with sentiment
        let topics = extractTopicWords(text)
        for topic in topics {
            if sentiment > 0.2 {
                emotionalSignature.positiveTriggersTopics[topic, default: 0] += sentiment
            } else if sentiment < -0.2 {
                emotionalSignature.negativeTriggersTopics[topic, default: 0] += abs(sentiment)
            }
        }

        // Trim trigger maps
        if emotionalSignature.positiveTriggersTopics.count > 50 {
            let sorted = emotionalSignature.positiveTriggersTopics.sorted { $0.value > $1.value }
            emotionalSignature.positiveTriggersTopics = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(30)))
        }
        if emotionalSignature.negativeTriggersTopics.count > 50 {
            let sorted = emotionalSignature.negativeTriggersTopics.sorted { $0.value > $1.value }
            emotionalSignature.negativeTriggersTopics = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(30)))
        }

        emotionalSignature.analysisCount += 1
    }

    // MARK: - Thought Pattern Analysis

    private func analyzeThoughtPatterns(_ text: String) {
        let lowercased = text.lowercased()
        let words = tokenizeWords(text)
        let n = Double(thoughtPatterns.analysisCount + 1)
        let alpha = 1.0 / n

        // Analytical vs Emotional
        let analyticalWords = Set(["because", "therefore", "reason", "analyze", "logic", "evidence", "data", "think", "consider", "evaluate", "compare", "conclude", "hypothesis"])
        let emotionalWords = Set(["feel", "feeling", "felt", "heart", "soul", "love", "hate", "miss", "hurt", "joy", "pain", "emotion", "mood", "vibe"])
        let analyticalCount = words.filter { analyticalWords.contains($0.lowercased()) }.count
        let emotionalCount = words.filter { emotionalWords.contains($0.lowercased()) }.count
        let total = max(1, analyticalCount + emotionalCount)
        let analyticalRatio = Double(analyticalCount) / Double(total)
        thoughtPatterns.analyticalScore = lerp(thoughtPatterns.analyticalScore, analyticalRatio, alpha)

        // Abstract vs Concrete
        let abstractWords = Set(["concept", "idea", "meaning", "purpose", "philosophy", "theory", "wonder", "imagine", "dream", "possibility", "abstract", "metaphor"])
        let concreteWords = Set(["did", "went", "ate", "bought", "made", "saw", "met", "talked", "worked", "drove", "walked", "called"])
        let abstractCount = words.filter { abstractWords.contains($0.lowercased()) }.count
        let concreteCount = words.filter { concreteWords.contains($0.lowercased()) }.count
        let acTotal = max(1, abstractCount + concreteCount)
        thoughtPatterns.abstractScore = lerp(thoughtPatterns.abstractScore, Double(abstractCount) / Double(acTotal), alpha)

        // Time orientation
        let futureWords = Set(["will", "going to", "plan", "goal", "hope", "tomorrow", "next", "future", "soon", "want to", "someday", "ahead"])
        let pastWords = Set(["was", "were", "had", "used to", "remember", "ago", "yesterday", "last", "before", "back then", "once"])
        let futureCount = words.filter { futureWords.contains($0.lowercased()) }.count
        let pastCount = words.filter { pastWords.contains($0.lowercased()) }.count
        let timeTotal = max(1, futureCount + pastCount)
        thoughtPatterns.futureOriented = lerp(thoughtPatterns.futureOriented, Double(futureCount) / Double(timeTotal), alpha)

        // Self-focus (I/me/my vs they/them/others)
        let selfWords = words.filter { ["i", "me", "my", "myself", "i'm", "i've", "i'd", "i'll"].contains($0.lowercased()) }.count
        let otherWords = words.filter { ["they", "them", "their", "he", "she", "we", "people", "everyone", "someone"].contains($0.lowercased()) }.count
        let focusTotal = max(1, selfWords + otherWords)
        thoughtPatterns.selfFocused = lerp(thoughtPatterns.selfFocused, Double(selfWords) / Double(focusTotal), alpha)

        // Growth mindset indicators
        let growthWords = Set(["learn", "grow", "improve", "better", "progress", "develop", "understand", "realize", "change", "adapt", "try"])
        let fixedWords = Set(["can't", "impossible", "never", "always", "stuck", "hopeless", "pointless", "useless"])
        let growthCount = words.filter { growthWords.contains($0.lowercased()) }.count
        let fixedCount = words.filter { fixedWords.contains($0.lowercased()) }.count
        let mindsetTotal = max(1, growthCount + fixedCount)
        thoughtPatterns.growthMindsetScore = lerp(thoughtPatterns.growthMindsetScore, Double(growthCount) / Double(mindsetTotal), alpha)

        // Self-awareness
        let awarenessWords = Set(["i realize", "i notice", "i'm aware", "i see now", "i understand", "pattern", "tendency", "habit"])
        let hasAwareness = awarenessWords.contains { lowercased.contains($0) } ? 0.8 : 0.3
        thoughtPatterns.selfAwarenessLevel = lerp(thoughtPatterns.selfAwarenessLevel, hasAwareness, alpha)

        // Gratitude
        let gratitudeWords = Set(["grateful", "thankful", "appreciate", "blessed", "lucky", "gift"])
        let hasGratitude = words.contains { gratitudeWords.contains($0.lowercased()) } ? 0.8 : 0.2
        thoughtPatterns.gratitudeTendency = lerp(thoughtPatterns.gratitudeTendency, hasGratitude, alpha)

        thoughtPatterns.analysisCount += 1
    }

    // MARK: - Knowledge Graph Update

    private func updateKnowledgeGraph(_ text: String, date: Date) {
        let sentiment = getSentiment(text)

        // Extract entities
        entityTagger.string = text
        var extractedPeople: [String] = []
        var extractedPlaces: [String] = []
        var extractedTopics: [String] = []

        entityTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .joinNames]) { tag, range in
            let entity = String(text[range])
            guard entity.count > 1 else { return true }

            switch tag {
            case .personalName:
                extractedPeople.append(entity)
                knowledgeGraph.addOrUpdate(id: entity, label: entity, type: .person, sentiment: sentiment)
            case .placeName:
                extractedPlaces.append(entity)
                knowledgeGraph.addOrUpdate(id: entity, label: entity, type: .place, sentiment: sentiment)
            case .organizationName:
                knowledgeGraph.addOrUpdate(id: entity, label: entity, type: .topic, sentiment: sentiment)
                extractedTopics.append(entity)
            default:
                break
            }
            return true
        }

        // Extract topic words
        let topicWords = extractTopicWords(text)
        for word in topicWords.prefix(5) {
            knowledgeGraph.addOrUpdate(id: word, label: word.capitalized, type: .topic, sentiment: sentiment)
            extractedTopics.append(word)
        }

        // Detect goals/fears/values
        let lowercased = text.lowercased()
        if lowercased.contains("i want to") || lowercased.contains("my goal") || lowercased.contains("dream of") {
            for topic in topicWords.prefix(2) {
                knowledgeGraph.addOrUpdate(id: "goal:\(topic)", label: topic.capitalized, type: .goal, sentiment: 0.5)
            }
        }
        if lowercased.contains("afraid of") || lowercased.contains("scares me") || lowercased.contains("worried about") {
            for topic in topicWords.prefix(2) {
                knowledgeGraph.addOrUpdate(id: "fear:\(topic)", label: topic.capitalized, type: .fear, sentiment: -0.5)
            }
        }

        // Build connections between entities mentioned together
        let allEntities = extractedPeople + extractedPlaces + extractedTopics
        for i in 0..<allEntities.count {
            for j in (i+1)..<min(allEntities.count, i + 4) {
                knowledgeGraph.connect(allEntities[i], to: allEntities[j])
            }
        }
    }

    // MARK: - Behavioral Pattern Update

    private func updateBehavioralPatterns(_ text: String, date: Date, duration: Double) {
        let words = tokenizeWords(text)
        let hour = Calendar.current.component(.hour, from: date)
        let weekday = Calendar.current.component(.weekday, from: date)
        let n = Double(behavioralPatterns.analysisCount + 1)
        let alpha = 1.0 / n

        behavioralPatterns.hourlyActivity[hour, default: 0] += 1
        behavioralPatterns.dayOfWeekActivity[weekday, default: 0] += 1
        behavioralPatterns.totalEntries += 1
        behavioralPatterns.totalWords += words.count
        behavioralPatterns.averageWordsPerEntry = lerp(behavioralPatterns.averageWordsPerEntry, Double(words.count), alpha)
        behavioralPatterns.averageSessionLength = lerp(behavioralPatterns.averageSessionLength, Double(words.count), alpha)

        // Peak hour/day
        behavioralPatterns.peakHour = behavioralPatterns.hourlyActivity.max(by: { $0.value < $1.value })?.key
        behavioralPatterns.peakDay = behavioralPatterns.dayOfWeekActivity.max(by: { $0.value < $1.value })?.key

        // Weekly tracking
        let weekKey = Self.weekFormatter.string(from: date)
        behavioralPatterns.weeklyEntryHistory[weekKey, default: 0] += 1

        // Voice preference
        if duration > 0 {
            behavioralPatterns.prefersVoice = lerp(behavioralPatterns.prefersVoice, 0.8, alpha)
        } else {
            behavioralPatterns.prefersVoice = lerp(behavioralPatterns.prefersVoice, 0.2, alpha)
        }

        // Entry length preference
        let shortThreshold = 50
        if words.count < shortThreshold {
            behavioralPatterns.prefersShortEntries = lerp(behavioralPatterns.prefersShortEntries, 0.8, alpha)
        } else {
            behavioralPatterns.prefersShortEntries = lerp(behavioralPatterns.prefersShortEntries, 0.2, alpha)
        }

        behavioralPatterns.analysisCount += 1
    }

    // MARK: - Summary Generation

    private func updateSummary() {
        let totalDataPoints = behavioralPatterns.totalEntries

        // Update maturity
        if totalDataPoints >= 100 {
            summary.maturityLevel = .deep
        } else if totalDataPoints >= 50 {
            summary.maturityLevel = .established
        } else if totalDataPoints >= 20 {
            summary.maturityLevel = .developing
        } else if totalDataPoints >= 5 {
            summary.maturityLevel = .emerging
        } else {
            summary.maturityLevel = .nascent
        }
        summary.dataPointsCollected = totalDataPoints

        // Personality snapshot
        var traits: [String] = []
        if communicationStyle.expressiveness > 0.6 { traits.append("expressive") }
        else if communicationStyle.expressiveness < 0.3 { traits.append("reserved") }
        if communicationStyle.directness > 0.6 { traits.append("direct") }
        else if communicationStyle.directness < 0.3 { traits.append("thoughtful") }
        if communicationStyle.formalityLevel < 0.3 { traits.append("casual") }
        else if communicationStyle.formalityLevel > 0.7 { traits.append("articulate") }
        if thoughtPatterns.analyticalScore > 0.6 { traits.append("analytical") }
        if thoughtPatterns.growthMindsetScore > 0.6 { traits.append("growth-oriented") }
        if thoughtPatterns.gratitudeTendency > 0.5 { traits.append("grateful") }

        summary.personalitySnapshot = traits.isEmpty ? "Still learning about you..." : "You come across as \(traits.joined(separator: ", "))."

        // Communication snapshot
        if communicationStyle.analysisCount > 3 {
            let wordStyle = communicationStyle.averageSentenceLength > 15 ? "detailed" : "concise"
            let toneStyle = communicationStyle.expressiveness > 0.5 ? "emotionally rich" : "measured"
            summary.communicationSnapshot = "Your writing style is \(wordStyle) and \(toneStyle), with an average of \(Int(communicationStyle.averageSentenceLength)) words per sentence."
        }

        // Emotional snapshot
        if emotionalSignature.analysisCount > 3 {
            let valenceLabel = emotionalSignature.baselineValence > 0.1 ? "generally positive" : (emotionalSignature.baselineValence < -0.1 ? "going through some challenges" : "balanced")
            let trendLabel = emotionalSignature.sentimentTrend > 0.05 ? "trending upward" : (emotionalSignature.sentimentTrend < -0.05 ? "trending downward" : "staying steady")
            summary.emotionalSnapshot = "Your emotional baseline is \(valenceLabel) and \(trendLabel)."
        }

        // Life snapshot
        let topPeople = knowledgeGraph.topNodes(ofType: .person, limit: 3)
        let topTopics = knowledgeGraph.topNodes(ofType: .topic, limit: 3)
        var lifeItems: [String] = []
        if !topPeople.isEmpty {
            lifeItems.append("Key people: \(topPeople.map { $0.label }.joined(separator: ", "))")
        }
        if !topTopics.isEmpty {
            lifeItems.append("Main themes: \(topTopics.map { $0.label }.joined(separator: ", "))")
        }
        summary.lifeSnapshot = lifeItems.joined(separator: ". ")

        // Growth snapshot
        if behavioralPatterns.totalEntries > 5 {
            let consistency = behavioralPatterns.consistencyScore > 0.5 ? "consistent" : "occasional"
            summary.growthSnapshot = "You're a \(consistency) journaler with \(behavioralPatterns.totalEntries) entries. \(summary.maturityLevel.description)."
        }

        summary.lastUpdated = Date()
    }

    // MARK: - Search Suggestions

    struct SearchSuggestion {
        let text: String
        let type: String  // "person", "topic", "place", "mood"
        let icon: String
    }

    /// Search knowledge graph for suggestions matching query
    func searchSuggestions(for query: String) -> [SearchSuggestion] {
        guard query.count >= 2 else { return [] }
        let lowered = query.lowercased()
        var results: [SearchSuggestion] = []

        // Search knowledge graph nodes
        for node in knowledgeGraph.nodes.values {
            if node.label.lowercased().contains(lowered) {
                let icon: String
                switch node.type {
                case .person: icon = "person.fill"
                case .place: icon = "mappin.circle.fill"
                case .topic: icon = "tag.fill"
                case .goal: icon = "star.fill"
                case .fear: icon = "exclamationmark.triangle.fill"
                default: icon = "doc.text"
                }
                results.append(SearchSuggestion(text: node.label, type: node.type.rawValue, icon: icon))
            }
        }

        // Search mood names
        let moodNames = ["happy", "calm", "grateful", "excited", "tired", "anxious", "sad", "angry"]
        for mood in moodNames {
            if mood.contains(lowered) {
                results.append(SearchSuggestion(text: mood.capitalized, type: "mood", icon: "face.smiling"))
            }
        }

        return Array(results.prefix(8))
    }

    // MARK: - Twin Predictions

    /// Predict what the user might want to talk about
    func predictTopics() -> [String] {
        // Based on recurring topics and time patterns
        var suggestions: [String] = []

        // Recent high-importance topics
        let recentTopics = knowledgeGraph.topNodes(ofType: .topic, limit: 3)
        suggestions.append(contentsOf: recentTopics.map { $0.label })

        // Unresolved situations (topics with negative sentiment that keep recurring)
        let negativeTopics = emotionalSignature.negativeTriggersTopics
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { $0.key.capitalized }
        suggestions.append(contentsOf: negativeTopics)

        return Array(Set(suggestions)).prefix(5).map { $0 }
    }

    /// Predict the user's current emotional state based on patterns
    func predictMood(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let weekday = Calendar.current.component(.weekday, from: date)

        var predictedSentiment = emotionalSignature.baselineValence

        if hour < 12 {
            predictedSentiment = emotionalSignature.morningMood
        } else {
            predictedSentiment = emotionalSignature.eveningMood
        }

        if weekday >= 2 && weekday <= 6 {
            predictedSentiment = (predictedSentiment + emotionalSignature.weekdayMood) / 2
        } else {
            predictedSentiment = (predictedSentiment + emotionalSignature.weekendMood) / 2
        }

        if predictedSentiment > 0.3 { return "positive" }
        if predictedSentiment > 0.1 { return "calm" }
        if predictedSentiment > -0.1 { return "neutral" }
        if predictedSentiment > -0.3 { return "reflective" }
        return "needs support"
    }

    // MARK: - NLP Helpers

    private func tokenizeWords(_ text: String) -> [String] {
        var words: [String] = []
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            words.append(String(text[range]))
            return true
        }
        return words
    }

    private func tokenizeSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        sentenceTokenizer.string = text
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }
        return sentences
    }

    private func extractTopicWords(_ text: String) -> [String] {
        var topics: [String] = []
        entityTagger.string = text
        entityTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 3 && !Self.commonWords.contains(word) {
                    topics.append(word)
                }
            }
            return true
        }
        return topics
    }

    private func getSentiment(_ text: String) -> Double {
        sentimentTagger.string = text
        let (tag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(tag?.rawValue ?? "0") ?? 0
    }

    private func lerp(_ from: Double, _ to: Double, _ t: Double) -> Double {
        return from + (to - from) * t
    }

    // MARK: - Persistence

    private struct DTPayload: Codable {
        var communicationStyle: CommunicationStyle
        var emotionalSignature: EmotionalSignature
        var thoughtPatterns: ThoughtPatterns
        var knowledgeGraph: PersonalKnowledgeGraph
        var behavioralPatterns: BehavioralPatterns
        var summary: TwinSummary
    }

    private func save() {
        let payload = DTPayload(
            communicationStyle: communicationStyle,
            emotionalSignature: emotionalSignature,
            thoughtPatterns: thoughtPatterns,
            knowledgeGraph: knowledgeGraph,
            behavioralPatterns: behavioralPatterns,
            summary: summary
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }

        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            let request = NSFetchRequest<AIState>(entityName: "AIState")
            request.predicate = NSPredicate(format: "type == %@", "digital_twin")
            let existing = try? context.fetch(request).first

            let state = existing ?? AIState(context: context)
            if existing == nil {
                state.id = UUID()
                state.type = "digital_twin"
            }
            state.payload = data
            state.updatedAt = Date()
            try? context.save()
        }
    }

    private func load() {
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<AIState>(entityName: "AIState")
        request.predicate = NSPredicate(format: "type == %@", "digital_twin")

        if let state = try? context.fetch(request).first, let data = state.payload {
            let decoder = JSONDecoder()
            if let payload = try? decoder.decode(DTPayload.self, from: data) {
                communicationStyle = payload.communicationStyle
                emotionalSignature = payload.emotionalSignature
                thoughtPatterns = payload.thoughtPatterns
                knowledgeGraph = payload.knowledgeGraph
                behavioralPatterns = payload.behavioralPatterns
                summary = payload.summary
                return
            }
        }

        // One-time migration from UserDefaults
        let decoder = JSONDecoder()
        var migrated = false
        if let data = UserDefaults.standard.data(forKey: "dt_commStyle"),
           let val = try? decoder.decode(CommunicationStyle.self, from: data) { communicationStyle = val; migrated = true }
        if let data = UserDefaults.standard.data(forKey: "dt_emotionalSig"),
           let val = try? decoder.decode(EmotionalSignature.self, from: data) { emotionalSignature = val; migrated = true }
        if let data = UserDefaults.standard.data(forKey: "dt_thoughtPatterns"),
           let val = try? decoder.decode(ThoughtPatterns.self, from: data) { thoughtPatterns = val; migrated = true }
        if let data = UserDefaults.standard.data(forKey: "dt_knowledgeGraph"),
           let val = try? decoder.decode(PersonalKnowledgeGraph.self, from: data) { knowledgeGraph = val; migrated = true }
        if let data = UserDefaults.standard.data(forKey: "dt_behavioral"),
           let val = try? decoder.decode(BehavioralPatterns.self, from: data) { behavioralPatterns = val; migrated = true }
        if let data = UserDefaults.standard.data(forKey: "dt_summary"),
           let val = try? decoder.decode(TwinSummary.self, from: data) { summary = val; migrated = true }

        if migrated {
            save()
            for key in ["dt_commStyle", "dt_emotionalSig", "dt_thoughtPatterns", "dt_knowledgeGraph", "dt_behavioral", "dt_summary"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Static

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-'W'ww"
        return f
    }()

    private static let commonWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
        "be", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "need",
        "this", "that", "these", "those", "i", "you", "he", "she", "it",
        "we", "they", "what", "which", "who", "when", "where", "why", "how",
        "all", "each", "every", "both", "few", "more", "most", "other",
        "some", "such", "no", "nor", "not", "only", "own", "same", "so",
        "than", "too", "very", "just", "also", "now", "here", "there",
        "about", "like", "really", "much", "still", "well", "back", "even",
        "then", "thing", "things", "know", "think", "want", "get", "got",
        "going", "make", "made", "come", "came", "take", "took", "give",
        "gave", "tell", "told", "say", "said", "good", "time", "day"
    ]
}
