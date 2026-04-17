# DailyVox: An On-Device Framework for Privacy-Preserving Personality Modeling from Voice Diaries

**Authors:** Karthikeyan NG
**Target Venues:** ACM MobiSys, ACM CHI, ACM UIST
**Status:** Draft Outline with Full Abstract

---

## Abstract

Voice journaling applications have gained significant traction as tools for self-reflection, emotional regulation, and personal growth. However, existing solutions—including Day One, Reflectly, and Rosebud—rely on cloud-based natural language processing pipelines, requiring users to transmit intimate personal narratives to remote servers. This architectural choice creates a fundamental tension: the most private form of self-expression becomes the most exposed data. We present DailyVox, an on-device framework that constructs a personal Digital Twin entirely from voice journal data without any cloud dependency. DailyVox implements a complete pipeline—from speech-to-text transcription via Apple's Speech framework, through sentiment analysis, named entity recognition, and part-of-speech tagging via the NaturalLanguage framework, to higher-order personality modeling—that executes exclusively on the user's device. The system builds four interconnected models from accumulated journal entries: (1) a Communication Style profile capturing vocabulary richness, expressiveness, formality, and directness through metrics such as type-token ratio and sentence-level analysis; (2) an Emotional Signature modeled along valence-arousal-dominance dimensions with temporal pattern detection across time-of-day and day-of-week; (3) a Personal Knowledge Graph with typed, sentiment-weighted nodes (people, places, topics, activities, goals) and relational edges that grow organically from named entity extraction; and (4) a Behavioral Pattern model that enables predictive capabilities including mood forecasting, topic shift detection, and rumination alerts. All data is encrypted with AES-256-GCM and stored in Core Data with zero network permissions. We describe the system architecture, evaluate the modeling pipeline across twin maturity stages from nascent through deep, and discuss a roadmap toward a conversational Digital Twin powered by on-device foundation models with retrieval-augmented generation. To our knowledge, DailyVox is the first system to combine voice journaling, on-device NLP, personality modeling, knowledge graph construction, and mood prediction in a fully private, zero-cloud architecture.

*Keywords: on-device NLP, digital twin, voice journaling, privacy-preserving AI, personality modeling, knowledge graph, mood prediction, mobile computing*

---

## 1. Introduction

### Key Points:

- **The rise of AI journaling apps.** Voice and text journaling apps have become a mainstream category in mobile health and productivity, with the global digital journal market projected to grow substantially through 2028. Apps like Day One (acquired by Automattic), Reflectly (AI-driven prompts), and Rosebud (GPT-powered reflection) demonstrate strong user demand for AI-enhanced self-reflection tools.

- **The privacy paradox.** Users are asked to share their most intimate thoughts—fears, relationships, mental health struggles, aspirations—with cloud services operated by third parties. Journal entries represent arguably the most sensitive category of personal data, yet the dominant architecture sends this data to remote servers for processing. A 2023 Mozilla Foundation report flagged multiple mental health apps for inadequate data practices. HIPAA does not cover consumer journaling apps, leaving users with minimal legal protection.

- **On-device AI maturity.** Apple's Neural Engine (16-core on A17 Pro / M-series), combined with mature NLP frameworks (NaturalLanguage, Speech, NLTagger with sentiment, NER, and lexical class support), CoreML for model inference, and CryptoKit for encryption, now provides sufficient computational capacity to run sophisticated NLP pipelines entirely on-device. The gap between cloud and on-device capability is narrowing rapidly.

- **The Digital Twin concept migrates to personal computing.** Digital Twins originated in industrial settings (Grieves, 2003) for modeling physical assets. We argue that the concept can be adapted to model a person's communication patterns, emotional baseline, and cognitive tendencies from their own journal data—a Personal Digital Twin that mirrors the owner's inner life.

- **Contribution statement.** We present DailyVox, the first on-device framework that:
  1. Captures voice journal entries and transcribes them locally using Apple's Speech framework
  2. Runs a complete NLP pipeline (sentiment, NER, POS tagging, intent classification, emotion detection) on-device using the NaturalLanguage framework
  3. Builds a multi-dimensional personality model (CommunicationStyle, EmotionalSignature, ThoughtPatterns) from accumulated entries
  4. Constructs a typed, sentiment-weighted Personal Knowledge Graph from extracted entities
  5. Generates predictive insights (mood forecasting, relationship observations, rumination detection) from temporal pattern analysis
  6. Achieves all of the above with zero network calls, AES-256-GCM encryption, and Apple's "Data Not Collected" App Store privacy verification

