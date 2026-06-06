# DailyVox Roadmap

This roadmap outlines the planned evolution of DailyVox. Contributions are welcome for any upcoming version — check [open issues](https://github.com/intrepidkarthi/dailyvox/issues) or propose your own.

## Shipped

### v1.0 — Core Voice Journal
- Voice journaling with fully on-device transcription (SFSpeechRecognizer)
- Digital Twin personality model (communication style, emotional signature, knowledge graph)
- NLP analysis via NLTagger (sentiment, named entities, topics)
- Core Data storage with optional iCloud sync
- Biometric security (Face ID / Touch ID)
- Widgets (Home Screen & Lock Screen)
- Siri Shortcuts via AppIntents
- AES-256-GCM encrypted exports
- 8 themes, photo attachments, journaling goals

### v1.1 — Twin Predictions
- Twin Predictions: mood forecasting, trigger anticipation, temporal patterns
- Shareable Personality Card for social media
- Weekly Insight Cards
- Improved NLP keyword extraction

### v1.2 — Ask Your Twin
- Ask Your Twin: conversational chat with your Digital Twin
- Shareable Personality Cards (Instagram Stories + Twitter/X formats)
- Smarter App Store review prompts

### v1.2.1 — Warmth Update
- Emotional onboarding: "What brings you here?" intention selection (5th onboarding page)
- Life area auto-tagging: entries auto-classified into Work, Health, Relationships, Growth, Family, Creativity
- Intent-based reminder presets: Morning / Midday / Evening with purpose framing
- Warmer processing state: phased messages with pulsing animation replacing generic spinner
- First-entry celebration moment with Digital Twin callout
- "Just 42 seconds" low-friction nudge on empty states
- Monthly summaries in Timeline section headers (entry count + word count)

### v1.3.0 — Constellation Update
- Constellation metaphor: every entry becomes a star in your inner sky
- ConstellationView: Canvas-based 60fps visualization with mood-colored stars, connections, nebulae
- Celestial onboarding: star-birth welcome, planet system, aurora, shield, "Name your planets"
- Focused zero-state: single "What's on your mind?" screen for first-time users
- First-time Twin tab: guided 4-step introduction with empty sky preview
- Ivory theme as default with sage green/terracotta/warm gold palette
- SF Rounded typography, 20pt continuous corners, warm shadows throughout
- Warm recording UI: coral timer, sage/gold waveform, ambient mic glow
- All emojis replaced with SF Symbols
- WarmBackground gradient on all screens
- Tab bar: star.circle.fill for Twin, mic.circle.fill for Record
- Themes simplified to 4 (System, Ivory, Light, Dark)
- Constellation language: "your first star", "a new star is forming", "your inner sky"
- Full celestial website redesign with Digital Twin as hero message
- 35+ new/rewritten SEO blog posts with GEO optimization
- Newsletter, RSS, press page, /facts page

## Planned

### v1.3.5 — New Icon & Dynamic Island *(next)*
- **New app icon**: golden mic on sage green with 4+2 notch easter egg (matches landing page refresh)
  - Full AppIcon set across all iOS sizes (iPhone, iPad, App Store 1024×1024)
  - iOS 18 dark + tinted icon variants (warm charcoal background, monochrome silhouette)
- **Dynamic Island / Live Activities** (ActivityKit + WidgetKit extension):
  - Recording timer: elapsed time + live waveform in compact pill and expanded view; counts up past the 42-second soft target so users can speak as long as they need
  - Star birth: brief celebratory Live Activity after entry completion ("A new star appeared in your sky"), auto-dismisses
  - Streak tracker (opt-in via Settings): star icon + "Day N" in compact, today-done status in expanded; persists until disabled or streak breaks
  - Constellation Lock Screen widget: Canvas-rendered mini constellation, one star per recent entry, coloured by mood

### v1.4 — Body Twin: HealthKit + Apple Watch *(next)*

The Twin gains a body. Until now it has learned only from your words; v1.4 gives it physiological context so it can finally tell the difference between "feeling stressed" and *being* stressed. Directly addresses one of the limitations called out for v3.0 ("Feel what you feel — no embodied experience").

**Design principle: two layers, context-aware sampling**

Body data feeds the Twin in two distinct layers, with different sampling rules for each. This prevents the obvious failure mode — recording during a jog showing as "extreme stress" — and gives the Twin a coherent way to interpret physiology.

| Layer | What it captures | When sampled | Purpose |
|:--|:--|:--|:--|
| Background | Sleep, morning HRV, resting HR, daily steps, mindful minutes | Snapshotted at entry creation from already-stable Health data | Body state going into the entry |
| Foreground | Recording HR mean + peak, HRV reactivity | Only sampled when `activityContext == .at_rest` for 10+ min | Embodied entry signature |
| Activity context tag | `at_rest` / `active` / `post_workout` / `unknown` | Computed in real time from `HKWorkoutSession` + `CMMotionActivity` | Tells the Twin how to interpret everything else |

Foreground HR is **deliberately skipped during exercise** — the entry is tagged `body_context: active` and the Twin infers emotional state from text and voice alone. A jog recording isn't garbage data; it's a different *kind* of data, useful for different insights (e.g. *"you journal during runs when you're processing something"*).

All HR readings are stored as **deltas from your personal baseline for that hour of day**, not raw bpm — making "+18 over your usual" meaningful regardless of whether your resting HR is 55 or 75.

**HealthKit integration (iPhone):**
- Read access to five high-signal metrics: sleep duration, HRV (SDNN), resting heart rate, steps, mindful minutes
- Per-entry `HealthSnapshot` frozen with each `JournalEntry` (~10 floats per entry including HR deltas + context tag, optional, CloudKit-synced via personal iCloud)
- Activity context detected via `HKWorkoutSession` (active workout) and `CMMotionActivity` classifier (stationary / walking / running / cycling / automotive)
- Pre-entry "body whisper" card — one line of context before recording (e.g. *"You slept 5h 20m. HRV is low. Take a breath."*); suppressed when `activityContext == .active` to avoid interrupting flow
- Heart model upgrade: background metrics + foreground HR delta (when present) feed mood prediction alongside text sentiment
- Causal insights surfaced in the Insights tab: *"Your best mood weeks share 7h+ sleep, 8k+ steps, and mentions of [person]"*
- Twin chat learns to answer body+text questions: *"Why did I feel low Tuesday?"* references body state, not just narrative
- Personal-baseline learner runs nightly to keep "your normal HR/HRV at this hour" accurate
- Permission requested after day 3 of use (not at first-launch) for value-framed acceptance
- Settings → Health: master toggle, per-signal toggles, "Wipe all health snapshots" destructive action
- "Data Not Collected" Apple privacy label preserved — HealthKit reads stay on-device, snapshots live in Core Data + personal iCloud only

**Apple Watch companion app:**
- Quick wrist recording: tap mic, speak, auto-syncs to iPhone via WatchConnectivity
- Heart rate sampled *during* the 42-second recording (Watch is the natural sensor); stored as delta from personal hour-of-day baseline
- Context-aware capture: if recording starts during a workout, HR is **not** stored as an emotional signal — the entry is tagged `body_context: active` and the Twin treats it accordingly
- Constellation pulse: ConstellationView renders subtle pulse intensity on each star from recording HR delta (calm reflection = slow pulse; high-arousal at rest = fast). Active-context entries get a distinct "in motion" star variant instead of pulse intensity
- Embodied entry signature: every star now carries body state alongside mood color
- Watch Complications: streak counter + "today done" status for quick glance
- Native WatchKit target, same SwiftUI codebase patterns where shared
- Works standalone on Watch (records locally) and syncs when iPhone is reachable

**Twin model impact:**
- **Heart** — physiological mood signature improves prediction confidence; distinguishes felt-stress from body-stress; learns separate emotional patterns for at-rest vs active entries
- **Mind** — cognitive-state input ("I'm overthinking on low-sleep days") becomes a learned pattern
- **Voice** — HR/HRV during at-rest speech refines stress detection beyond pacing and tone; active-context recordings rely on voice features alone
- **Graph** — people, places, and activities now link to physiological response, not just sentiment

### v1.5 — Semantic Search & Proactive Insights
- NLEmbedding for 512-dimensional sentence embeddings
- Semantic search via cosine similarity
- K-means clustering for thematic discovery
- Z-score anomaly detection for unusual entries
- Graph-based semantic indexing (text chunks + knowledge graph entities unified)
- Foundation for on-device RAG pipeline (inspired by [MiniRAG](https://github.com/HKUDS/MiniRAG) architecture)
- Causal chains: connect entities temporally to emotional outcomes ("your mood drops after mentions of [person] in [context]")
- Decision-language extraction: detect and store patterns like "I decided to...", "I regret...", "I chose..."
- Embodied search (builds on v1.4 Body Twin): "show me entries where I was stressed but didn't say so" — finds entries where HR was elevated but text stayed neutral

### v1.6 — macOS & Multi-Language
- Native macOS target — same SwiftUI codebase, sidebar navigation, Twin accessible from the desktop
- Multi-language UI via String Catalogs

### v2.0 — Foundation Models + Android *(iOS 26, iPhone 15 Pro+)*

**iOS — Apple Foundation Models:**
- Apple Foundation Models integration (on-device 3B LLM)
- LanguageModelSession for multi-turn conversations
- Tool calling for autonomous Core Data queries
- @Generable for type-safe structured outputs
- Multi-tier personality conditioning for Twin conversations (demographic + behavioral + psychometric prompts, inspired by [PersonaTwin](https://arxiv.org/abs/2508.10906))
- "How would I react?" — Twin predicts your response to situations based on past patterns and personality
- Twin replies in your voice using Apple Personal Voice API (AVSpeechSynthesizer)
- Autobiographical memory consolidation: monthly distillation of journal entries into semantic self-knowledge ("I tend to...", "I always...")
- SpeechAnalyzer replaces SFSpeechRecognizer
- Zero network calls — entire pipeline on-device

**Android — Native Kotlin:**
- Native Kotlin + Jetpack Compose (not KMP — platform-specific AI APIs need native access)
- Tiered AI: Gemini Nano (Pixel/Samsung flagships) → MediaPipe + TFLite fallback → core journal for older devices
- On-device speech: SpeechRecognizer (API 33+) + Vosk fallback
- Room + SQLCipher for encrypted local storage
- Zero INTERNET permission in AndroidManifest.xml (hard OS-level block)
- Google Play "No data collected" Data Safety label
- Constellation UI in Jetpack Compose Canvas
- BiometricPrompt + Android Keystore for security

### v2.1 — LoRA Fine-Tuning
- Personal LoRA adapter training on Mac (macOS app becomes the training environment)
- ~160 MB adapter delivered via Background Assets
- Train the Twin to sound and think like you
- Export entries as JSONL for training
- Validated Big Five personality scoring from journal narratives (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism)
- Scientific personality profile based on [language-based personality modeling research](https://arxiv.org/abs/2506.19258)
- Identity evolution tracking: diff monthly personality snapshots to show how you've changed over time

### v3.0 — True Digital Self *(vision)*

The goal of v3.0 is the most accurate mirror of yourself that has ever existed — one that remembers everything you've shared, sees patterns you can't, and speaks in your voice. Entirely on-device, entirely yours.

**What the Twin can do at v3.0:**

- Talk like you — your vocabulary, phrasing, tone, and reasoning patterns
- Sound like you — replies spoken in your cloned voice (Personal Voice)
- Know what you care about — values, people, topics, ranked by emotional weight
- Know how you've felt across years — full emotional history with temporal patterns
- Predict your likely reaction to familiar situations — grounded in your actual past decisions
- Explain why you feel the way you do — causal reasoning citing specific past entries
- Show how you've changed over time — personality evolution across months and years

**What the Twin cannot do (and why):**

- Replace you in a conversation — it knows your narrated self, not your complete self. The thoughts you don't journal are invisible to it
- Handle truly novel situations — it extrapolates from personality traits, but humans are inconsistent and surprise even themselves
- Feel what you feel — no embodied experience (fatigue, hunger, physical state) or subconscious drives

**The honest framing:** This is not a clone. It's a mirror that deepens every day you journal. After years of daily entries, it becomes something no one else has — a private, evolving, on-device record of who you are and who you've been.

**Technical capabilities:**

- Full RAG implementation with personal knowledge base
- Personal LoRA adapter loaded at runtime
- Autonomous tool calling for data access
- Context condensation for long conversations
- Full causal reasoning: "Why did I feel this way?" with cited evidence from past entries
- Exportable digital self-preservation — your Twin's personality model, knowledge graph, emotional history, and voice in an open format

### v4.0 — DailyVox Mirror *(hardware device — vision)*

A physical tabletop device that IS your Digital Twin — speaks in your voice, thinks like you, answers like you. No internet. No cloud. Your most personal AI, embodied.

**Hardware:**
- Holographic display (Pepper's ghost + high-brightness LCD in dark enclosure)
- On-device LLM (Phi-3 Mini 3.8B + LoRA personality adapter, ~2.3GB)
- Voice cloning (XTTS-v2, needs only 6 seconds of reference audio)
- Speech recognition (whisper.cpp, fully offline)
- Microphone array + speaker
- No WiFi/Bluetooth chip — physically impossible to connect to the internet
- Data import only via USB-C from DailyVox app

**How it works:**
- You journal daily in DailyVox (phone app)
- Periodically sync journal archive to the device via USB-C cable
- Device fine-tunes its personality model from your entries
- Anyone can walk up and ask "you" a question — it answers in your voice, your tone, your reasoning
- The more you journal, the more accurate the mirror becomes

**Target specs:**
- SoC: NVIDIA Jetson Orin Nano (67 TOPS, 8GB) or equivalent edge AI chip
- Storage: 32-64GB (LLM + voice model + journal archive)
- Power: 10-30W, USB-C powered
- BOM target: $300-400 (retail $499-699)
- Privacy: no wireless silicon, encrypted storage, tamper-evident enclosure

---

For technical details, see [ARCHITECTURE.md](ARCHITECTURE.md) and the [Technology page](https://getdailyvox.com/technology.html).
