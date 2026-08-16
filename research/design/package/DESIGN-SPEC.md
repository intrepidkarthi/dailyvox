# DailyVox Android — Design Specification
v1.0 · August 2026 · derived from getdailyvox.com (iOS v1.9)

## 1. Product understanding

DailyVox is a voice-first journal with an on-device Digital Twin. The pitch that must survive the port unchanged: **speak 42 seconds, nothing leaves the phone, the Twin gets to know you.** Free forever, no account, open source, "Data Not Collected."

Twin dimensions: Mind (reflection/openness/formality), Voice (wpm/tone), Heart (valence/arousal), Graph (people/topics), Body (sleep/HRV/context, v1.5+). Twin Resolution is a measured score (41% in all mocks).

Audience: worldwide privacy-preferring users. On Android that skews mid-tier Samsung/Xiaomi far more than Pixel — which drives the capability-tier strategy in §6.

## 2. Design direction history

- **Turn 1** — three philosophies on five screens each:
  - 1a Native Android citizen: full M3 Expressive + dynamic colour. Familiar, loses the brand.
  - 1b Brand-first: cream/ink/Nunito held; Material for behaviour only.
  - 1c Night sky: M3 structure filled with ink + amber. Original recommendation.
- **Turn 2** — structural rethinks (kept as a idea bank): 2a transcript-as-interface (serif diary, Twin writes a prose portrait), 2b the-sky-is-the-app (no tabs, entries are stars, time is depth), 2c instrument (log table, gauges, NET 0 B promoted to permanent status).
- **Turn 3** — **final system (3a)**: 1b becomes the Light theme, 1c the Dark theme, one structure. All screens, plus iOS variants proving cross-platform fit.
- **Turn 4** — system surfaces: widgets, Quick Settings, Live Update, assistants, Dynamic Island.

## 3. Design tokens (system 3a)

### Colour — Light
| Token | Value |
|---|---|
| background | #FAF8F5 |
| surface (cards) | #FFFFFF + 1px border rgba(15,20,15,.09) |
| surface-variant (nav) | #F1EDE6 |
| text | #0F140F |
| text-secondary | rgba(15,20,15,.6) |
| accent (text/icons) | #8A4A20 (terracotta — amber fails contrast on cream) |
| accent-negative | #B0533A |
| positive | #4F7A3E |
| primary action | #0F140F (ink), on-primary #FAF8F5 |

### Colour — Dark
| Token | Value |
|---|---|
| background | #0F140F |
| surface (cards) | #1A211A (tonal, no borders) |
| text | #F2EFE9 |
| text-secondary | rgba(242,239,233,.6) |
| accent | #E0B15C (amber) |
| accent-negative | #C0705A |
| positive | #9CCB85 / #7FB069 |
| primary action | #E0B15C, on-primary #0F140F |

Rules: never shadows on cream (hairlines + white cards instead); amber is a Dark-only accent; **the Twin constellation screen is dark in both themes** — the sky is always night. Dynamic colour: off by default; opt-in accent only, never applied to the constellation.

### Type
- **Nunito** 700 — headlines, big numbers (screen titles 28–34px, stat values 21–26px)
- **Inter** 400/500/600 — UI and body (13.5–16px body, 1.55–1.7 line height)
- **DM Mono** 500 — data labels, timestamps, privacy facts (9.5–11px, letter-spacing .08–.14em, uppercase)
- Ship all three with the app on both platforms. No Roboto/SF fallbacks.

### Shape & layout
- Cards 22–26px radius; nav pill container 26px; buttons 14–28px; screen padding 16–24px
- Bottom nav (Android): floating pill container, active tab = tinted pill (amber .22 dark / terracotta .14 light)
- FAB: extended "Speak" — ink in Light, amber in Dark
- Motion: M3 Expressive spring specs; predictive back; the same durations mapped to UIKit springs on iOS

## 4. Screens (all in 3a, Light + Dark)