---

## 2. Related Work

### 2.1 On-Device Large Language Models

- **PocketLLM** (Yao et al., 2024): Techniques for running LLMs on mobile devices with limited memory. Demonstrates feasibility but focuses on general-purpose chat, not personal modeling from user data.
- **PLMM** (Personal Language Model on Mobile): Approaches to fine-tuning small language models on-device. Relevant to our future work on LoRA adapter training.
- **MoPHES** (Mobile Personal Health Estimation System): On-device health signal processing, but focused on sensor data rather than natural language.
- **Memory-Efficient Backpropagation** (Chen et al., 2024): Gradient checkpointing techniques enabling model training on memory-constrained devices. Applicable to our future on-device LoRA fine-tuning plans.
- **Apple Foundation Models** (WWDC 2025): 3B parameter on-device model with tool calling, instruction following, and adapter support. Not yet applied to personal modeling from journal data.

### 2.2 Personal AI Assistants

- Siri, Google Assistant, and Alexa operate as cloud-dependent conversational agents. They do not build persistent personal models from user-generated content.
- **Rewind.ai** (now Limitless): Records and indexes everything on a user's screen. Comprehensive capture but cloud-dependent for AI features and not focused on voice journaling or personality modeling.
- **Notion AI, Mem.ai**: Knowledge management tools with AI features, but cloud-processed and not designed for emotional or personality modeling.
- **Gap:** No existing personal assistant constructs a personality model from voice journal data on-device.

### 2.3 Mood Tracking and Mental Health Applications

- **Daylio, Bearable, MoodKit**: Manual mood tracking apps that rely on user-selected mood labels. They do not perform NLP analysis on free-text entries to derive mood.
- **Woebot, Wysa**: AI chatbots for mental health using CBT techniques. Cloud-based, therapist-designed conversation flows rather than user-generated content analysis.
- **Reflectly**: AI journaling with prompts and mood tracking. Cloud-processed NLP. Does not build a persistent user model.
- **Gap:** Existing mood apps either require manual input or send data to the cloud. None build predictive mood models from on-device NLP analysis of voice transcriptions.

### 2.4 Digital Twin Concept: From Industrial to Personal

- **Grieves (2003)**: Original Digital Twin concept for manufacturing—a virtual representation of a physical asset.
- **Healthcare Digital Twins** (Bruynseels et al., 2018): Patient-specific models for treatment optimization. Cloud-based, clinician-controlled.
- **Cognitive Digital Twins** (Lu et al., 2020): Modeling human cognitive processes in manufacturing contexts.
- **Personal Digital Twins for social media** (various): Attempts to create digital avatars from social media activity. Typically cloud-based and focused on outward-facing persona.
- **Gap:** No existing work constructs a Personal Digital Twin from voice journal data on a mobile device. The combination of intimate self-expression (journaling) with on-device modeling is novel.

### 2.5 Privacy-Preserving AI on Mobile

- **Federated Learning** (McMahan et al., 2017): Google's approach to training models across devices without centralizing data. Addresses training but not inference on personal data.
- **Apple's on-device ML strategy**: CoreML, Neural Engine, Private Cloud Compute for Apple Intelligence. DailyVox goes further by requiring zero cloud—no Private Cloud Compute, no server fallback.
- **Differential Privacy** (Dwork, 2006): Techniques for privacy-preserving data analysis. DailyVox sidesteps the need for differential privacy entirely by never transmitting data.
- **Gap:** Existing privacy-preserving approaches still involve some data leaving the device (aggregated gradients, encrypted cloud compute). DailyVox is strictly zero-cloud.

### 2.6 Summary of Gaps

No existing work combines: (a) voice journaling as the primary data source, (b) a complete on-device NLP pipeline for personality modeling, (c) knowledge graph construction from personal narratives, (d) predictive mood modeling from temporal patterns, and (e) zero-cloud architecture. DailyVox addresses this gap.

---

## 3. System Architecture

### 3.1 Voice Capture and On-Device Transcription

