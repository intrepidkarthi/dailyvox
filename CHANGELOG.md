# Changelog

All notable changes to DailyVox are documented here.

## [Unreleased] — Android

The Android app is **in development and not released**. There is no Play Store
listing and no announced date. This section tracks it so the work is visible;
nothing here has shipped to a user.

### Added
- Native Kotlin / Jetpack Compose app, feature-complete against iOS v1.10 in
  development builds: record, transcribe, detect names, score mood, file, search,
  Twin constellation, Ask, Insights, entry detail with audio playback, PDF and
  JSON export, encrypted backup, photo attachments, self-labels, read-aloud,
  daily reminder, home-screen widget, Quick Settings tile, app shortcuts,
  biometric lock, prosody, and Health Connect body signals.
- Full VADER lexicon bundled as an asset (7,517 entries, 30 KB deflated), so the
  scorer is the one the measured r = +0.663 was earned on rather than a subset.
- Prosody extraction: autocorrelation pitch, RMS energy, pause structure, and
  speaking rate measured per second of *voiced* audio rather than wall clock.
- Cross-platform encrypted backup, verified in both directions against Apple's
  CryptoKit.

### Fixed, before anyone was affected
- **Android Auto Backup was enabled by default**, which would have copied the
  journal database and every audio recording to the user's Google Drive. The
  system performs that copy, so it required no INTERNET permission from the app:
  every privacy claim would have remained technically true while the diary sat
  on a server. Now explicitly disabled, with local device-transfer kept.
- **The encrypted backup could only be restored to the install that wrote it.**
  It keyed from the Android Keystore, whose entries die when app data is cleared
  or the app is uninstalled — so reinstall, factory reset and new phone, every
  real reason to hold a backup, produced an unreadable file, silently.
- **A schema change crashed every existing install on launch.** Prosody columns
  were added without bumping the Room version. `fallbackToDestructiveMigration`
  was removed rather than used: on a journal it means "if the schema confuses us,
  delete their diary."
- **The recogniser failed in silence.** `onError` discarded the error code, so a
  missing offline language pack was indistinguishable from successfully
  recording silence, and the record button appeared permanently broken with no
  explanation. The app cannot fetch that pack — it holds no network permission —
  so it now names the Android setting that fixes it.

### Known unverified
- The entity graph depends on Android's speech recogniser capitalising names.
  That has not been tested across a broad range of physical devices, and it is
  why there is no release date.

## [1.11.0] — unreleased

### Fixed, and this one matters most
- **Voice recordings were being sent to Apple's speech servers.** The
  transcriber read "prefer on-device recognition when offline", which meant that
  on a connected iPhone — nearly every user, nearly always — the recording was
  uploaded for better punctuation. Every claim the product makes rested on that
  not happening: "nothing you say leaves this phone", the 0-calls ledger, the
  0 BYTES OUT on the Dynamic Island, the shareable privacy receipt. On-device
  recognition is now unconditional; where it is unavailable, transcription fails
  and says why rather than reaching for the network. Voice search had the same
  fault and the same fix.
- **Settings claimed "Network calls made: 0 · EVER" while the app linked
  CloudKit and offered a sync toggle.** A claim nothing can falsify is not a
  claim. The Data Shield panel now reports what is actually true — including
  when iCloud sync is on — and the shareable receipt prints the sync setting
  instead of a zero it could not vouch for.
- The lock screen reported "Authentication failed" to anyone who dismissed the
  Face ID prompt, and kept reporting it for the rest of the session. Cancelling
  is not failing.
- Tab bar targets were 31pt against a 44pt floor, and the bar sat inside the
  home-indicator strip — so tabs often needed pressing twice. With a keyboard
  up, taps fell through the bar entirely.
- Entry actions sat underneath the floating tab bar and could not be pressed.
- **The Journal's starred filter could not be reached.** Its button lived in a
  navigation bar the screen hides, so it rendered nothing — you could star an
  entry, count starred entries in Insights and export only starred entries, but
  never look at them. It now sits in the filter row, where a filter belongs.
