//
//  LocalAIEngine.swift
//  solyn
//
//  On-device AI engine for personal assistant capabilities.
//  All processing happens locally using CoreML and NaturalLanguage frameworks.
//  No data is ever sent to external servers.
//
//  Capabilities:
//  - Intent recognition from voice/text
//  - Contextual understanding based on user history
//  - Personalized insights and suggestions
//  - Emotion and sentiment tracking
//  - Topic extraction and categorization
//  - Smart reminders and proactive assistance
//

import Foundation
import NaturalLanguage
import CoreML
import CoreData

// MARK: - User Profile (Local Learning)

/// Stores learned preferences and patterns about the user locally
final class UserProfile: ObservableObject, Codable {
    
    // MARK: - Stored Properties
    
    var commonTopics: [String: Int] = [:]
    var emotionalPatterns: [String: [EmotionEntry]] = [:]
    var writingTimes: [Int: Int] = [:] // Hour -> count
    var averageSentiment: Double = 0.0
    var totalEntries: Int = 0
    var preferredMoods: [String: Int] = [:]
    var importantPeople: [String: Int] = [:]
    var importantPlaces: [String: Int] = [:]
    var goalsAndAspirations: [String] = []
    var recurringThemes: [String: Int] = [:]
    var weeklyMoodTrend: [Double] = []
    
    // MARK: - Nested Types
    
    struct EmotionEntry: Codable {
        let date: Date
        let sentiment: Double
        let dominantEmotion: String
    }
    
    // MARK: - Persistence

    private static let profileKey = "userAIProfile"
    private static let coreDataType = "user_profile"

    static func load() -> UserProfile {
        // Try Core Data first
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<AIState>(entityName: "AIState")
        request.predicate = NSPredicate(format: "type == %@", coreDataType)
        if let state = try? context.fetch(request).first,
           let data = state.payload,
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }

        // One-time migration from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        profile.save()
        UserDefaults.standard.removeObject(forKey: profileKey)
        return profile
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            let request = NSFetchRequest<AIState>(entityName: "AIState")
            request.predicate = NSPredicate(format: "type == %@", UserProfile.coreDataType)
            let existing = try? context.fetch(request).first
            let state = existing ?? AIState(context: context)
            if existing == nil {
                state.id = UUID()
                state.type = UserProfile.coreDataType
            }
            state.payload = data
            state.updatedAt = Date()
            try? context.save()
        }
    }
}

// MARK: - Intent Recognition

enum UserIntent: String, CaseIterable {
    case journaling = "journaling"
    case venting = "venting"
    case reflection = "reflection"
    case planning = "planning"
    case gratitude = "gratitude"
    case problemSolving = "problem_solving"
    case celebration = "celebration"
    case processing = "processing"
    case seeking = "seeking"
    case unknown = "unknown"
    
    var description: String {
        switch self {
        case .journaling: return "Recording daily thoughts"
        case .venting: return "Expressing frustration or stress"
        case .reflection: return "Deep thinking about life"
        case .planning: return "Setting goals or making plans"
        case .gratitude: return "Appreciating good things"
        case .problemSolving: return "Working through a challenge"
        case .celebration: return "Sharing good news"
        case .processing: return "Making sense of emotions"
        case .seeking: return "Looking for guidance"
        case .unknown: return "General expression"
        }
    }
    
    var suggestedFollowUp: String {
        switch self {
        case .journaling: return "How did that make you feel?"
        case .venting: return "What would help you feel better right now?"
        case .reflection: return "What insight stands out to you?"
        case .planning: return "What's the first small step you could take?"
        case .gratitude: return "How can you carry this feeling forward?"
        case .problemSolving: return "What resources do you have to help?"
        case .celebration: return "Who would you like to share this with?"
        case .processing: return "What does this experience teach you?"
        case .seeking: return "What does your intuition say?"
        case .unknown: return "Tell me more about what's on your mind."
        }
    }
}