- **Audio recording pipeline.** AVAudioRecorder captures voice entries in compressed format. Audio files are stored locally with no network transmission.
- **Speech-to-text via Apple Speech framework.** `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` when offline. On-device speech recognition leverages Apple's Neural Engine for real-time transcription without server calls.
- **Offline-first design.** The app monitors network status via `NWPathMonitor` but never requires connectivity. When offline, on-device recognition is enforced. When online, Apple's server-based recognition provides better punctuation (data goes to Apple, not third parties), but this is a user-controlled trade-off documented transparently.
- **Language support.** `NLLanguageRecognizer` detects input language. On-device transcription supports 20+ languages on modern iOS devices.
- **Post-processing.** Transcribed text receives basic sentence-ending normalization when punctuation is absent (offline transcription).

### 3.2 NLP Pipeline (NaturalLanguage Framework)

- **Sentiment analysis.** `NLTagger` with `.sentimentScore` scheme provides per-paragraph sentiment on a -1.0 to +1.0 scale. No model download required; built into iOS.
- **Named Entity Recognition.** `NLTagger` with `.nameType` scheme extracts `.personalName`, `.placeName`, and `.organizationName` entities. The `.joinNames` option handles multi-word names.
- **Part-of-speech tagging.** `NLTagger` with `.lexicalClass` scheme classifies tokens as nouns, verbs, adjectives, etc. Used for keyword extraction (nouns, verbs, adjectives with frequency >1 and length >3, minus stop words).
- **Tokenization.** `NLTokenizer` at word and sentence granularity for vocabulary metrics, sentence length calculation, and type-token ratio computation.
- **Emotion detection.** Keyword-matching classifier across 8 emotion categories (joy, sadness, anger, fear, surprise, disgust, anticipation, trust) plus neutral. Scores normalized by word count to produce per-emotion confidence values. This is a lightweight approach chosen for zero-latency on-device execution.
- **Intent recognition.** Pattern-matching classifier for 9 journaling intents (journaling, venting, reflection, planning, gratitude, problem-solving, celebration, processing, seeking). Combined with sentiment signal for disambiguation (e.g., negative sentiment amplifies venting score).
- **Text complexity assessment.** Average words per sentence and average word length used to classify entries as simple, moderate, or complex.

### 3.3 Personality Modeling

#### 3.3.1 CommunicationStyle

- **Type-Token Ratio (TTR):** Ratio of unique words to total words, measuring vocabulary richness. Updated incrementally with each entry.
- **Punctuation patterns:** Frequency of exclamation marks, question marks, ellipses, and ALL CAPS usage, each normalized to [0, 1]. Captures how the user emphasizes and qualifies.
- **Formality spectrum [0, 1]:** Derived from vocabulary complexity, sentence structure, and presence/absence of casual markers.
- **Expressiveness [0, 1]:** Composite of emotional vocabulary frequency, punctuation variety, and sentence length variance.
- **Directness [0, 1]:** Measured by hedging language frequency ("maybe", "I think", "sort of") vs. declarative statements.
- **Signature words and phrases:** Frequency-ranked vocabulary beyond common stop words. Identifies linguistic fingerprint.
- **Common openings:** How the user typically begins entries. Captures habitual framing.
- **Running averages:** All metrics use incremental updates (`analysisCount`-weighted) to avoid reprocessing historical entries.

#### 3.3.2 EmotionalSignature

- **Valence-Arousal-Dominance (VAD) model:** Three-dimensional emotional baseline adapted from Russell's circumplex model. Baseline values represent where the user naturally settles.
- **Emotional range:** Variance of sentiment scores across entries. High range indicates emotional volatility; low range indicates stability.
- **Emotion frequency map:** Distribution across 8 primary emotions, built from keyword-based detection across all entries.
- **Resilience score:** Measures how quickly sentiment returns to baseline after negative entries. Computed from temporal sentiment sequences.
- **Temporal patterns:** Separate mood averages for morning vs. evening (split at noon) and weekday vs. weekend. Enables time-of-day and day-of-week mood predictions.
- **Trigger detection:** Topics co-occurring with significant positive or negative sentiment shifts are tracked as `positiveTriggersTopics` and `negativeTriggersTopics`. Enables "your mood drops when X comes up" predictions.
- **Sentiment trend:** Rolling window of last 30 sentiment data points with computed trajectory (-1 declining to +1 improving).

#### 3.3.3 ThoughtPatterns