- **The Record tab and Insights disagreed about the streak.** Three copies of
  one rule existed and the most prominent was wrong: it counted back from the
  latest entry without checking the run reached the present, so a journal last
  written in March still read "5-day streak". One definition now, with tests.
- **An entry's timestamp changed when you edited it.** The line read from the
  modification stamp, so fixing a typo at 11:47pm rewrote a morning entry to
  "11:47 PM". It reads the time the entry was spoken.
- **An edit could be lost.** Text and mood were written only when the screen
  went away; backgrounding the app and having iOS reclaim it discarded them.
  Done saves, and so does leaving the foreground.
- Selecting text in an entry opened the editor instead — two gestures on one
  press, with the destructive one winning.
- The Journal greeted a brand-new user with "No entries found" and a magnifying
  glass: a search failure for a search they had not run.
- The Twin's first-run screen ran under the floating tab bar, told users to go
  to a "Record tab" that is called Speak, and pointed a hand leftward at it.
- Pull-to-refresh in the Journal buzzed, waited, and did nothing.
- Pressing Return while searching threw you off the screen into a second search.
- The reminder rows always showed Evening ticked, whatever time was scheduled.
- Touch targets under the 44pt floor: the route to Settings, mood and date
  filters, filter chips, the Twin's section picker, storage refresh.
- Body context was joined to an entry by the day the user *reviewed* the reading
  rather than the day it was taken. Review is batched, so working through a week
  of pending snapshots in one sitting stamped them all with the same date — and
  an entry would then show a night's sleep belonging to a different night.
- Recording is no longer lost to a phone call: an interruption pauses and keeps
  what was captured, rather than ending the entry silently.

### Added
- **Live transcription.** The recording dial and the Dynamic Island now show
  what is being heard as it is heard, with a gold star when a name is caught.
  On-device only; if it cannot run, the recording is unaffected.
- **Dynamic Island**, in full: the 42-second ring, the caught name, the live
  phrase, a mood bar, and Finish / Discard from the Lock Screen.
- **A Control Centre control** — the iOS answer to Android's Quick Settings
  tile. Assignable to the Action Button.
- **The three faces ship with the app** — Nunito, Inter, DM Mono — replacing the
  system font everywhere, and text now scales with Dynamic Type.
- **The constellation encodes the journal.** Distance from the centre is how
  long ago; angle is the hour it was spoken; size is how long you spoke; colour
  is mood. Named people sit close and bright when they are recent and frequent,
  and drift out as they fade. Before this, position came from a hash and size
  from a list index — it had the grammar of a chart and said nothing.
- **A "Tonight" share card**, different every night by construction. Everything
  else was occasional; there was nothing to post on an ordinary Tuesday.
- **A "Body" share card** — nights slept, and how mood read after a long night
  against a short one. It is the only shareable that can carry a health fact, so
  it is held to a stricter rule than names: it is absent unless body signals were
  kept, its own switch starts off every time the sheet opens, and with the switch
  off the card renders a withheld state rather than the same picture unguarded.
  Heart-rate variability and resting heart rate never reach a card at all.
- Full-screen recording dial with Discard, Stop & keep, and a real Pause.
- "What your Twin filed" on an entry, with gold-underlined names, plus Edit and
  Ask about this.
- A visible semantic search field in the Journal, in the product's own words.
- Ask your Twin as a Siri intent, answered on the device with its citation count.
- Reduced-motion support, and a real sunset that follows the sun.
- **A privacy manifest** (`PrivacyInfo.xcprivacy`), which the binary had never
  carried. It declares no tracking, no tracking domains, no collected data types
  and one required-reason API — UserDefaults, reason CA92.1. An audit found no
  other required-reason API in use, so without the manifest the only thing
  missing was the declaration, not the compliance.

### Changed
- **The mic sits at the bottom of the Speak tab.** It was a centred object about
  45% up the screen — outside the arc a thumb reaches on the phone holding it.
  The question stays married to the button, so the pair moved down together.
