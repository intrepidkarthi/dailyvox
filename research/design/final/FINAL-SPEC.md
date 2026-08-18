# DailyVox Android — Final Design Specification
**System: "Evergreen & Gold Hour"** · v2.0 · August 2026 · handoff-ready
Companion visual: `prototype/DailyVox Final System.dc.html` (sections A–D) and `screenshots/final/`.

## 0. One-paragraph summary
One design system, two themes. Day = cream paper + forest green. Night = navy sky + gold. The Twin screen is always night. Colour grammar is strict: **green acts, gold rewards, navy is the sky, cream is paper** — nothing else gets colour. Structure and motion are Material 3 Expressive on Android, mapped to UIKit springs on iOS.

## 1. Tokens

### Colour
| Token | Day | Night |
|---|---|---|
| background | #F7F3EA | #101B2D |
| surface (card) | #FFFFFF, shadow 0 2 10 rgba(30,42,38,.06) | #1C2A42, no border |
| text primary | #1E2A26 | #F1EDE2 |
| text secondary | rgba(30,42,38,.6) | rgba(241,237,226,.6) |
| action (green) | #2E5B44 on-action #F7F3EA | #D9A441 on-action #101B2D (gold is the actor at night) |
| positive | #4A7C59 | #8FBF77 |
| gold accent | #D9A441 · tint #F3E7CD · text-on-cream #8A6A1F | #D9A441 · tint rgba(217,164,65,.16) · text #EDCB86 |
| green tint | #E4EDE4 (chips) | — |
| info-blue star | #9DC1E4 (constellation only) | same |

Rules:
- Green = actions (record, send, save, active-day nav). Gold = made things (stars, streaks, insights, active-night nav). Never swap.
- No pure black, no pure white text. No dynamic (wallpaper) colour — opt-in later at most.
- Twin/constellation screen uses night tokens in BOTH themes.
- Contrast: gold on cream is decorative only; gold TEXT on cream uses #8A6A1F (AA).

### Type (bundle all three; never fall back to Roboto/SF)
| Role | Font | Size/weight |
|---|---|---|
| Display / screen titles | Nunito 800 | 28–30px, line 1.1–1.18 |
| Card display numbers | Nunito 800 | 20–38px |
| Body / UI | Inter 400/500/600 | 12–13.5px body (scale ×1.15 for production dp), line 1.5–1.7 |
| Data labels / timestamps / privacy facts | DM Mono 500 | 9.5–10px, tracking .12em, uppercase |
| Buttons / nav / chips | Nunito 700–800 | 10.5–14px |

(The mock px values are at 360×780 preview scale; production = same ratios on 412dp base grid. Minimum hit target 48dp.)

### Shape
- Cards 20–22 radius · nav bar container 24, active pill 17–18 · buttons 15–19 · input pill 22 · chips 13 · mic button full circle.
- Day cards: white + soft shadow. Night cards: tonal #1C2A42, flat.

### Spacing
- Screen padding 16 (cards) / 24 (titles) · card padding 14–17 · stack gap 10 · chip gap 6–7.

## 2. Screens (see visual, sections B & C)
1. **Onboarding (B1)** — headline "Nothing you say leaves this phone.", permission ledger (Mic REQUIRED / Health Connect OPTIONAL / Internet NOT REQUESTED), navy airplane-mode proof card, single green CTA "Speak your first star".
2. **Record / Home (B2, C1)** — greeting + date, streak & star chips, "How was your day, really?", circular mic (green day / gold night) inside a **42-dot tick ring** (one dot per second of the ritual; ring drifts at 120s/rev, one small gold star orbits at 16s/rev — solar-system idle). Once today's entry exists, a **Today card** appears under the mic: time, one-line summary, valence, play chip.
   - **Recording state (B2b)**: full-screen counter dial — 42 ticks light up gold one per second (elapsed arc over faint dots), big Nunito elapsed time in centre, radial glow breathing (2.4s), two orbiting stars (12s and reverse 22s — the solar system speeds up while you speak), live waveform bars (staggered 1s scaleY loop), last transcribed phrase, entity-caught chip blink, and controls: Discard ✕ · **red Stop & keep** (76dp) · Pause. Status bar shows the recording chip.