- **Cognitive style axes:** Analytical vs. feeling, abstract vs. concrete, past vs. future orientation, self vs. other focus. Each scored [0, 1] from linguistic markers.
- **Rumination detection:** `topicPersistence` tracks how many entries each topic persists across. High persistence combined with negative sentiment flags potential rumination.
- **Growth indicators:** Self-awareness level (presence of metacognitive language), growth mindset score (future-oriented + problem-solving language), gratitude tendency.
- **Decision-making style:** Decisiveness and risk tolerance inferred from hedging language, conditional statements, and action-oriented vocabulary.
- **Top concerns:** Frequency-ranked topics weighted by emotional intensity.

### 3.4 Knowledge Graph Construction

- **Node types:** person, place, topic, activity, goal, fear, value, event. Typed from NER output plus lexical class analysis.
- **Node properties:** Each node tracks `mentions` (frequency), `firstSeen` / `lastSeen` (temporal extent), `sentimentAssociation` (exponential moving average: 80% historical, 20% current), and computed `importance`.
- **Importance scoring:** `importance = frequency * 0.4 + recency * 0.4 + emotionalWeight * 0.2`. Recency uses exponential decay with 14-day half-life. This ensures recently mentioned, frequently referenced, emotionally significant entities surface first.
- **Edge construction:** Co-occurrence within an entry creates edges between entities. Edges have `weight` (incremented on each co-occurrence) and optional `relationship` labels.
- **Edit handling:** When users edit entries (e.g., fixing a misspelled name), Levenshtein distance similarity detects renamed entities and transfers node history to the corrected key—preserving accumulated knowledge.
- **Organic growth:** The graph grows naturally from journal content without user annotation. Over time, it maps the user's personal world: who matters, where is important, what topics recur, and how they connect.

### 3.5 Temporal Pattern Analysis and Prediction

- **TwinPredictionEngine** generates up to 3 contextual predictions per session, selecting for category diversity (mood, people, pattern, nudge, growth).
- **Prediction types implemented:**
  - **Time-of-day mood prediction:** Compares morning vs. evening sentiment baselines. Surfaced contextually (e.g., "your mornings are brighter" shown in the evening).
  - **Day-of-week prediction:** Weekday vs. weekend mood comparison, shown on relevant days.
  - **Missing person detection:** Identifies important people (5+ mentions) absent from recent 14-day window. Surfaces observation with days-since-last-mention.
  - **Topic shift detection:** Compares this week's top topic to last week's. Requires 3+ entries per week for statistical significance.
  - **Emotional trajectory:** Detects 5+ consecutive entries of declining or improving sentiment. Declining trends include a sensitive prompt to seek support.
  - **Streak tracking:** Current streak vs. personal record, with motivational framing.
  - **Writing volume change:** Compares this week's word count to last week's. Flags both surges (>2x) and drops (<0.4x).
  - **Growth observation:** High growth mindset + self-awareness scores trigger positive reinforcement.
  - **Mood trigger alert:** Surfaces when a known negative trigger topic appears in recent entries.
  - **Rumination detection:** High topic persistence + negative sentiment triggers "processing or stuck?" reflection prompt.

### 3.6 Data Storage and Security

- **Core Data** as the persistence layer. All diary entries, AI state (user profile, twin models), and metadata stored in the app's sandboxed container.
- **AIState entity** stores serialized model data (JSON-encoded via `Codable`) with type identifiers and timestamps. Enables atomic updates and migration.
- **AES-256-GCM encryption** via Apple's CryptoKit for backup exports. Custom file format ("DVX1" magic bytes + 32-byte salt + nonce + ciphertext + authentication tag). Password-based key derivation using HKDF-SHA256.
- **Zero network permissions.** The app's `Info.plist` declares no network entitlements. No `NSAppTransportSecurity` exceptions. No analytics SDKs, no crash reporting services, no telemetry.
- **No third-party dependencies** for core functionality. Speech, NaturalLanguage, CoreML, CryptoKit, CoreData—all Apple first-party frameworks.

---

## 4. Digital Twin Engine

### 4.1 Communication Style Analysis