- Insights lost its "AI Insights" card. "AI" is the category this product
  defines itself against, and the card said what "Your Twin noticed" says
  further down the same scroll. Entry detail had already dropped its copy.
- Reaching a milestone no longer throws a full-screen gold trophy over Insights
  before you have read a word of it. It is a line on the streak card.
- The Twin screen printed the same entry count four times. The badge keeps it.
- Settings, presented as a sheet, gained a Done button, and its two privacy
  sections stopped contradicting each other about iCloud.
- The Journal's search field said "Describe it — search what you meant" while
  running a substring match. It says "Search your entries"; search-by-meaning is
  offered from the empty result, which is when it is actually worth having.
- Sharing reaches three surfaces — an entry, the Journal and the sky — rather
  than one glyph in one corner. Insights is a named action, not an icon.
- The Record screen is the question and the microphone, centred, with today's
  star beneath. The inert "Add a star" card — which drew a microphone that did
  nothing, above the real one — is gone.
- Fewer surfaces throughout: the second filter row, the permanent privacy card,
  the duplicate metadata card, per-row chevrons and the "AI Insights" panel have
  all been removed. "AI Insights" and "What your Twin filed" were two names for
  the same thing.

### Known
- Recording still stops if the app is backgrounded. This is deliberate: a
  microphone foreground service would add permissions to a ledger the product
  invites people to audit.
- 91 of 422 user-visible strings have no German, Spanish, French or Italian
  translation and fall back to English — 20 of them new in this release. Not
  machine-translated on purpose: several are deliberately typographic English,
  and the rest carry a voice a literal translation would flatten.
- App Store screenshots have not been regenerated for this release. They show
  the old centred microphone, the old Journal header and a sky placed by hash.
- The amended privacy policy is committed but not deployed. The old wording said
  health data is "never shared with anyone", which the Body card makes untrue in
  the one way that matters — you can now put your own sleep on a card. App Review
  reads the hosted page, so it has to go live before submission.

## [1.10.0] — 2026-08-11

### Added
- **The interface now ships in Spanish, French, German and Italian** alongside English, via a single `Localizable.xcstrings` String Catalog (358 strings, complete in all four). It follows your iPhone's language automatically; there is nothing to switch on.

### Why only four
- Search by meaning relies on `NLEmbedding.sentenceEmbedding`, which Apple provides for English, Spanish, French, German and Italian only. Shipping the interface in a language where that feature silently returned nothing would have been a worse experience than waiting. Tamil and Kannada, which earlier roadmaps listed first, are supported by neither Speech API and are not deferred — they are out until Apple's coverage changes.
- Recording already worked in every language the iPhone can transcribe, and still does. This release changed the interface language, not what you can speak.

### Changed
- **App Store screenshots rebuilt across all four device sizes.** The previous set was captured on 3 July and was three releases behind, showing none of v1.6 semantic search, v1.7 Ask Your Twin or v1.9 read-aloud.

## [1.9.0] — 2026-07-31

### Added
- **Your Twin can read its replies aloud.** Tap "Read aloud" under any answer. Choose the voice in Settings → Twin Voice — regional voices are listed first, so pick whichever sounds closest to you, and press "Hear a sample" to compare. Synthesis happens on this iPhone; nothing is uploaded. Off by default, and it never asks for a permission.
- **DailyVox now offers the daily reminder when you finish setting up.** It used to default to off and sit several taps deep in Settings, which meant most people never found the one thing that brings them back tomorrow.

### Changed
- **Text scales with your system text size.** 138 places in the app used a fixed font size and ignored Accessibility → Display & Text Size entirely. Thirty-five of them were smaller than Apple's own 11pt minimum and are now larger, so this is a legibility fix for everyone, not only for people using larger text.
- The daily reminder now reads "Forty-two seconds — what happened today?" instead of a generic nudge.

### Fixed
- **The constellation on your Twin screen is readable.** The labels — the names and topics drawn from your entries — rendered at 9pt and 30% opacity, measuring 2.5:1 against the dark card. They were effectively invisible. Now 8.75:1.
- The Twin's section picker no longer comes to rest with a word cut in half, and it tells VoiceOver which section is selected instead of reading as six identical buttons.
- The Twin Resolution ring now announces its score to VoiceOver. It was pure geometry, so the number — the entire point of the card — was silent.

