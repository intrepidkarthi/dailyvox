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

### v1.4.0 — Warm Look *(shipped)*
- Calm sage-and-gold palette across every screen; the Digital Twin promoted to the center of the app
- Refined recording screen and onboarding; compact audio player on entries; replayable welcome
- Polish and fixes throughout — still free, still 100% on-device

### v1.4.1 — Speak Your First Star *(shipped 2026-07-04)*
- **Voice-first "Speak your first star" onboarding** — the signature moment (voice → a private star carrying your own words), with the first recording persisted as your real first entry
- Warm ivory-light onboarding redesign with an optional Name step
- Widget counter + Star Birth Live Activity fixes
- Rating prompt tuned: first ask at entry 3 (was 5) and after the first share
- Anchored ASO keyword field (`mood tracker` + `digital twin`) and fresh App Store screenshots at current resolutions

## Planned

> **⚠️ Version numbers & status (corrected 2026-07-02; v1.4.1 shipped 2026-07-04).** App Store **1.4.0 shipped the *Warm Look*, not Body Twin.** Body Twin and its review-and-discard queue are **not built yet** — the Phase-1 engine code sits in the private package, unwired (the June 2026 App Review rejection came from *leftover* HealthKit Info.plist keys, since removed). Because the "1.4" build number is already spent, the feature stages below are renumbered up one minor: **Body Twin → v1.5, Ambient → v1.5.5, Memory & Fidelity → v1.6, Foundation Models → v1.7** (v2.0+ unchanged). *Since then: v1.8 became Research Pilot & retrieval-fix, v1.9 became Voice & Access, and Multi-Language moved again to v1.10.* The stage labels are the Twin's growth stages; App Store build numbers increment independently.

> **One device, by conviction.** As of June 2026 this roadmap is iPhone-only — with Apple Watch as the Twin's sensor and iPad along for free. Everything that makes the Twin defensible lives on the device that's with you all day: ambient signals, body sensors, Foundation Models, Apple Intelligence, the "Data Not Collected" label. Journaling is a phone-shaped habit; the phone is not one port target among many — it's the Twin's body. There is no macOS app, no visionOS app, and Android stays deferred until iOS product-market fit. Portability is solved where it belongs — in the *data*, via the open Twin Protocol (v2.5) — not by spreading a small team across platforms.
>
> **The end-to-end rule.** Every feature on this roadmap — from the first entry to v3.0's full digital self — must work for a user whose only computer is their iPhone. No step may ever require a Mac, a desktop, or any second machine: not training, not export, not setup, not backup. If a capability can't be delivered on the phone, it waits for the phone to catch up — it never graduates to a desktop. (The v4.0 Mirror is downstream of the phone, not a dependency: it syncs *from* the iPhone over USB-C and adds embodiment, never capability the app lacks.)

**How the Twin grows.** One device means one trajectory: every release is a stage in the same organism, not a feature grab-bag.

| Stage | Release | The Twin... |
|:--|:--|:--|
| **Scribe** | v1.0–v1.4.1 *(shipped)* | listens, remembers, and reflects what you tell it |
| **Body** | v1.5 *(shipped)* | feels what your body felt — physiology joins the narrative |
| **Senses** | v1.5.5 *(shipped in v1.6.0)* | learns from your day — on-device photo and music signals, reviewed before they touch the Twin |
| **Memory** | v1.6 *(shipped)* | remembers you accurately across years — measurable fidelity + semantic memory |
| **Voice** | v1.7 *(shipped 2026-07-20)* | converses with a real on-device brain, citing your own entries |
| **Spoken** | v1.9 *(shipped 2026-07-31)* | reads its answers back to you — and is usable by people the app had locked out |
| **Polyglot** | v1.10 | speaks your language — depth on one platform, breadth in languages |
| **Citizen** | v2.0 | lives inside the OS — answers through Siri, keeps every byte on-device |
| **Self** | v2.1 | knows who you are — and lets you talk to who you were |
| **Agent** | v2.2 | acts on your behalf, every action explained and evidenced |
| **Presence** | v2.3 | learns from your day, not just your narration of it |
| **Protocol** | v2.5 | becomes portable — yours, not the app's |
| **Mirror** | v3.0+ | the most faithful reflection ever built — eventually embodied (v4.0) |