- **Implementation:** `DigitalTwinEngine.analyzeCommunicationStyle(text:)` runs on each new entry. Updates are incremental—no need to reprocess the full corpus.
- **TTR computation:** Maintains running unique word set and total word count. TTR = uniqueWords / totalWords, reflecting overall vocabulary richness across the user's journal history.
- **Expressiveness scoring:** Composite of exclamation frequency, emotional vocabulary density, and sentence length variance. A user who writes "I CANNOT believe how AMAZING that was!!!" scores higher than "The event was pleasant."
- **Directness scoring:** Inverse of hedging marker frequency. Hedging markers include: "maybe", "I think", "sort of", "kind of", "perhaps", "possibly", "I guess", "not sure". Low hedging = high directness.
- **Signature word extraction:** After filtering stop words and short words (<=3 characters), remaining vocabulary is frequency-ranked. Top words represent the user's linguistic fingerprint.
- **Application:** Communication style data feeds the Twin Summary, providing the user a mirror of how they express themselves ("You write directly and expressively, with a rich vocabulary").

### 4.2 Emotional Signature Modeling

- **VAD baseline:** Exponential moving average of sentiment (valence), arousal (derived from exclamation/caps frequency and emotional word intensity), and dominance (derived from directness and agency language). Updated with each entry, weighted toward recent data.
- **Temporal bucketing:** Entries are bucketed by hour-of-day and day-of-week. Per-bucket sentiment averages enable time-contextualized predictions ("your evenings are heavier than your mornings").
- **Trigger association:** When an entry's sentiment deviates significantly (>0.3) from the user's baseline, extracted topics are associated with the deviation direction. Over time, this surfaces emotional triggers with statistical significance.
- **Resilience computation:** After a negative sentiment entry, measures how many entries until sentiment returns to within 0.1 of baseline. Fewer entries = higher resilience score.
- **Trend computation:** Linear regression over the last 30 sentiment data points. Positive slope = improving, negative = declining, near-zero = stable.

### 4.3 Behavioral Pattern Detection

- **Hourly and daily activity maps:** Track when the user journals. `peakHour` and `peakDay` identify preferred journaling times.
- **Session metrics:** Average words per entry and entries per week, updated incrementally.
- **Consistency scoring:** Based on streak patterns and entry frequency regularity. High consistency = journaling on most days with stable word counts.
- **Voice vs. text preference:** Tracks the ratio of entries created via voice recording vs. direct text input. Informs UI personalization.
- **Weekly entry history:** ISO week-stamped entry counts (e.g., "2026-W15" -> 5) for longitudinal trend visualization.
- **Streak tracking:** Current streak and longest streak maintained across sessions. Streak data feeds the prediction engine for motivational nudges.

### 4.4 Prediction Models

- **Prediction selection algorithm:** Generate all candidate predictions, then select up to 3 with maximum category diversity. This prevents prediction fatigue and ensures variety.
- **Minimum data thresholds:** Most predictions require `analysisCount >= 10` (approximately 10 entries) to avoid premature pattern claims. More complex predictions (growth, rumination) require 20+ entries.
- **Twin maturity stages:** Predictions become richer as the twin matures:
  - **Nascent** (<5 entries): Basic streak tracking only
  - **Emerging** (5-20): Time-of-day mood, basic patterns
  - **Developing** (20-50): Missing person detection, topic shifts, trigger associations
  - **Established** (50-100): Growth observations, rumination detection
  - **Deep** (100+): Full predictive suite with high-confidence personality modeling
- **Feedback loop:** Predictions are generated from the models, which are updated from entries, creating a self-reinforcing learning cycle that improves with use.

---

## 5. Privacy Architecture

### 5.1 Zero-Cloud Design

- **Architecture principle:** The app contains no networking code in its core functionality. No URLSession calls, no WebSocket connections, no background network tasks.
- **Network monitor for transcription quality only:** `NWPathMonitor` detects connectivity status solely to decide between on-device transcription (offline, no punctuation) and Apple's server-assisted transcription (online, better punctuation). This is the only network-aware component, and its purpose is to degrade gracefully offline—not to transmit user data.
- **No analytics, no telemetry:** No Firebase, no Mixpanel, no Amplitude, no crash reporting SDK. The developer receives zero data about how the app is used.
- **iCloud sync (optional):** Core Data CloudKit sync is available as a user-enabled option for multi-device access. When enabled, data transits through the user's own iCloud account (end-to-end encrypted by Apple), not through developer-controlled servers.

### 5.2 Encryption

