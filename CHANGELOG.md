# Changelog

All notable changes to DailyVox are documented here.

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
- The Twin tab can rest: the constellation now animates without keeping the run loop busy, honors Reduce Motion, and pauses cleanly during UI tests (screenshot runs dropped from ~17 minutes to seconds)
- Dark-theme legibility on the new Today cards

### Build
- `MARKETING_VERSION` 1.4.1 → 1.5.0
- `CURRENT_PROJECT_VERSION` 18 → 19
- HealthKit entitlement + Health/Motion usage descriptions added to the app target only

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