### Build
- `MARKETING_VERSION` 1.8.0 → 1.9.0; `CURRENT_PROJECT_VERSION` 23 → 24.
- Website: pinned-device hero (the app demonstrates itself), homepage FAQPage schema, footer version markers.
- SEO: E-E-A-T pass across all nine striking-distance pages — disclosures, methodology, a "where DailyVox falls short" section, and Person (not Organization) author schema.

## [1.8.0] — 2026-07-23

### Fixed
- **Ask Your Twin actually answers now.** v1.7's retrieval scored realistic questions against your entries at cosine 0.02–0.25 — below the 0.37 abstention threshold — so the chat abstained on almost every real diary question despite working in demos. Retrieval is now hybrid (per-sentence max cosine + content-word overlap) with a re-measured abstention threshold (τ=0.29, 98.2% balanced accuracy on a realistic eval leg authored from this exact failure). Unrelated questions still abstain honestly; journaled topics now surface with dated, cited entries.
- Streak milestones now celebrate once, at the highest crossed threshold — a long streak no longer replays "7-Day Streak!" on every Insights visit.
- Entry Topics and the Twin's "Main themes" no longer surface temporal filler ("Today", "Morning", "While") as if it were a subject.
- Ask Your Twin and Settings now render in the app's warm ivory palette — they were falling back to the system default gray.
- "Recording saved but not yet transcribed" (offline / no speech detected) no longer alerts as "Recording Error."
- Minor grammar fix in the Twin's growth summary.

### Added
- **Research pilot: recording-time self-labels.** Pilot participants (Settings → Research) get a one-tap "how did that feel?" picker right after each recording — 7-class emotion + intensity, on-device only, leaving the phone solely via the existing user-initiated research export. Feeds the affect-research program's per-person adaptation experiment (K-curve harness, engine-side).
- **Neutral prompt nudge.** Pilot participants occasionally see a plain "Just log your day" starting thought instead of the usual emotionally-loaded prompts, so pilot data isn't neutral-starved — neutral is the scarce hard class in real diary data.

### Build
- `MARKETING_VERSION` 1.7.0 → 1.8.0; `CURRENT_PROJECT_VERSION` 22 → 23.
- App icon: four mac-idiom @2x slots were carrying oversized source images (each exactly 2x the declared size); regenerated at the correct pixel dimensions.
- Engine (DailyVoxTwin): `SemanticMemoryIndex` moved to per-sentence hybrid indexing (store payload v2); `RetrievalSuite` gained a realistic-failure eval leg; new `KCurveSuite` scaffolds the per-person adaptation experiment (Experiment B) against the research-export format.

## [1.7.0] — 2026-07-20

### Added
- **Ask Your Twin becomes a real conversation** — on iPhones with Apple Intelligence (iOS 26+), the Twin answers free-text questions using Apple's on-device foundation model, grounded in your own entries and live Twin state. Ask anything, in your own words.
- **Every answer shows its sources** — "From your journal" citation chips under each answer open the exact entries the Twin drew from. No citation, no claim: the answer structure forces every factual sentence to cite an entry or a measured Twin signal, and a deterministic audit checks every answer before it renders. An answer that fails the audit never appears — the classic chat answers instead.
- **Honest by construction** — the Twin cannot cite an entry it didn't retrieve or a signal it hasn't measured (structurally impossible, not just checked); numbers only appear copied verbatim from your data; a hard week is reflected plainly, never spun. Verified by an adversarial evaluation battery (grounding, tone, false-premise resistance, prompt-injection resistance) that the release had to pass twice consecutively — the recorded runs live in the engine repository.
- **Suggested follow-ups** — the Twin offers up to three next questions after each answer.
- **Free-text questions on every iPhone** — on devices without Apple Intelligence, asking in your own words searches your journal by meaning and answers with your closest entries quoted verbatim, dated, and cited — or says plainly that you haven't written about it. No model, no guessing; the same honest surface also catches any conversational answer the audit rejects.
- **An invitation to the research pilot** — journalers with a few weeks of entries see a single, dismissible card in the Twin tab inviting them to the consented validation study. It appears once, links to the research page, and participation is an explicit, email-based, consent-first process — the app itself still collects nothing.