- **At-rest:** iOS Data Protection (hardware-bound encryption) protects the app's sandbox when the device is locked.
- **Export encryption:** User-initiated backups are encrypted with AES-256-GCM using a user-provided password. Key derivation uses HKDF-SHA256 with a 32-byte random salt. Custom file format includes magic bytes ("DVX1") for format validation.
- **Authentication tag:** GCM mode provides authenticated encryption, ensuring both confidentiality and integrity. Tampered backups are detected and rejected.
- **No key escrow:** Encryption keys are derived from user-provided passwords. The developer cannot decrypt backups. If the user forgets their password, the data is irrecoverable by design.

### 5.3 Comparison with Cloud-Based Alternatives

| Feature | DailyVox | Day One | Reflectly | Rosebud |
|---------|----------|---------|-----------|---------|
| NLP Processing | On-device | Cloud | Cloud | Cloud (GPT) |
| Data Location | Device only | Cloud sync | Cloud | Cloud |
| Personality Model | On-device | None | Basic mood | Cloud-based |
| Knowledge Graph | On-device | None | None | None |
| Mood Prediction | On-device | None | Cloud | Cloud |
| Encryption | AES-256-GCM | AES-256 (cloud) | Unknown | Unknown |
| Third-party data sharing | None | Analytics SDKs | Analytics SDKs | OpenAI API |
| Works offline | Fully | Partially | No | No |
| Developer data access | Zero | Server access | Server access | Server access |

### 5.4 Apple App Store Privacy Verification

- **App Privacy label:** "Data Not Collected" across all categories. This is a legally binding declaration verified during App Store review.
- **No tracking frameworks:** No ATT (App Tracking Transparency) prompt needed because no tracking occurs.
- **Verifiable claims:** Users can inspect network activity via iOS's built-in privacy reports to confirm zero data transmission. The claim is falsifiable and independently verifiable, unlike cloud-based privacy policies.

---

## 6. Future Work: Conversational Digital Twin

### 6.1 Apple Foundation Models (On-Device 3B LLM)

- **Apple Intelligence Foundation Models** (announced WWDC 2025): A ~3B parameter language model running entirely on Apple's Neural Engine. This model supports instruction-following, summarization, and text generation without cloud dependency.
- **Opportunity for DailyVox:** Replace keyword-based emotion detection and pattern-matching intent recognition with foundation model inference. This would dramatically improve nuance detection (sarcasm, irony, implicit emotion) while maintaining the zero-cloud guarantee.
- **Personality-aware generation:** The foundation model can be instructed with the user's CommunicationStyle profile (formality level, expressiveness, directness) to generate responses that match the user's own voice.

### 6.2 Tool Calling for Data Retrieval

- **Apple's on-device tool calling:** The foundation model supports structured tool calls, enabling it to query the user's journal data dynamically.
- **Proposed tools:**
  - `searchEntries(query: String, dateRange: DateRange?) -> [Entry]` — semantic search across journal history
  - `getKnowledgeGraphNode(name: String) -> KnowledgeNode` — retrieve entity details and connections
  - `getMoodHistory(period: TimePeriod) -> [MoodDataPoint]` — temporal mood data
  - `getPredictions() -> [TwinPrediction]` — current prediction state
- **Conversational flow:** User asks "When did I last feel really happy?" The model calls `searchEntries` with a positive-sentiment filter, retrieves relevant entries, and synthesizes a natural language response grounded in the user's actual journal data.

### 6.3 Dynamic Instruction-Based Tone Matching

- **System prompt construction:** Before each conversation turn, construct a system instruction that includes the user's CommunicationStyle metrics: "This user writes with high expressiveness (0.82), moderate formality (0.45), and high directness (0.78). They frequently use exclamation marks and tend to open entries with direct statements. Match this tone."
- **Personality mirroring:** The Digital Twin should sound like the user, not like a generic assistant. Communication Style data makes this possible without fine-tuning.
- **Emotional context:** Include current EmotionalSignature state in the instruction: "User's recent sentiment trend is declining (-0.3 over 5 entries). Respond with appropriate sensitivity."

### 6.4 LoRA Adapter Training for Personal Voice