// MARK: - Emotion Detection

enum DetectedEmotion: String, CaseIterable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    case anticipation = "anticipation"
    case trust = "trust"
    case neutral = "neutral"
    
    var emoji: String {
        switch self {
        case .joy: return "😊"
        case .sadness: return "😢"
        case .anger: return "😤"
        case .fear: return "😰"
        case .surprise: return "😮"
        case .disgust: return "😒"
        case .anticipation: return "🤔"
        case .trust: return "🤝"
        case .neutral: return "😐"
        }
    }
    
    var supportiveMessage: String {
        switch self {
        case .joy: return "It's wonderful to see you feeling good!"
        case .sadness: return "It's okay to feel this way. Your feelings are valid."
        case .anger: return "I hear your frustration. Taking a moment to breathe can help."
        case .fear: return "Acknowledging fear is brave. What small step feels manageable?"
        case .surprise: return "Life certainly keeps us on our toes!"
        case .disgust: return "Sometimes we need to process difficult feelings."
        case .anticipation: return "The future holds possibilities. What excites you most?"
        case .trust: return "Building connections is meaningful work."
        case .neutral: return "Sometimes a calm mind is exactly what we need."
        }
    }
}

// MARK: - AI Analysis Result

struct AIAnalysisResult {
    let intent: UserIntent
    let emotions: [DetectedEmotion: Double]
    let dominantEmotion: DetectedEmotion
    let sentiment: Double // -1.0 to 1.0
    let topics: [String]
    let people: [String]
    let places: [String]
    let suggestedResponse: String
    let keywords: [String]
    let complexity: TextComplexity
    
    enum TextComplexity {
        case simple, moderate, complex
    }
}

// MARK: - Local AI Engine