1. **Onboarding / permission** — "Nothing you say leaves this phone." Permission ledger (mic REQUIRED, Health Connect OPTIONAL, Internet NOT REQUESTED), airplane-mode proof as first-run ritual, widget priming card.
2. **Record (home)** — Day counter, resolution badge, concentric-ring mic (42s marker), airplane-mode status card, nav.
3. **Journal** — semantic search ("search what you meant"), filter chips (People/Mood/Body), entry cards with valence dot, duration, entity chips + sleep chip.
4. **Entry detail** — audio scrubber, transcript with entity underlines, "What your Twin filed" ledger (mood, people, body context, pace), Edit / Ask about this.
5. **Twin** — resolution ring (41%), glowing constellation with named stars (Sarah ×18, James, Emma, work), dotted orbits, dimension cards with progress bars (Mind/Heart/Body), forecast sparkline. Same screen both themes.
6. **Ask your Twin** — chat with 0 CALLS badge, cited answer chips ("FROM YOUR ENTRIES"), suggestion chips (kills the blank-box problem), voice input.
7. **Insights** — streak / week / vs-June stat row, "Last 30 nights" star-dot strip (brightness = valence, tonight hollow), mood curve (7-day area chart), "Patterns your Twin noticed."
8. **Settings** — Data Shield ledger (0 network calls, AES-256, biometric lock, Health Connect review queue), Light/Dark/System, export (PDF/JSON/MD/CSV), encrypted transfer.

## 5. System surfaces (turn 4)

- **Widgets**: 2×2 "Tonight's star" (hollow star fills when you speak — no guilt copy); 4×2 with 7-night dot strip + resolution. Never shows entry text (lock-screen safe).
- **Quick Settings tile**: idle "tap to speak" / amber pulsing "0:28 · recording". Records without opening the app.
- **Live Update** (Android) / **Live Activity** (iOS): status chip (star + elapsed) → notification with 42s countdown ring, "on-device · 0 bytes out", Finish action. Ring fills to 42s then counts up quietly — a shape, not a cutoff.
- **Assistants**: "Hey Google, journal with DailyVox" → lock-screen recording. Siri/App Intents: "Ask my Twin how my week was" → cited on-device answer.
- **Dynamic Island** (4 states): ① compact listening — live waveform + 42s ring around the camera; ② entity caught — a four-point star pops with the name ("Sarah ✦ filed to your graph"); ③ long-press expanded — last transcribed phrase live, valence gradient bar, 0 BYTES OUT, Finish/Discard; ④ saved — the day's star arcs into the island (~600ms matched-geometry), resolution ticks 41→42%, island settles to an amber ember. Android mirrors ④ as the Live Update collapsing into the status chip.

## 6. Capability tiers (the hard Android problem)

Gemini Nano exists only on Pixel 8+/Galaxy S24+ class devices. The privacy-first audience is mostly on phones without it.

- **Full** (Nano via AICore): conversational Twin, cited free-form answers, semantic search.
- **Standard** (everything else): all features except free-form chat; Ask becomes structured questions answered from on-device stats + quotes. Honest, still useful.
- **Never**: a cloud fallback — it would cost the only claim competitors can't copy.

Tier is disclosed once in onboarding, never nagged.

## 7. Engineering mapping (iOS → Android)

| iOS | Android |
|---|---|
| SFSpeechRecognizer / SpeechAnalyzer | ML Kit GenAI Speech Recognition (Basic: API 31+; Advanced: Pixel 10+) |
| NLTagger / NLEmbedding | MediaPipe + bundled sentence-embedding model (must ship your own — no free system NLP layer) |
| Foundation Models (3B LLM) | Gemini Nano via ML Kit Prompt / AICore (4k context, capable devices only) |
| HealthKit | Health Connect (sleep, HRV, resting HR, steps) |
| Core Data + CloudKit | Room + SQLCipher; opt-in E2E sync (not a Google account) |
| Face ID / Secure Enclave | BiometricPrompt + Keystore (StrongBox where available) |
| WidgetKit / AppIntents | Glance widgets, Quick Settings tile, App Shortcuts + Assistant |
| Live Activities / Dynamic Island | Live Updates + status-bar chip |

## 8. What iOS should adopt back

1. **The airplane-mode proof** as an onboarding step — the site's strongest argument, currently absent from the app.
2. **Live Activity / Dynamic Island recording states** (§5) — the Island is doing nothing today.
3. **Structured Ask suggestion chips** — a blank chat box is a blank page, the thing the product exists to kill.
4. **Capability honesty** — Apple Intelligence vs non-AI iPhones is the same split; surface it once, like the Android tiers.

## 9. Open items

- Real iOS screenshots were never received; mocks derive from getdailyvox.com marketing screens and the demo. Sanity-check details against the shipped app.
- Foldable/tablet layouts, Wear OS, and the tappable prototype of the theme toggle are designed-for but not yet drawn.
