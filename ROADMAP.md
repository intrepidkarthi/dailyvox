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

### v1.3.5 — New Icon & Dynamic Island
- **New app icon**: golden mic on sage green with 4+2 notch easter egg (matches landing page refresh)
  - Full AppIcon set across all iOS sizes (iPhone, iPad, App Store 1024×1024)
  - iOS 18 dark + tinted icon variants (warm charcoal background, monochrome silhouette)
- **Dynamic Island / Live Activities** (ActivityKit + WidgetKit extension):
  - Recording timer: elapsed time + live waveform in compact pill and expanded view; counts up past the 42-second soft target so users can speak as long as they need
  - Star birth: brief celebratory Live Activity after entry completion ("A new star appeared in your sky"), auto-dismisses
  - Streak tracker (opt-in via Settings): star icon + "Day N" in compact, today-done status in expanded; persists until disabled or streak breaks
  - Constellation Lock Screen widget: Canvas-rendered mini constellation, one star per recent entry, coloured by mood

## Planned

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
- **Voice biomarkers**: on-device prosody analysis (pace, pitch variability, energy, pause patterns) as a mood/stress signal independent of word content — "your voice sounded tired before you said you were". Patterns and reflections only, never diagnoses; per-signal toggle in Settings; raw audio features stay on-device like everything else
- **Twin Resolution score**: a visible accuracy/depth meter that grows with every entry ("your Twin can now see 7 months deep"). Makes the data moat *felt* — the longer you journal, the more it knows, the harder it is to leave

### v1.6 — Foundation Models Twin *(iOS 26, iPhone 15 Pro+)*

The Twin gets a real brain. Apple's on-device Foundation Models framework has been shipping since iOS 26 — this release adopts it fully, replacing the template-based Twin chat with genuine on-device language model conversations grounded in everything the Twin knows.

- Apple Foundation Models integration (on-device 3B LLM)
- LanguageModelSession for multi-turn conversations
- Tool calling for autonomous Core Data queries — the Twin fetches its own evidence
- @Generable for type-safe structured outputs
- RAG grounding via the v1.5 semantic index: every Twin answer cites the entries it drew from
- Autobiographical memory consolidation: monthly distillation of journal entries into semantic self-knowledge ("I tend to...", "I always...")
- SpeechAnalyzer replaces SFSpeechRecognizer
- Zero network calls — entire pipeline on-device
- Graceful fallback to the current Twin chat on devices below iPhone 15 Pro

### v1.7 — macOS, Multi-Language & Spatial
- Native macOS target — same SwiftUI codebase, sidebar navigation, Twin accessible from the desktop
- Strategic purpose: the Mac app is the **LoRA training environment for v2.1** — desktop compute is what makes personal fine-tuning practical
- Multi-language UI via String Catalogs
- **visionOS spatial constellation** *(exploratory)*: walk inside your inner sky — entries as stars around you, years of your life at room scale. The constellation metaphor was built for this

### v2.0 — Apple Intelligence Native *(iOS 27)*

Ride the platform, don't trail it. WWDC 2026 rebuilt Siri on next-generation Foundation Models with OS-level, cross-app context. v2.0 makes the Twin a first-class citizen of that world — while keeping every byte on-device.