### v1.5 — Body Twin: HealthKit *(shipped 2026-07-18, build 19)*

> Shipped as the **iPhone HealthKit layer**: per-entry health snapshots, activity-context tags, the review-and-discard queue, the body whisper, and Body & Mood insights. The **Apple Watch companion** (wrist recording + heart rate sampled during the entry) is deferred to a later Body Twin release — the sections below that describe the Watch app are the plan for that follow-on, not what shipped in build 19.

The Twin gains a body. Until now it has learned only from your words; v1.5 gives it physiological context so it can finally tell the difference between "feeling stressed" and *being* stressed. Directly addresses one of the limitations called out for v3.0 ("Feel what you feel — no embodied experience").

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
- **Foundation for ambient capture**: v1.5 introduces the generic *review-and-discard queue* — a reusable surface where passively-captured signals (health snapshots first) wait for you to keep, edit, or discard before they reach the Twin. Building it here is what lets v1.5.5's photo/music signals and v2.3's full Ambient Twin plug in cleanly; every future passive signal is honest-by-default because it flows through this one gate

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

### v1.5.1 — Trust Defaults *(shipped 2026-07-19, in the v1.6.0 build)*

One small change that makes the code agree with the promise:

- **iCloud sync off by default for new installs.** The privacy story says sync is optional; today's default turns it on whenever an iCloud account exists. New installs will start with sync off and a clear opt-in in Settings. Existing users are migrated to keep their current behavior — anyone already syncing stays syncing; nobody's data silently stops.
- Settings copy states plainly where entries live (this iPhone) and exactly what turning sync on changes.

**Bug fixes (reported by Karthik, 2026-07-18):**
- **Personal names mis-transcribed and won't stick.** Uncommon proper nouns — e.g. his daughter's name *Adyah* — are mis-heard on every recording and corrections don't carry to the next entry. Root cause: `SpeechTranscriber.swift:92` builds `SFSpeechURLRecognitionRequest` with no `contextualStrings`, so recognition has no vocabulary bias; each new entry re-mis-hears the name (editing an entry *does* reprocess — `EntryDetailView.swift:668` — but transcription itself has no memory). Fix = feed the Twin's known people/place entities (the knowledge graph already holds them) into `request.contextualStrings`, plus a small user-editable names list so a correction persists across entries. The same customization carries to `SpeechAnalyzer` (now v1.6). Secondary: NLTagger NER may still mis-class an uncommon name in the World map — the confirmed-names list seeds that too.
- **Twin Resolution questions truncate to one line.** `TwinResolutionView.swift:214` caps the question prompt with `.lineLimit(1)`, so every question shows one line + "…" and the full text never reveals. Fix = drop the line limit (or `.fixedSize(horizontal: false, vertical: true)`) so questions wrap.

### v1.5.5 — Ambient Signals *(shipped 2026-07-19, in the v1.6.0 build; pulled forward from v2.3)*

The first taste of the Twin learning from your day, not just your words — and the part of the ambient thesis that needs no new conversational brain, so it ships now rather than at v2.3. Both signals run entirely on-device and flow through the v1.5 review-and-discard queue: nothing is learned without your eyes on it first. This is the differentiation the server-based companion apps structurally cannot copy — they ingest the same signals by uploading your life; DailyVox reads them where they already live.

- **Photo signals**: on-device Photos/Vision scene analysis turns the day's camera roll into context — "mostly trail photos, one birthday dinner." Only derived labels are produced, never the photos themselves, and they never leave the device. Per-day, opt-in, reviewed before anything reaches the Twin
- **Music mood**: listening patterns from your on-device music library as an emotional signal — what you reached for on a hard day says something your entries might not. On-device only; no ShazamKit/network dependency
- **Reuses the v1.5 queue**: no new privacy surface beyond the Photos and Media Library permissions; the review-and-discard gate already exists. "Data Not Collected" label preserved; both signals off by default
- Deliberately *not* here: location, calendar, email — those wait for v2.3's full Ambient Twin (location/calendar) or are ruled out entirely (email credentials). v1.5.5 is the cheapest, highest-trust slice of the ambient bet