/// Main AI engine that processes all user data locally using CoreML and NaturalLanguage
final class LocalAIEngine: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LocalAIEngine()
    
    // MARK: - Properties
    
    @Published var userProfile: UserProfile
    @Published var isProcessing = false
    
    private let sentimentTagger: NLTagger
    private let entityTagger: NLTagger
    private let tokenizer: NLTokenizer
    private let languageRecognizer: NLLanguageRecognizer
    
    // Emotion keyword dictionaries for local classification
    private let emotionKeywords: [DetectedEmotion: Set<String>] = [
        .joy: ["happy", "excited", "glad", "wonderful", "amazing", "great", "love", "enjoy", "fantastic", "thrilled", "delighted", "blessed", "grateful", "awesome", "beautiful", "celebrate", "fun", "laugh", "smile", "proud"],
        .sadness: ["sad", "unhappy", "depressed", "lonely", "miss", "cry", "hurt", "disappointed", "grief", "sorrow", "heartbroken", "down", "blue", "melancholy", "lost", "empty", "hopeless", "tears", "mourning", "regret"],
        .anger: ["angry", "frustrated", "annoyed", "furious", "mad", "irritated", "hate", "resent", "rage", "upset", "bitter", "offended", "hostile", "outraged", "livid", "disgusted", "fed up", "pissed", "infuriated"],
        .fear: ["afraid", "scared", "worried", "anxious", "nervous", "terrified", "panic", "dread", "fear", "uneasy", "tense", "stressed", "overwhelmed", "paranoid", "insecure", "threatened", "alarmed", "frightened"],
        .surprise: ["surprised", "shocked", "amazed", "astonished", "unexpected", "wow", "unbelievable", "sudden", "startled", "stunned", "speechless", "incredible", "mind-blown"],
        .anticipation: ["hope", "expect", "looking forward", "planning", "excited about", "can't wait", "eager", "curious", "wondering", "future", "soon", "tomorrow", "next", "upcoming", "preparing"],
        .trust: ["trust", "believe", "faith", "confident", "reliable", "honest", "loyal", "support", "depend", "safe", "secure", "comfortable", "connected", "understood", "accepted"]
    ]
    
    // Intent detection patterns
    private let intentPatterns: [UserIntent: [String]] = [
        .venting: ["so frustrated", "can't believe", "hate when", "annoyed", "ugh", "terrible", "worst", "sick of", "fed up", "drives me crazy"],
        .gratitude: ["thankful", "grateful", "appreciate", "blessed", "lucky", "thank", "fortunate", "gift"],
        .planning: ["going to", "plan to", "want to", "need to", "should", "will", "goal", "tomorrow", "next week", "future"],
        .reflection: ["thinking about", "wonder", "realize", "understand now", "looking back", "in hindsight", "learned that", "means to me"],
        .celebration: ["excited", "finally", "achieved", "accomplished", "won", "got the", "made it", "success", "promotion", "accepted"],
        .problemSolving: ["how can i", "what should", "trying to figure", "solution", "problem is", "challenge", "struggling with", "need help"],
        .seeking: ["advice", "guidance", "help me", "what do you think", "should i", "confused about", "not sure"]
    ]
    
    // MARK: - Initialization
    
    private init() {
        self.userProfile = UserProfile.load()
        self.sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        self.entityTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        self.tokenizer = NLTokenizer(unit: .word)
        self.languageRecognizer = NLLanguageRecognizer()
    }
    
    // MARK: - Main Analysis Function
    
    /// Analyzes text completely on-device and returns comprehensive AI insights
    func analyze(text: String) -> AIAnalysisResult {
        isProcessing = true
        defer { isProcessing = false }
        
        let lowercasedText = text.lowercased()
        
        // Perform all analyses
        let sentiment = analyzeSentiment(text)
        let emotions = detectEmotions(lowercasedText)
        let dominantEmotion = emotions.max(by: { $0.value < $1.value })?.key ?? .neutral
        let intent = detectIntent(lowercasedText)
        let entities = extractEntities(text)
        let keywords = extractKeywords(text)
        let complexity = assessComplexity(text)
        
        // Generate personalized response
        let response = generateResponse(
            intent: intent,
            emotion: dominantEmotion,
            sentiment: sentiment,
            topics: entities.topics
        )
        
        // Update user profile with learnings
        updateProfile(
            sentiment: sentiment,
            emotion: dominantEmotion,
            topics: entities.topics,
            people: entities.people,
            places: entities.places
        )
        
        return AIAnalysisResult(
            intent: intent,
            emotions: emotions,
            dominantEmotion: dominantEmotion,
            sentiment: sentiment,
            topics: entities.topics,
            people: entities.people,
            places: entities.places,
            suggestedResponse: response,
            keywords: keywords,
            complexity: complexity
        )
    }
    
    // MARK: - Sentiment Analysis
    
    private func analyzeSentiment(_ text: String) -> Double {
        sentimentTagger.string = text
        let (sentiment, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0.0
    }
    
    // MARK: - Emotion Detection
    
    private func detectEmotions(_ text: String) -> [DetectedEmotion: Double] {
        var emotionScores: [DetectedEmotion: Double] = [:]
        
        // Initialize all emotions with base score
        for emotion in DetectedEmotion.allCases {
            emotionScores[emotion] = 0.0
        }
        
        // Tokenize and check against emotion keywords
        tokenizer.string = text
        var wordCount = 0
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            wordCount += 1
            
            for (emotion, keywords) in self.emotionKeywords {
                if keywords.contains(word) {
                    emotionScores[emotion, default: 0.0] += 1.0
                }
            }
            return true
        }
        
        // Normalize scores
        if wordCount > 0 {
            for emotion in emotionScores.keys {
                emotionScores[emotion] = min(1.0, (emotionScores[emotion] ?? 0) / Double(max(1, wordCount / 10)))
            }
        }
        
        // If no emotions detected, mark as neutral
        let totalScore = emotionScores.values.reduce(0, +)
        if totalScore < 0.1 {
            emotionScores[.neutral] = 1.0
        }
        
        return emotionScores
    }
    
    // MARK: - Intent Detection
    
    private func detectIntent(_ text: String) -> UserIntent {
        var intentScores: [UserIntent: Int] = [:]
        
        for (intent, patterns) in intentPatterns {
            for pattern in patterns {
                if text.contains(pattern) {
                    intentScores[intent, default: 0] += 1
                }
            }
        }
        
        // Additional intent signals based on sentiment and structure
        let sentiment = analyzeSentiment(text)
        
        if sentiment < -0.3 && intentScores[.venting] ?? 0 > 0 {
            intentScores[.venting, default: 0] += 2
        }
        
        if sentiment > 0.3 && intentScores[.celebration] ?? 0 > 0 {
            intentScores[.celebration, default: 0] += 2
        }
        
        // Check for question patterns (seeking)
        if text.contains("?") {
            intentScores[.seeking, default: 0] += 1
        }
        
        // Default to journaling if no strong signal
        return intentScores.max(by: { $0.value < $1.value })?.key ?? .journaling
    }
    
    // MARK: - Entity Extraction
    
    private func extractEntities(_ text: String) -> (topics: [String], people: [String], places: [String]) {
        entityTagger.string = text
        
        var topics: Set<String> = []
        var people: Set<String> = []
        var places: Set<String> = []
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        entityTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            let entity = String(text[range])
            
            switch tag {
            case .personalName:
                people.insert(entity)
            case .placeName:
                places.insert(entity)
            case .organizationName:
                topics.insert(entity)
            default:
                break
            }
            return true
        }
        
        // Extract nouns as potential topics
        entityTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if tag == .noun {
                let noun = String(text[range])
                if noun.count > 3 { // Filter short words
                    topics.insert(noun.capitalized)
                }
            }
            return true
        }
        
        return (Array(topics.prefix(10)), Array(people), Array(places))
    }
    
    // MARK: - Keyword Extraction
    
    private func extractKeywords(_ text: String) -> [String] {
        entityTagger.string = text
        var keywords: [String: Int] = [:]
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        entityTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if tag == .noun || tag == .verb || tag == .adjective {
                let word = String(text[range]).lowercased()
                if word.count > 3 && !Self.stopWords.contains(word) {
                    keywords[word, default: 0] += 1
                }
            }
            return true
        }
        
        return keywords.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }
    
    // MARK: - Text Complexity Assessment
    
    private func assessComplexity(_ text: String) -> AIAnalysisResult.TextComplexity {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let words = text.split { $0.isWhitespace }
        
        let avgWordsPerSentence = sentences.isEmpty ? 0 : Double(words.count) / Double(sentences.count)
        let avgWordLength = words.isEmpty ? 0 : Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
        
        if avgWordsPerSentence > 20 && avgWordLength > 6 {
            return .complex
        } else if avgWordsPerSentence > 12 || avgWordLength > 5 {
            return .moderate
        }
        return .simple
    }
    
    // MARK: - Response Generation
    
    private func generateResponse(intent: UserIntent, emotion: DetectedEmotion, sentiment: Double, topics: [String]) -> String {
        var response = emotion.supportiveMessage
        
        // Add intent-specific follow-up
        response += " " + intent.suggestedFollowUp
        
        // Personalize based on user history
        if userProfile.totalEntries > 10 {
            if let frequentTopic = topics.first(where: { userProfile.commonTopics[$0, default: 0] > 3 }) {
                response += " I notice '\(frequentTopic)' comes up often for you."
            }
        }
        
        return response
    }
    
    // MARK: - Profile Learning
    
    private func updateProfile(sentiment: Double, emotion: DetectedEmotion, topics: [String], people: [String], places: [String]) {
        // Update topic frequency
        for topic in topics {
            userProfile.commonTopics[topic, default: 0] += 1
        }
        
        // Update people and places
        for person in people {
            userProfile.importantPeople[person, default: 0] += 1
        }
        for place in places {
            userProfile.importantPlaces[place, default: 0] += 1
        }
        
        // Track emotional patterns
        let entry = UserProfile.EmotionEntry(
            date: Date(),
            sentiment: sentiment,
            dominantEmotion: emotion.rawValue
        )
        
        let dayKey = Self.dayFormatter.string(from: Date())
        userProfile.emotionalPatterns[dayKey, default: []].append(entry)
        
        // Update writing time preference
        let hour = Calendar.current.component(.hour, from: Date())
        userProfile.writingTimes[hour, default: 0] += 1
        
        // Update running average sentiment
        let oldTotal = userProfile.averageSentiment * Double(userProfile.totalEntries)
        userProfile.totalEntries += 1
        userProfile.averageSentiment = (oldTotal + sentiment) / Double(userProfile.totalEntries)
        
        // Save profile
        userProfile.save()
    }
    
    // MARK: - Proactive Insights
    
    /// Generates proactive suggestions based on learned patterns
    func getProactiveInsights() -> [String] {
        var insights: [String] = []
        
        // Best writing time suggestion
        if let bestHour = userProfile.writingTimes.max(by: { $0.value < $1.value })?.key {
            let timeString = bestHour < 12 ? "\(bestHour)am" : "\(bestHour - 12)pm"
            insights.append("You often journal around \(timeString). That seems to be your best reflection time.")
        }
        
        // Mood trend insight
        if userProfile.averageSentiment > 0.2 {
            insights.append("Your overall sentiment has been positive. Keep nurturing what's working!")
        } else if userProfile.averageSentiment < -0.2 {
            insights.append("It seems like you've been going through some challenges. Remember, journaling itself is an act of self-care.")
        }
        
        // Important people insight
        if let topPerson = userProfile.importantPeople.max(by: { $0.value < $1.value })?.key {
            insights.append("\(topPerson) appears frequently in your entries. They seem important to you.")
        }
        
        // Recurring theme insight
        if let topTopic = userProfile.commonTopics.max(by: { $0.value < $1.value }),
           topTopic.value > 5 {
            insights.append("'\(topTopic.key)' is a recurring theme in your journal. It might be worth exploring deeper.")
        }
        
        return insights
    }
    
    /// Suggests a journaling prompt based on user patterns
    func suggestPrompt() -> String {
        let prompts: [String] = [
            "What's one thing you're grateful for today?",
            "How are you really feeling right now?",
            "What's been on your mind lately?",
            "Describe a moment from today that stood out.",
            "What would make tomorrow a good day?",
            "What's something you've been avoiding thinking about?",
            "Who made a positive impact on you recently?",
            "What's a small win you can celebrate?",
            "What would you tell your past self from a week ago?",
            "What's something you want to remember about this time in your life?"
        ]
        
        // Personalize based on recent patterns
        if userProfile.averageSentiment < -0.1 {
            return "What's one small thing that brought you comfort today?"
        }
        
        if let lastEmotion = Array(userProfile.emotionalPatterns.values).last?.last?.dominantEmotion {
            if lastEmotion == DetectedEmotion.sadness.rawValue {
                return "What support do you need right now?"
            }
            if lastEmotion == DetectedEmotion.joy.rawValue {
                return "What contributed to your good mood? Let's capture it!"
            }
        }
        
        return prompts.randomElement() ?? prompts[0]
    }
    
    // MARK: - Helpers
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
        "be", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "need",
        "this", "that", "these", "those", "i", "you", "he", "she", "it",
        "we", "they", "what", "which", "who", "when", "where", "why", "how",
        "all", "each", "every", "both", "few", "more", "most", "other",
        "some", "such", "no", "nor", "not", "only", "own", "same", "so",
        "than", "too", "very", "just", "also", "now", "here", "there"
    ]
}