- Siri AI integration via App Intents: ask the system assistant and it consults your Twin ("Hey Siri, how was my week really?")
- Cross-app context adoption as Apple opens iOS 27 APIs to third parties — with DailyVox's standing rule: context flows in, nothing flows out
- Next-generation Apple Foundation Models for deeper reasoning and longer conversations
- Multi-tier personality conditioning for Twin conversations (demographic + behavioral + psychometric prompts, inspired by [PersonaTwin](https://arxiv.org/abs/2508.10906))
- "How would I react?" — Twin predicts your response to situations based on past patterns and personality
- Twin replies in your voice using Apple Personal Voice API (AVSpeechSynthesizer)

> **Android: deliberately deferred.** A native Kotlin port doubles the engineering surface right when iOS needs depth. Android happens after iOS retention proves product-market fit — not before. (Prior native-Kotlin design notes preserved in git history.)

### v2.1 — LoRA Fine-Tuning
- Personal LoRA adapter training on Mac (macOS app becomes the training environment)
- ~160 MB adapter delivered via Background Assets
- Train the Twin to sound and think like you
- Export entries as JSONL for training
- Validated Big Five personality scoring from journal narratives (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism)
- Scientific personality profile based on [language-based personality modeling research](https://arxiv.org/abs/2506.19258)
- Identity evolution tracking: diff monthly personality snapshots to show how you've changed over time
- **Talk to your past self**: conversational time-travel built on those snapshots — "ask 2024-you what they were afraid of." The Twin answers as you *were*, citing entries from that era; diff the conversation against present-you to see how far you've come

### v2.2 — Agentic Twin

The Twin stops only reflecting and starts acting — a chief of staff for your inner life. Built on v2.0's tool calling; every action is on-device, user-initiated or explicitly opted into, and explainable ("here's why I'm suggesting this, citing these entries").

- **Weekly review, drafted for you**: the Twin writes your week's reflection from your entries; you edit and approve rather than start from blank
- **Decision pre-briefs**: ask about a decision and the Twin assembles your own precedent — "the last 3 times you felt this way about a job change, here's what you did and how you felt 3 months later"
- **Pattern interrupts**: proactive, gentle, rate-limited — "you haven't mentioned [person] in 6 weeks", "entries about work have darkened for 3 consecutive weeks"
- **Intention follow-through**: detects commitments in entries ("I'll talk to her this weekend") and asks how it went
- **Drafting on request**: "help me write this difficult message the way I'd want to say it" — grounded in your communication style model
- Guardrails: no autonomous outbound actions, no notifications without opt-in, every suggestion cites its evidence

### v2.3 — Ambient Twin *(opt-in passive capture)*

The industry is racing toward always-on AI wearables that journal your day for you — by sending your life to a server. DailyVox's architecture is the only honest way to build this. The Twin learns from your day, not just your narration of it, and nothing ever leaves the device.

- **Day summarization**: on-device synthesis of Watch signals (movement, heart patterns, workouts), location *patterns* (place categories, not coordinates), and calendar context into a draft "here's what your day looked like"
- **Review-and-discard**: every ambient observation lands in a daily review queue — you keep, edit, or discard before anything touches the Twin. Nothing is learned without your eyes on it first
- **Whisper capture**: AirPods quick-journaling — raise to speak, no phone out; transcribed on-device like everything else
- **Gap awareness**: the Twin distinguishes "you didn't journal" from "nothing happened" — ambient context fills silence honestly ("a hard week, three back-to-back conflict meetings, no entries")
- Hard lines: no continuous audio recording, no raw location storage, master kill-switch, ambient data wiped on demand
- Strict superset of the privacy promise: "Data Not Collected" label preserved; ambient capture is off by default

### v2.5 — Twin Protocol *(the open format)*

The infrastructure play. Your digital self should be **yours** — portable, inspectable, not locked inside any app, including this one. And in the agent era, the Twin becomes the **personal context layer**: the thing every AI assistant needs and none of them should own.

- Open specification for the portable personal model: personality vectors + knowledge graph + emotional history + voice profile in a documented, versioned format
- Encrypted container ("`.twin` file") with user-held keys; export and import in full fidelity
- Swift SDK (and reference spec for other platforms) so third-party apps can read a Twin **with user consent, scoped per-field** — a meditation app reads emotional patterns, never raw entries
- **Agent interop**: the Twin as an on-device personal-context server (MCP-style) that AI agents query with per-field consent — your assistant asks your Twin how you like to be briefed; a writing tool asks for your voice profile; neither sees a single journal entry. Consent receipts log every access
- DailyVox becomes the best *producer* of the format, not the only one — the moat moves from lock-in to being the canonical implementation
- Positioning: the personality wallet. Data lock-in is the industry default; portability as a feature is the trust differentiator that matches the privacy brand

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
- Exportable digital self-preservation — your Twin in the open Twin Protocol format (v2.5)

### v3.5 — Twin-to-Twin *(vision)*

Two consenting people let their Twins talk to each other — locally, peer-to-peer, nothing through a server.

- **Couples mode**: both Twins compare patterns and surface what neither person says out loud — "you both journal about the same argument, from opposite sides"
- **Compatibility conversations**: two Twins converse and produce a shared, mutually-visible summary; raw models never leave either device
- Exchange over local transport (Multipeer/AirDrop-style), session-scoped, revocable, with both users seeing exactly what was shared
- Inherently viral mechanics ("my twin talked to my partner's twin") that only work *because* of the privacy architecture — no server-based competitor can copy this honestly

### v4.0 — DailyVox Mirror & Legacy *(hardware device — vision)*

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

**Legacy mode** *(named deliberately — this is the device's deepest purpose)*:

After years of journaling, your Twin is the most complete record of who you are that has ever existed. Legacy mode lets you decide what happens to it.

- **Encrypted bequest**: designate inheritors; the Twin transfers as a sealed `.twin` container (v2.5 format) unlockable only by the keys you leave behind
- A family can keep a Mirror device — your voice, your reasoning, your stories — on a shelf, with no internet, forever
- Strictly opt-in, revocable while living, with an explicit "never preserve" option that guarantees cryptographic erasure
- Honest framing carried over from v3.0: this is not the person — it's the most faithful mirror they chose to leave. Grief-tech demands restraint; the no-radio hardware and user-held keys are the ethical line that makes it defensible

---

For technical details, see [ARCHITECTURE.md](ARCHITECTURE.md) and the [Technology page](https://getdailyvox.com/technology.html).