### v1.6 — Semantic Memory & Measurable Fidelity *(shipped 2026-07-19, build 20)*

> Shipped: semantic search (NLEmbedding vector index), SpeechAnalyzer transcription on iOS 26+, the openness trait head with per-prediction confidence bands, the prosody/voice-biomarker foundation, the v1.5.5 ambient signals, and the v1.5.1 trust defaults + fixes — all in the single v1.6.0 build. The measurement infrastructure (TwinEval suites incl. groundedness/tonal audits, retrieval and entity evals) lives engine-side and gates releases rather than shipping in-app. **Deferred from the original v1.6 scope** to a later release: proactive-insight clustering/anomaly detection, causal chains, decision-language extraction, embodied search, and the agentic long-term-memory/summary-distillation designs below (superseded in part by v1.7's grounded chat).

Reframed from "semantic search + insights." Now that v1.5 gives the Twin a body, the binding constraint is no longer *more signals* — it's proving the Twin **remembers accurately across years** and **models you rather than imitates you**. So evaluation and long-term memory move onto the critical path *ahead* of v1.7's on-device brain: you can't tell whether the Foundation-Models Twin beats the template Twin without a fidelity number, and you can't ground it without a memory layer. **Measurement infrastructure comes before features.**

**Measurable fidelity (build first — currently the roadmap's biggest gap):**
- **Twin Resolution score** — the surfaced number, now backed by a real harness. A self-prediction fidelity benchmark in the style of Park et al. ([arXiv:2411.10109](https://arxiv.org/abs/2411.10109)): the Twin predicts your answers to a fixed, periodically-answered questionnaire from your entries alone, **normalized against your own two-week test-retest consistency**. Floor to beat: 74% (demographics-only); aspiration: the 83–86% band self-report agents reached. Shown in-app as "your Twin can now see N months deep" so accuracy is *felt*, not claimed.
- **Out-of-Character (OOC) rate** — an atomic-level persona-fidelity metric ([arXiv:2506.19352](https://arxiv.org/abs/2506.19352)) tracked across releases as the drift regression-alarm. A feature that raises fidelity on paper but increases OOC drift is a net loss; this catches it.
- **Faithful-reflection (anti-sycophancy) audit** — measure whether the Twin reflects an *accurate* rather than *flattering* version of you (false-premise correction rate). Early on-device evidence: journal-grounded, evidence-forced answering is the dominant mitigation. A mirror that only tells you what you want to hear is worse than useless.

**Semantic memory:**
- NLEmbedding sentence-embedding vector store + semantic search via cosine similarity.
- **SpeechAnalyzer transcription** (pulled forward from v1.7): on iOS 26+ the new long-form `SpeechAnalyzer`/`SpeechTranscriber` replaces `SFSpeechRecognizer` for entry transcription — measurably lower word-error rate on sustained speech, still fully on-device, models managed by the system (zero app-size cost). Earlier iOS keeps the current on-device recognizer; better transcripts feed every layer above.
- Graph-based semantic indexing (text chunks + knowledge-graph entities unified) with **boundary-aware retrieval** to stop the Twin recalling wrong facts ([RoleRAG, arXiv:2505.18541](https://arxiv.org/abs/2505.18541)).
- **Long-term memory as tools** — the Twin decides what to store, retrieve, update, summarize, or discard (design from Agentic Memory, [arXiv:2601.01885](https://arxiv.org/abs/2601.01885)); benchmarked against **MemoryCD** ([arXiv:2603.25973](https://arxiv.org/abs/2603.25973)), which the field has *not* solved — an open problem DailyVox's longitudinal single-user data is uniquely positioned to contribute to.
- **Offline monthly summary distillation** — task-aware user summaries generated on-device, combined with light runtime retrieval ([arXiv:2310.20081](https://arxiv.org/abs/2310.20081): matches or beats pure retrieval with ~75% less retrieved data — the difference between a sluggish and a snappy Twin). Feeds both the memory layer and the v1.6 RAG pipeline. (MiniRAG remains architectural inspiration for RAG on small models.)

**Proactive insights (carried from the original scope):**
- K-means thematic clustering; Z-score anomaly detection for unusual entries.
- Causal chains: entities → emotional outcomes over time ("your mood drops after mentions of [person] in [context]").
- Decision-language extraction ("I decided to…", "I regret…", "I chose…").
- Embodied search (builds on v1.5 Body Twin): "show me entries where I was stressed but didn't say so" — HR elevated, text neutral.
- **Voice biomarkers**: on-device prosody analysis (pace, pitch variability, energy, pause patterns) as a mood/stress signal independent of word content. Patterns and reflections only, never diagnoses; per-signal toggle in Settings; raw audio features stay on-device like everything else.

> **The honest ceiling (unchanged from v3.0's framing).** This is a *mirror* of your reflective self: attitudes, personality, and reflective responses transfer well (83–86% of your own self-consistency); one-shot strategic decisions in novel situations do not. DailyVox is built and marketed as **reflection and precedent, never a decision-making oracle** — and never a mood-diagnosis tool (passive affect sensing tops out ~0.74 AUROC: insight, never diagnosis).

### v1.7 — Foundation Models Twin *(shipped 2026-07-20, build 22; iOS 26, Apple Intelligence devices)*

> **Shipped 2026-07-20 (build 22).** Ask Your Twin answers free-text questions with Apple's on-device model, grounded in your entries and citing them; a deterministic audit gates every answer before it renders (failures fall back to the classic chat). On iPhones without Apple Intelligence, the same box answers from on-device semantic search over your entries. The evaluation gate — a live battery against the real on-device model (honesty, fallback rate, anti-sycophancy, injection and abstention safety) — passed twice consecutively; recorded runs live in the engine repo.

The Twin gets a real brain. Apple's on-device Foundation Models framework has been shipping since iOS 26 — this release adopts it fully, replacing the template-based Twin chat with genuine on-device language model conversations grounded in everything the Twin knows.

- Apple Foundation Models integration (on-device 3B LLM)
- LanguageModelSession for multi-turn conversations
- Tool calling for autonomous Core Data queries — the Twin fetches its own evidence
- @Generable for type-safe structured outputs
- RAG grounding via the v1.5 semantic index: every Twin answer cites the entries it drew from
- Autobiographical memory consolidation: monthly distillation of journal entries into semantic self-knowledge ("I tend to...", "I always...")
- Zero network calls — entire pipeline on-device
- Graceful fallback to the current Twin chat on devices below iPhone 15 Pro

### v1.8 — Research Pilot & a Twin That Actually Answers *(shipped 2026-07-23, build 23)*

> **Shipped 2026-07-23 (build 23).** v1.7's Ask Your Twin retrieval path was measured post-ship to abstain on almost every real-diary question — whole-entry averaged embeddings put realistic question-vs-entry cosine at 0.02–0.25 against a 0.37 threshold tuned only on synthetic data. Retrieval is now hybrid (per-sentence max cosine + content-word overlap), re-measured against a realistic-failure eval leg (τ=0.29, 98.2% balanced accuracy), and verified end-to-end on device: real questions now answer with dated, cited entries instead of the honest-abstention fallback. Alongside it: the recording-time self-label capture that feeds the affect-research pilot (Experiment B, per-person adaptation), a neutral "just log your day" prompt for the scarce neutral class, and a pass of brand-consistency, streak-milestone, and topic-extraction fixes found in a full app walkthrough.

- **Ask Your Twin, fixed** — hybrid sentence-level retrieval replaces whole-entry cosine; re-measured abstention threshold; unrelated questions still abstain honestly, journaled topics now surface with "From your journal" citation chips
- **Research pilot: recording-time self-labels** — pilot participants (Settings → Research) get a one-tap emotion + intensity check right after each recording, feeding the affect-research program's per-person adaptation experiment; on-device only, leaves the phone solely via the existing user-initiated research export
- **Neutral prompt nudge** — pilot participants occasionally see a plain "Just log your day" starting thought instead of the usual emotionally-loaded prompts, so the pilot corpus isn't neutral-starved
- Brand-consistency fixes: Ask Your Twin and Settings now render in the app's warm ivory palette instead of the system default gray
- Streak milestone now celebrates once, at the highest crossed threshold — a long streak no longer replays "7-Day Streak!" on every visit
- Entry Topics and Twin "Main themes" no longer surface temporal filler ("Today", "Morning", "While") as if it were a subject

### v1.9 — Voice & Access *(shipped 2026-07-31, build 24)*

> The Twin gets a voice, and the app gets usable by people it previously locked out. Both came out
> of the same week: a growth diagnosis that found retention — not discovery — was the binding
> constraint, and a UI/UX audit against the App Store featuring bar that found the accessibility
> gap was the blocker.

- **Twin Voice** — Ask Your Twin can read its replies aloud, using a voice already installed on the
  iPhone, with a picker so a regional variant can be chosen if it sounds closer. Entirely
  on-device, off by default, no permission prompt and no enrollment.
  *Accent is approximated, not reproduced, and that is a deliberate stopping point.* Apple's
  Personal Voice does carry the user's real accent, but it costs a ~30-minute enrollment (150
  sentences, read in Settings) that the app cannot perform for them — if the creator won't do it,
  users won't either. Voice cloning from existing journal audio was investigated at length and
  looked closed at the time this shipped: accent lives in phone realisation and phonemic choice,
  and everything carrying those is autoregressive over a reference prompt, which appeared not to
  fit a phone's memory budget. **That conclusion was overturned the day after this build was cut
  — see "Your own voice" under v1.10.** The stopping point stands for *this release*, not as a
  permanent verdict. Both paths slot in behind `resolvedVoice` without touching callers when one
  qualifies. See `project_voice_cloning_spike` and §Deferred below.
- **The daily reminder is finally offered** — it defaulted to OFF and was reachable only by digging
  through Settings, which for a once-a-day app meant the entire habit loop was invisible. Now
  offered pre-checked at the end of onboarding, where the copy already promises "speak again
  tomorrow, and your sky grows", with the notification permission requested at peak intent rather
  than cold on launch. Notification copy rewritten to name the 42-second commitment.
- **Dynamic Type across the app** — 138 fixed font sizes converted to semantic text styles. 35 of
  them were below 11pt, Apple's stated minimum, and were mapped *up* rather than ported across: a
  legibility fix as much as a scaling one. Share-card renderers deliberately keep fixed sizes, since
  they draw into fixed-size images.
- **Constellation labels made legible** — the signature visual rendered at 9pt / 0.30 opacity, which
  measures 2.50:1 against its background and fails WCAG outright. Now 8.75:1.
- **Twin section picker no longer rests mid-word**, and its chips announce their selected state to
  VoiceOver instead of reading as six identical unlabelled buttons.
- Twin Resolution ring gained an accessibility label and value — it was pure geometry, so VoiceOver
  announced nothing where the score is the whole point of the card.

*Why accessibility is on the roadmap and not in a backlog:* DailyVox exists because its creator lost
the ability to write by hand. The origin story is an accessibility story, and the app would have
failed an accessibility review — which is also the single most common reason a well-made indie app
does not get featured. See `marketing/launch/ux-featuring-readiness-2026-07-26.md`.

### v1.10 — Multi-Language

iPhone-first by conviction, not just sequencing. Everything that makes the Twin defensible — ambient signals, Watch sensors, Foundation Models, Apple Intelligence — lives on the device that's with you all day, and journaling is a phone-shaped habit. Growth comes from languages, not platforms.

- **Your own voice — candidate, gated on one measurement.** The v1.9 note below says accent cannot
  be reproduced at a size a phone can hold. **That stopped being true on 2026-07-28.** Kyutai Pocket
  TTS reproduced Karthik's voice from a 30-second slice of *existing journal audio* — no enrollment,
  nothing asked of the user — and he confirmed it by ear after every previous attempt failed on
  accent. The unlock was mundane: normalise the reference clip to full scale before conditioning,
  and use the full 30 s the model accepts. Model is 109.5M params, uniformly BF16, autoregressive
  (which is why it carries accent where OpenVoice could not), RTF 0.20. An ExecuTorch iOS export
  exists with the voice-reference encoder included: 69 MB at enrolment, then unloadable, leaving a
  188 MB synthesis path. **Ships only when: (1) iPhone peak RSS is measured, not projected —
  Chatterbox died at exactly this stage of confidence; (2) the weights come from the official gated
  download rather than the unlicensed mirror used for the spike; (3) it is re-validated on real
  44.1 kHz journal `.m4a`, not the 22 kHz mp3 the spike ran on.** See
  `project_voice_cloning_spike_2026_07_27` for the working recipe and the licence landmines.
- Multi-language UI via Xcode String Catalogs — Tamil, Kannada, Hindi, Spanish, Japanese, German first
- Speech framework already transcribes 60+ languages on-device; the UI catches up to the pipeline
- **No second platform.** The macOS target is dropped (v2.1's re-scope to on-device persona conditioning removed its last reason to exist); the visionOS spatial-constellation exploration is dropped; Android stays deferred until iOS product-market fit (see v2.0 note)

### v2.0 — Apple Intelligence Native *(iOS 27)*

Ride the platform, don't trail it. WWDC 2026 rebuilt Siri on next-generation Foundation Models with OS-level, cross-app context. v2.0 makes the Twin a first-class citizen of that world — while keeping every byte on-device.

- Siri AI integration via App Intents: ask the system assistant and it consults your Twin ("Hey Siri, how was my week really?")
- Cross-app context adoption as Apple opens iOS 27 APIs to third parties — with DailyVox's standing rule: context flows in, nothing flows out
- Next-generation Apple Foundation Models for deeper reasoning and longer conversations
- Multi-tier personality conditioning for Twin conversations (demographic + behavioral + psychometric prompts, inspired by [PersonaTwin](https://arxiv.org/abs/2508.10906))
- "How would I react?" — Twin predicts your response to situations based on past patterns and personality
- Twin replies in your voice using Apple Personal Voice API (AVSpeechSynthesizer)

> **Android: deliberately deferred.** A native Kotlin port doubles the engineering surface right when iOS needs depth. Android happens after iOS retention proves product-market fit — not before. (Prior native-Kotlin design notes preserved in git history.)

### v2.1 — Personality Depth *(re-scoped for one device)*

Originally planned as Mac-based LoRA fine-tuning; the iPhone-only commitment retires the desktop training rig. Personalization moves from *training weights* to *conditioning the on-device model* with a scientifically grounded personality profile — no export step, no second machine, nothing leaves the phone. The Twin sounds like you because every conversation is grounded in your measured personality and your own words, not because weights were tuned on a desktop.

- Validated Big Five personality scoring from journal narratives (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism)
- Scientific personality profile based on [language-based personality modeling research](https://arxiv.org/abs/2506.19258)
- **Deep persona conditioning**: v2.0's multi-tier prompts upgraded with the Big Five profile plus retrieved style exemplars — your actual phrasings, drawn from the v1.5 semantic index, steer every reply
- Identity evolution tracking: diff monthly personality snapshots to show how you've changed over time
- **Talk to your past self**: conversational time-travel built on those snapshots — "ask 2024-you what they were afraid of." The Twin answers as you *were*, citing entries from that era; diff the conversation against present-you to see how far you've come
- *Sounding* like you stays with Personal Voice (v2.0); *thinking* like you is conditioning + retrieval. If Apple ever ships user-level adapter training on-device, weight-level personalization returns to the table — on the phone, where it belongs

### v2.2 — Agentic Twin

The Twin stops only reflecting and starts acting — a chief of staff for your inner life. Built on v2.0's tool calling; every action is on-device, user-initiated or explicitly opted into, and explainable ("here's why I'm suggesting this, citing these entries").

- **Weekly review, drafted for you**: the Twin writes your week's reflection from your entries; you edit and approve rather than start from blank
- **Decision pre-briefs**: ask about a decision and the Twin assembles your own precedent — "the last 3 times you felt this way about a job change, here's what you did and how you felt 3 months later"
- **Pattern interrupts**: proactive, gentle, rate-limited — "you haven't mentioned [person] in 6 weeks", "entries about work have darkened for 3 consecutive weeks"
- **Intention follow-through**: detects commitments in entries ("I'll talk to her this weekend") and asks how it went
- **Drafting on request**: "help me write this difficult message the way I'd want to say it" — grounded in your communication style model
- **Relationship map, yours to correct**: the Twin's model of the people in your life — built only from your own entries — is fully inspectable and editable. See what it believes about each relationship, correct it, or delete it entirely. Derived social graphs you can't audit are the industry's anti-pattern; here the map is a first-class screen
- Guardrails: no autonomous outbound actions, no notifications without opt-in, every suggestion cites its evidence

### v2.3 — Ambient Twin *(opt-in passive capture)*

The industry is racing toward always-on AI wearables that journal your day for you — by sending your life to a server. DailyVox's architecture is the only honest way to build this. v1.5.5 ships the first ambient signals (photo, music); v2.3 completes the thesis — the Twin synthesizes a *whole day* from every passive signal, not just your narration of it, and nothing ever leaves the device.

- **Day summarization**: on-device synthesis of the v1.5.5 photo/music signals plus Watch signals (movement, heart patterns, workouts), location *patterns* (place categories, not coordinates), and calendar context into a draft "here's what your day looked like"
- **New ambient inputs**: location *patterns* and calendar context join the photo/music signals already shipped — the same review-and-discard gate, more of the day covered
- **Whisper capture**: AirPods quick-journaling — raise to speak, no phone out; transcribed on-device like everything else
- **Gap awareness**: the Twin distinguishes "you didn't journal" from "nothing happened" — ambient context fills silence honestly ("a hard week, three back-to-back conflict meetings, no entries")
- Hard lines: no continuous audio recording, no raw location storage, master kill-switch, ambient data wiped on demand
- Strict superset of the privacy promise: "Data Not Collected" label preserved; ambient capture is off by default

### v2.5 — Twin Protocol *(the open format)*

The infrastructure play. Your digital self should be **yours** — portable, inspectable, not locked inside any app, including this one. And in the agent era, the Twin becomes the **personal context layer**: the thing every AI assistant needs and none of them should own.

> **Spec ships before the implementation.** The Twin Protocol *specification* — the documented, versioned format — is published as a standalone document well ahead of the full SDK, as soon as the v2.1 personality model stabilizes. A public format spec is a credibility artifact in its own right (citable, reference-able, a standards-positioning move) and costs little next to the implementation. It is the clearest signal that DailyVox is building an open personal-data standard, not just an app.

- Open specification for the portable personal model: personality vectors + knowledge graph + emotional history + voice profile in a documented, versioned format
- Encrypted container ("`.twin` file") with user-held keys; export and import in full fidelity
- Swift SDK (and reference spec for other platforms) so third-party apps can read a Twin **with user consent, scoped per-field** — a meditation app reads emotional patterns, never raw entries
- **Agent interop**: the Twin as an on-device personal-context server (MCP-style) that AI agents query with per-field consent — your assistant asks your Twin how you like to be briefed; a writing tool asks for your voice profile; neither sees a single journal entry. Consent receipts log every access
- DailyVox becomes the best *producer* of the format, not the only one — the moat moves from lock-in to being the canonical implementation
- Positioning: the personality wallet. Data lock-in is the industry default; portability as a feature is the trust differentiator that matches the privacy brand
- **The platform hedge**: the app is iPhone-only by conviction, but your digital self is not locked to any platform — the `.twin` format is how the Twin outlives device choices. The honest answer to "what about Android?" is a protocol reader, not a port

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
- Persona conditioning stack (v2.1) loaded at runtime: Big Five profile + style exemplars + autobiographical memory
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

A physical tabletop device that IS your Digital Twin — speaks in your voice, thinks like you, answers like you. No internet. No cloud. Your most personal AI, embodied. This is the one deliberate exception to the one-device conviction: not a port, a graduation — the Twin leaves the phone only to take physical form.

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