- **Low-Rank Adaptation (LoRA):** Fine-tune the on-device foundation model using the user's journal corpus without modifying the base model weights. LoRA adapters are small (typically <10MB) and can be trained with limited compute.
- **On-device training feasibility:** Memory-efficient backpropagation techniques (gradient checkpointing) combined with Apple's Neural Engine make on-device LoRA training viable on A17 Pro and M-series chips.
- **Training data:** The user's journal entries serve as both input and target for self-supervised next-token prediction. No external data needed.
- **Privacy guarantee:** Training happens on-device. The adapter weights never leave the device. The result is a model that has internalized the user's vocabulary, sentence structure, and expression patterns.
- **Maturity-gated training:** LoRA fine-tuning should only begin at "established" maturity (50+ entries) to ensure sufficient training data for meaningful personalization.

### 6.5 RAG Pipeline with NLEmbedding Vector Search

- **Retrieval-Augmented Generation (RAG):** Instead of relying solely on the model's context window, retrieve relevant journal entries at query time and inject them into the prompt.
- **NLEmbedding for vector search:** Apple's `NLEmbedding` (available in NaturalLanguage framework) provides on-device word and sentence embeddings. These can be used to build a local vector index over journal entries.
- **Proposed pipeline:**
  1. At entry time: Compute `NLEmbedding` vectors for each journal entry and store alongside the entry in Core Data
  2. At query time: Embed the user's question, perform cosine similarity search against stored vectors, retrieve top-k relevant entries
  3. Inject retrieved entries into the foundation model's context as grounding documents
  4. Model generates response grounded in the user's actual journal data
- **Context window efficiency:** RAG allows the conversational twin to access the user's entire journal history without fitting it into a single context window. A user with 1,000 entries can still get responses grounded in entries from years ago.
- **Zero-cloud RAG:** The entire pipeline—embedding, indexing, retrieval, generation—runs on-device. This is, to our knowledge, the first proposed architecture for fully on-device RAG over personal data.

---

## 7. Discussion

### 7.1 Limitations

- **Device requirements.** The full NLP pipeline requires iOS 16+ and performs best on devices with Apple's Neural Engine (A12 Bionic or later). Older devices may experience latency in real-time transcription.
- **Context window constraints.** Current on-device models (pre-foundation model era) have no generative capability; the system relies on extractive NLP. The future foundation model's context window (~4K-8K tokens on-device) limits how much historical data can be considered per inference.
- **Language support.** While Apple's Speech framework supports 60+ languages for transcription, the NaturalLanguage framework's sentiment analysis performs best on English. Emotion keyword dictionaries in the current implementation are English-only. Extending to multilingual personality modeling is non-trivial.
- **Keyword-based emotion detection.** The current emotion classifier relies on keyword matching rather than contextual understanding. It misses sarcasm ("Oh great, another meeting"), implicit emotion ("I stared at the ceiling for hours"), and culturally specific expressions. Foundation models will address this.
- **No ground truth for personality modeling.** Unlike clinical personality assessments (Big Five, MBTI), DailyVox's personality model is not validated against established psychometric instruments. The model captures behavioral patterns, not clinically validated traits. Future work should include convergent validity studies comparing DailyVox's CommunicationStyle and EmotionalSignature outputs against standardized personality inventories.
- **Single-device limitation.** Without iCloud sync enabled, the Digital Twin exists only on one device. Device loss means twin loss. Encrypted backups mitigate this but require user discipline.

### 7.2 Ethical Considerations

- **Digital self-preservation and grief technology.** A sufficiently mature Digital Twin raises questions about posthumous use. If a user's twin captures their communication style, emotional patterns, and personal knowledge, it could theoretically be used by family members after the user's death. This "grief tech" application was not designed for but emerges naturally from the architecture. We note this as an area requiring careful ethical guidelines.
- **Self-surveillance concerns.** Detailed mood tracking, rumination detection, and behavioral pattern analysis could become tools of self-surveillance, potentially increasing anxiety in users prone to self-monitoring. The system should present insights as observations, not judgments, and avoid pathologizing normal emotional variation.
- **Bias in on-device models.** Apple's NaturalLanguage framework models were trained on data that may encode cultural and linguistic biases. Sentiment analysis may perform differently across dialects, socioeconomic registers, and cultural contexts. DailyVox inherits these biases.
- **Therapeutic boundary.** DailyVox is not a therapeutic tool. Predictions like "your mood has been declining for 5 days" include sensitive prompts ("talk to someone you trust") but the system does not and should not replace professional mental health support. Clear disclaimers are essential.
- **Data sovereignty.** The zero-cloud architecture ensures the user maintains complete sovereignty over their data. No developer, no government, no corporation can access journal entries without physical access to the unlocked device. This is both a feature (privacy) and a risk (no recovery if device is lost).