3. **Journal (B3, C3)** — semantic search field ("Describe it — search what you meant"), filter chips (All/People/Mood/Body), **Play today pill** in the header (queues all of today's recordings back-to-back with total duration), entry cards (DM Mono meta, 2-line preview, entity chips incl. sleep chip, gold ✦ = starred), Twin-noticed gold tint card.
4. **Entry detail (B4)** — back + date header, navy audio player (gold play, waveform, elapsed), transcript with gold-underlined entities, "What your Twin filed ✦" ledger (mood/places/body/pace), Edit + Ask-about-this.
5. **Twin (C2)** — always night, and alive: dashed orbits counter-rotate (80s / 130s), stars twinkle on staggered 3–4s cycles, centre glow breathes (5s), a gold comet orbits the outer ring (18s) and a small blue body the inner (30s reverse). New entries fly in as stars on open. Star count badge, named stars, Twin-summary card, dimension stats.
6. **Ask Your Twin (B5)** — "Answers with receipts · 0 network calls", user bubble green, answer card with citation chips (AUG 3 · 57% pattern) + "3 CITED ✦", suggestion chips (outlined green), input pill with green send-mic.
7. **Insights (B6)** — streak card (giant gold number + 7-day gold bar strip + LONGEST/MONTH/TOTAL), mood curve card (gold line + area, +0.4 badge), "Your Twin noticed ✦" list with tinted icon squares. Lives as a segment of the Twin tab.
8. **Settings (C4)** — Data Shield ledger (0 network calls EVER, AES-256, biometric toggle, Health Connect review queue), Theme = Day / Night / **Sunset** (default: follows the real sun), Backup & export (PDF/JSON/MD/CSV, import, encrypted phone-to-phone), version/entries footer.

## 3. Navigation
- 4 tabs: **Speak · Journal · Twin · Ask**. Insights is a segment inside Twin.
- Floating pill bar, inset 18, container white (day) / #1C2A42 (night); active tab = filled pill (green day / gold night), inactive = 55–60% text. Labels always visible.
- Android: predictive back everywhere; back-swipe previews the underlying screen. iOS: same visual bar, edge-swipe back.

## 4. Motion (M3 Expressive springs; iOS maps to UIKit springs)
| Moment | Spec |
|---|---|
| Tab switch | active pill morphs (spring, damping .8, ~350ms); content cross-fades 150ms |
| Record start | mic scales 1→1.08 spring; 42-dot ring morphs into the full-screen dial; orbiting star accelerates 16s→12s/rev; status-bar chip appears |
| Recording idle-life | glow pulse 2.4s · waveform bars staggered 1s · tick lights 1/s · entity chip blink 2.4s |
| Twin sky ambient | orbits 80s/130s counter-rotation · twinkles 3–4s staggered · comet 18s · all paused under reduced-motion |
| Star saved | star flies from screen centre into status chip / Dynamic Island, 600ms matched-geometry, then chip glows gold 60s |
| Day→night (Sunset theme) | 800ms cross-fade at local sunset, next app-open |
| Cards on scroll-in | 12px rise + fade, 250ms, stagger 40ms (respect reduced-motion) |
| Predictive back | M3 default; screens scale to .92 |

## 5. System surfaces (section D)
- **Widget 4×2** (day + night variants): mic circle, "Day N · speak tonight", last-7-nights star dots (tonight hollow), sky count. Never entry text. 2×2 = mic + hollow star only.
- **Quick Settings tile**: idle "tap to speak" / recording green with elapsed. Records without opening the app.
- **Live Update / Live Activity**: status chip (gold dot + elapsed) → expanded card: 42s gold ring, "Listening · on-device · 0 bytes out", gold Finish.
- **Dynamic Island (final file, section E)** — four states: ① compact: live waveform + 42s ring around the camera; ② entity caught: four-point star pops with the name ("Sarah ✦ filed to your sky", ~0.5s); ③ long-press expanded: live transcript line, valence gradient bar, 0 BYTES OUT, Finish ✦ / Discard; ④ saved: star arcs into the island (600ms matched-geometry), count ticks 140→141, gold ember glow for 60s. Android mirrors ①–④ on the Live Update status chip.
- **Assistant**: "journal with DailyVox" intent → lock-screen recording; "ask my Twin…" → cited on-device answer.

## 6. Capability tiers (Android)
- **Full** (Gemini Nano via AICore — Pixel 8+/S24+ class): conversational Ask, free-form cited answers.
- **Standard** (everything else): Ask = suggestion-chip questions answered from on-device stats + quoted entries (the B5 layout unchanged; only free-typed questions gated).
- **Never** a cloud fallback. Tier disclosed once in onboarding.

## 7. Engineering mapping
| Capability | Android | iOS |
|---|---|---|
| Transcription | ML Kit GenAI Speech Recognition | SFSpeechRecognizer / SpeechAnalyzer |
| Entities/valence | MediaPipe + bundled embedding model | NLTagger / NLEmbedding |
| Twin LLM | Gemini Nano (AICore), tiered | Foundation Models |
| Body data | Health Connect | HealthKit |
| Storage | Room + SQLCipher | Core Data (encrypted) |
| Lock | BiometricPrompt + Keystore/StrongBox | Face ID + Secure Enclave |
| Widgets/tiles | Glance + QS tile + App Shortcuts | WidgetKit + AppIntents |
| Recording status | Live Updates + status chip | Live Activity + Dynamic Island |

## 8. Acceptance criteria (design QA)
1. Airplane mode on: every flow works; Data Shield still shows 0 calls.
2. No Roboto anywhere (inspect with Layout Inspector); Nunito/Inter/DM Mono only.
3. Green never appears as decoration; gold never as an action — except night-theme primary action, which is gold by rule.
4. Twin screen renders night tokens under the day theme.
5. Widget shows no entry text in any state.
6. All hit targets ≥48dp; text contrast AA (gold text on cream = #8A6A1F).
7. Recording survives app kill via foreground service; Live Update chip persists.
8. Reduced-motion: replace flights/springs with fades; pause ambient sky/orbit loops.
9. No emoji anywhere in the product. Icons are geometric glyphs or vector shapes (star ✦, triangle ▲, plus, rings) in the token palette.

## 9. Out of scope for v1 (designed-for, not drawn)
Foldable two-pane (journal list + detail), Wear OS 1-tap record tile, per-entry photo attachments, dynamic-colour opt-in.