### Changed
- The classic question-chip chat remains the experience on iOS below 26, on devices without Apple Intelligence, when the model is still preparing, when Twin Brain is switched off in Settings — and for any single answer the audit rejects. Same template answers as before, now served from the evaluation-locked engine copy.
- Settings gains a **Twin Brain** section (only on capable devices): on by default — it adds no new permission or data flow — with a switch back to the classic chat.

### Privacy
- The entire conversation pipeline runs on-device with Apple's system model. Zero network calls; nothing leaves the iPhone; the "Data Not Collected" App Store label is preserved.

### Build
- `MARKETING_VERSION` 1.6.0 → 1.7.0; `CURRENT_PROJECT_VERSION` 20 → 22 (21 = first TestFlight cut; 22 adds the every-device free-text path, the pilot invitation card, and the fallback/diagnostics fixes).
- Engine (DailyVoxTwin): structured `GroundedTwinAnswer` contract + 14-rule deterministic `AnswerAudit`, Foundation-Models pipeline with per-turn constrained citation schema, three read-only evidence tools, and the new TwinEval `--suite brain` gate (passed 2×: raw honesty 95.3%, fallback 4.7%, zero injection leaks).

## [1.6.0] — 2026-07-19

### Added
- **Semantic memory** — your Twin can find an entry by meaning, not just keywords. On-device sentence embeddings (Apple NLEmbedding, no shipped model bytes) index every entry for similarity search. Search works best with a full phrase.
- **A first learned trait** — the Twin's openness estimate now comes from a small on-device model trained on real, consented human writing, not keyword ratios. It shrinks toward a neutral prior until your diary is deep enough to speak, and it never claims more confidence than it earned in evaluation.
- **Predictions now say how sure they are** — every Twin prediction carries an honest confidence (tentative / moderate / strong), derived from how much history backs it and how strong the pattern is. No prediction pretends to be an oracle.
- **Your Day (Ambient), off by default** — DailyVox can read the kind of photos you took and the music you reached for, on-device, and turn each into a one-line note ("mostly trail photos", "reached for calm music"). Every note waits in a review-and-discard queue; nothing reaches your Twin until you keep it. Only derived labels are ever produced — your photos and audio never leave this iPhone. (v1.5.5 Ambient Signals.)
- **Spoken Words** — teach DailyVox names and uncommon words it keeps mis-hearing (a child's name, say). It listens for them on every recording, so a correction sticks instead of coming back wrong. Stays on this iPhone.
- **Sharper transcription on iOS 26** — entries transcribe with Apple's new SpeechAnalyzer where available (markedly lower word-error rate on sustained speech), with the current recognizer as the fallback on earlier iOS. Still fully on-device.

### Changed
- **iCloud sync is now off by default for new installs**, matching the "your entries live on this iPhone" promise. Existing installs that were already syncing keep syncing — nobody's data silently stops.

### Fixed
- Twin Resolution questions no longer truncate to a single line — the full question shows.
- Whole-entry sentiment now reads every paragraph, not just the first.

### Privacy
- Ambient signals (photos, music) are analyzed entirely on-device and produce only derived labels; new Photos and Media Library permissions are opt-in and off by default. The "Data Not Collected" App Store label is preserved.

### Build
- `MARKETING_VERSION` 1.5.0 → 1.6.0; `CURRENT_PROJECT_VERSION` 19 → 20.
- Engine (DailyVoxTwin): semantic memory index, embedding trait heads (bundled openness head), per-prediction confidence, prosody/voice-biomarker foundation, and new TwinEval suites (entities NER, retrieval, prosody) — all with measured, honest ceilings.

## [1.5.0] — 2026-07-04

### Added
- **Body Twin — the Twin gains a body.** With your permission, DailyVox reads five signals on this iPhone (sleep, morning HRV, resting heart rate, steps, mindful minutes) and freezes a small snapshot alongside each entry, tagged with your activity context (at rest / in motion) so a walk is never mistaken for a feeling
- **Review before your Twin learns**: every captured signal waits in a review queue — *Keep* folds it into your Twin, *Let go* deletes it. Nothing reaches the Twin without your eyes on it. This gate is the foundation every future passive signal will flow through
- **Body card** on the Twin tab: maturity (warming up → learning → ready), moments kept, and signals waiting
- **Body whisper** on the Today screen: one calm line of context before you speak ("Slept 5h 20m. Take a breath.")
- **Body & Mood insights**: honest correlations (sleep vs mood, steps vs mood) that appear only when there's enough data — patterns, never prescriptions
- **Settings → Health**: master toggle, per-signal toggles, and "Wipe all health snapshots"
- **Twin Resolution**: answer a few quick questions and see how well your Twin already knows you — "your Twin knows you N%," measured, not claimed
- **Native Liquid Glass tab bar** on iOS 26 (warm classic bar preserved on earlier iOS)

### Privacy
- Health signals stay on this iPhone: never uploaded, never in iCloud/CloudKit, excluded from device backups. They leave the device only inside your encrypted export, locked with your key
- Per-signal opt-outs filter *before* the HealthKit read — disabled signals are never queried
- The widget extension has zero health access

### Fixed
- **Widgets finally count**: the widget extension shipped without the Core Data model, so every counter (entries, streak, stars, today's entry) rendered zero forever regardless of data — the model is now bundled with the widget and all surfaces populate
- The Twin's stress-triggers answer no longer calls a data gap "actually a good sign" — an empty trigger map means the Twin needs more entries, and now it says exactly that
- The Twin tab can rest: the constellation now animates without keeping the run loop busy, honors Reduce Motion, and pauses cleanly during UI tests (screenshot runs dropped from ~17 minutes to seconds)
- Dark-theme legibility on the new Today cards

### Research
- **Join the pilot**: a new invitation in Settings links to getdailyvox.com/research — a small consented study measuring how well the Twin's estimates agree with how you see yourself. Display-only: the app still collects and transmits nothing
- Privacy policy gains an explicit Health data section

### Build
- `MARKETING_VERSION` 1.4.1 → 1.5.0
- `CURRENT_PROJECT_VERSION` 18 → 19
- HealthKit entitlement + Health/Motion usage descriptions added to the app target only
- `NSHealthUpdateUsageDescription` added (upload validation requires it whenever `requestAuthorization(toShare:read:)` is referenced, even read-only with an empty share set); the string states plainly that DailyVox never writes to Apple Health

## [1.4.1] — 2026-07-04

### Added
- **Voice-first onboarding — "Speak your first star"**: the final onboarding step invites you to record your first entry by voice; your own words become your first real star in the constellation (typing and skipping remain available)
- Optional **Name step** in onboarding so the Twin can greet you personally

### Changed
- Onboarding redesigned in the warm ivory-light style; message-step titles no longer truncate
- Rating prompt: first ask moved from entry 5 to entry 3, plus a second natural moment after your first share
- App Store listing: anchored keyword field (`mood tracker`, `digital twin`), refreshed copy, and fresh screenshots at current device resolutions

### Fixed
- Widget entry counters showing stale counts
- Star Birth Live Activity firing repeatedly after a single entry

### Build
- `MARKETING_VERSION` 1.4.0 → 1.4.1
- `CURRENT_PROJECT_VERSION` 17 → 18

## [1.4.0] — 2026-06-19

### Changed
- **Warm Look**: calm sage-and-gold palette across every screen; the Digital Twin promoted to the center of the app
- Refined recording screen and onboarding; compact audio player on entries; welcome replayable from Settings
- Polish and fixes throughout — still free, still 100% on-device

### Build
- `MARKETING_VERSION` 1.3.5 → 1.4.0
- `CURRENT_PROJECT_VERSION` 15 → 17 (build 16 was rejected in App Review for leftover HealthKit/Motion Info.plist keys with no corresponding code; both keys removed in build 17)

## [1.3.5] — 2026-05-27

### Added
- **New app icon variants**: iOS 18 dark-mode icon (golden mic on warm charcoal) and tinted (monochrome) silhouette to complement the sage-green default
- **Dynamic Island — Recording timer**: live elapsed time and waveform render in the compact pill, expanded view, and Lock Screen banner while you record. Counts up past the 42-second soft target so you can speak as long as you need
- **Dynamic Island — Star birth**: a brief celebratory Live Activity ("A new star appeared in your sky") fires the moment an entry saves, then auto-dismisses
- **Dynamic Island — Streak tracker (opt-in)**: pin your current `★ Day N` streak to the Dynamic Island and Lock Screen. Enable from Settings → Live Activities; ends automatically if the streak breaks or you toggle off
- **Constellation Lock Screen widget**: Canvas-rendered mini constellation, one star per recent entry, coloured by mood. Available as accessoryRectangular, accessoryCircular, and accessoryInline
- New `LiveActivityManager` centralises all ActivityKit lifecycle (start / throttled updates at 2 Hz / end / auth checks)
- New shared `LiveActivityAttributes.swift` defining `RecordingActivityAttributes`, `StarBirthActivityAttributes`, `StreakActivityAttributes`

### Changed
- Recording copy softened from "Speak for 42 seconds" to "42 seconds — or longer" / "as long as you need" in TodayView, DigitalTwinView, and ConstellationView. The recording timer never had a hard cap; this aligns the framing with reality
- `Info.plist` now declares `NSSupportsLiveActivities` and `NSSupportsLiveActivitiesFrequentUpdates`

### Build
- `MARKETING_VERSION` 1.3.0 → 1.3.5
- `CURRENT_PROJECT_VERSION` 14 → 15
- Widget Extension target (`DailyVoxWidgets`) added — the existing `SolynWidget/` code finally compiles into a shipping binary

## [1.3.0] — 2026-05-24

### Added
- **Constellation Metaphor**: Every journal entry becomes a star in your inner sky. The Digital Twin tab now features a real-time Canvas-based constellation visualization with mood-colored stars, connection lines, nebulae, and a central core star
- **Celestial Onboarding**: 5-page premium onboarding with star-birth animation, planet system (Mind/Heart/Voice/Graph orbiting planets), aurora insights visualization, shield constellation for privacy, and "Name your planets" intention mapping (Mercury, Venus, Mars, Jupiter, Saturn)
- **Focused Zero-State**: First-time users see a single focused screen — "What's on your mind?" with a pulsing mic button — instead of cluttered cards
- **Digital Twin Introduction**: First-time Twin tab shows a guided 4-step timeline (You speak → Stars appear → Twin learns → Always private) with an empty sky preview
- **Star Field Particles**: 60+ ambient star particles behind all onboarding pages
- **ConstellationView.swift**: New Canvas-based 60fps constellation renderer with deterministic star positioning, mood colors, and maturity scaling

### Changed
- **Ivory Theme as Default**: Warm ivory background (#FAF8F5), sage green accent (#5B7C6B), terracotta secondary (#C4956A), warm gold highlights (#D4A547)
- **SF Rounded Typography**: All headlines use `.design(.rounded)` for warmth
- **20pt Continuous Corners**: Every card uses `RoundedRectangle(cornerRadius: 20, style: .continuous)`
- **Warm Shadows**: Cards have warm shadows (`0.04 opacity, 12pt radius`)
- **Recording UI**: Warm coral timer, sage-to-gold waveform bars, ambient glow on mic button, "Speaking... tap when you're done"
- **Processing State**: "A new star is forming..." replaces generic spinner
- **First Entry Celebration**: "Your first star — your constellation has begun"
- **Tab Bar**: Record (mic.circle.fill), Journal (book.closed.fill), Insights (sparkle.magnifyingglass), Twin (star.circle.fill), Settings (gearshape.fill)
- **Themes Simplified**: 4 themes (System, Ivory, Light, Dark) replacing 8 — committed to the DailyVox identity
- **All Emojis Removed**: Every UI emoji replaced with premium SF Symbols
- **WarmBackground Gradient**: Subtle radial warm gradient on all daily-use screens (like cream-colored paper)
- **Constellation Language Throughout**: "Your inner sky", "your first star", "add a star to today's sky", "your constellation grows"

### Website
- **Full Celestial Redesign**: Dark hero with constellation Canvas, warm ivory body, sage/gold/terracotta palette, Nunito + DM Mono fonts
- **Digital Twin Vision Section**: "Your Digital Twin is the most accurate mirror of yourself that has ever existed"
- **35+ New/Rewritten Blog Posts**: Pillar pages for voice journal, AI journal, private journal, free journal queries
- **GEO Optimization**: Answer-first paragraphs, FAQPage schema, extraction-ready SVO sentences
- **Newsletter Signup**: Buttondown integration on landing page and pillar posts
- **RSS Feed**: 20-post feed for crawler discovery
- **Press Page**: Facts, story, data points for journalists
- **/facts Page**: Standalone quotable data points for LLM citation

## [1.2.1] — 2026-05-21

### Added
- **Emotional Onboarding**: New 5th onboarding page — "What brings you here?" with selectable intention cards (Track thoughts, Understand emotions, Build a habit, Remember my life, Create my Digital Twin)
- **Life Area Auto-Tagging**: Entries automatically tagged with life areas (Work, Health, Relationships, Growth, Family, Creativity) shown as colored pills in Timeline
- **Intent-Based Reminders**: Morning / Midday / Evening presets with purpose-driven descriptions ("Start your day with clarity", "Reset and reflect", "Unwind and look back") plus Custom time option
- **First Entry Celebration**: Special moment after your very first journal entry — "Your Digital Twin just learned something new about you"
- **Monthly Summaries**: Timeline section headers now show entry count and total word count per month

### Improved
- **Warmer Processing State**: Replaced generic spinner with phased messages ("Listening to your words..." → "Understanding your thoughts..." → "Your Twin is learning...") and pulsing animation
- **"Just 42 seconds" Nudge**: Welcome card and empty state now frame journaling as a 42-second commitment — because 42 is the answer to life, the universe, and everything

## [1.2.0] — 2026-05-21

### Added
- **Ask Your Twin**: Chat with your Digital Twin — ask about mood patterns, personality, journaling habits
- **Shareable Personality Cards**: Beautiful cards optimized for Instagram Stories (1080x1920) and Twitter/X (1200x675)
- **Smarter Review Prompts**: Milestone-based App Store rating requests (at 5, 15, 40 entries) with 90-day cooldown

## [1.1.0] — 2026-03-26

### Added
- **Twin Predictions**: Mood forecasting, trigger anticipation, temporal pattern detection
- **Shareable Personality Card**: Visual snapshot of your Digital Twin profile
- **Weekly Insight Cards**: Shareable summaries of your weekly emotional journey
- **Improved NLP**: Better keyword extraction with refined text processing

## [1.0.0] — 2026-03-23

### Added
- Voice journaling with fully on-device transcription (Apple Speech framework)
- Digital Twin: on-device personality model (communication style, emotional signature, knowledge graph)
- Mood tracking with automatic sentiment analysis (NLTagger)
- Smart insights and pattern detection
- Biometric security (Face ID / Touch ID)
- Photo attachments (up to 5 per entry)
- 8 themes (System, Light, Sage, Lavender, Rose, Ocean, Warm, Dark)
- Encrypted exports (PDF, JSON, Markdown, CSV, AES-256-GCM backup)
- Optional iCloud sync
- Home Screen & Lock Screen widgets
- Siri Shortcuts via AppIntents
- Journaling goals with weekly targets and milestone celebrations
- Full iPad support with adaptive layouts