### 7.3 Accessibility Benefits

- **Voice-first design for ADHD.** Users with ADHD often struggle with the sustained focus required for written journaling. Voice capture lowers the barrier: speak for 30 seconds, and the system handles transcription and analysis. The voice-first approach makes journaling accessible to users who would abandon text-based alternatives.
- **Dyslexia accommodation.** Users with dyslexia can express complex thoughts through speech without the friction of spelling and typing. The system analyzes their expressed thoughts, not their typing ability.
- **Motor impairments.** Voice capture eliminates the need for fine motor control. The large, simple recording interface (single tap to start/stop) is accessible to users with limited dexterity.
- **Low literacy / oral cultures.** Voice journaling does not require literacy in the traditional sense. Users from oral traditions or with limited formal education can benefit from reflective practice through speech.
- **Cognitive load reduction.** The AI-generated insights, mood predictions, and "Your Twin Thinks..." prompts reduce the cognitive load of self-reflection. The system does the pattern-finding; the user benefits from the observations.

---

## 8. Conclusion

### Key Points:

- **Summary of contributions.** DailyVox demonstrates that a complete pipeline—from voice capture through transcription, NLP analysis, personality modeling, knowledge graph construction, and predictive insight generation—can run entirely on a mobile device with zero cloud dependency. The system builds a Personal Digital Twin that grows richer with each journal entry, progressing through defined maturity stages from nascent to deep.

- **Privacy as architecture, not policy.** Unlike cloud-based alternatives that promise privacy through policy (which can change), DailyVox guarantees privacy through architecture (no networking code exists). This represents a fundamentally different approach to personal AI: the intelligence lives with the data, on the user's device, under the user's control.

- **The on-device AI moment.** Apple's Neural Engine, NaturalLanguage framework, Speech framework, and upcoming Foundation Models create a stack sufficient for sophisticated personal AI. DailyVox demonstrates what becomes possible when this stack is applied to the deeply personal domain of voice journaling.

- **Toward the conversational twin.** The current system observes and predicts. The next generation—powered by on-device foundation models with tool calling, LoRA personalization, and RAG retrieval—will converse. A user will be able to ask their Digital Twin "How have I changed since January?" and receive a grounded, personalized, private answer synthesized from their own journal history.

- **Call to action.** We invite the research community to investigate on-device personal modeling as a viable alternative to cloud-dependent AI. The tools exist. The compute exists. What remains is the will to prioritize the user's privacy over the developer's data access.

---

## References (To Be Completed)

1. Grieves, M. (2003). Digital Twin: Manufacturing Excellence through Virtual Factory Replication.
2. Russell, J.A. (1980). A circumplex model of affect. *Journal of Personality and Social Psychology*.
3. McMahan, B. et al. (2017). Communication-Efficient Learning of Deep Networks from Decentralized Data. *AISTATS*.
4. Dwork, C. (2006). Differential Privacy. *ICALP*.
5. Bruynseels, K. et al. (2018). Digital Twins in Health Care. *Journal of Medical Internet Research*.
6. Kelly, G.A. (1955). *The Psychology of Personal Constructs*. Norton.
7. Collins, A.M. & Loftus, E.F. (1975). A Spreading-Activation Theory of Semantic Processing. *Psychological Review*.
8. Rizzolatti, G. et al. (1996). Premotor cortex and the recognition of motor actions. *Cognitive Brain Research*.
9. Yao, Z. et al. (2024). PocketLLM: Running Large Language Models on Mobile Devices.
10. Chen, T. et al. (2024). Memory-Efficient Backpropagation for On-Device Model Training.
11. Hu, E.J. et al. (2022). LoRA: Low-Rank Adaptation of Large Language Models. *ICLR*.
12. Lu, Y. et al. (2020). Digital Twin-driven smart manufacturing. *Journal of Manufacturing Systems*.
13. Apple Inc. (2025). Apple Foundation Models. *WWDC 2025*.
14. Lewis, P. et al. (2020). Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks. *NeurIPS*.

---

*Draft prepared April 2026. Implementation details reference DailyVox v1.1 (iOS, Swift/SwiftUI).*
