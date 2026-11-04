# DailyVox multilingual release plan (for approval)

Date: 2026-10-26. Status: **proposal. Nothing gets built until Karthik approves the decisions in section 1.**

This plan reconciles four read-only audits:
- Audit 1: iOS capability by language.
- Audit 2: Android capability by language.
- Audit 3: localization completeness and English-only logic.
- Audit 4: which languages give the most reach.

**Sources and refs**
- iOS: `origin/release/ios-1.13.0` @0bae6340 (MARKETING_VERSION 1.13.0).
- Android: `origin/release/android-1.2` @57790e56.
- Engine: `DailyVoxTwin` main @8cfee01. The app links it by local SPM path, so it is UNVERIFIED that this is the exact revision 1.13.0 was archived from.
- Path conventions: iOS paths are relative to `ios/solyn/`. Android paths are relative to `android/app/src/main/kotlin/com/dailyvox/app/` unless written in full. Engine paths are relative to `DailyVoxTwin/`.
- **`main` is behind both release branches.** It still shows iOS 1.12.0 (`ios/solyn.xcodeproj/project.pbxproj:456`) and Android 1.1 (`android/app/build.gradle.kts:48-49`). Every build task below must branch from the release branches, or from `main` after they merge.

Platform facts on iOS were measured with a framework probe on macOS 26.5 that uses the same OS-26 frameworks. Any value that still has to be confirmed on an iPhone is marked **UNVERIFIED**. Android on-device pack availability changes from phone to phone and is UNVERIFIED until it is probed on real handsets.

---

## 1. Decisions needed

### D1. Tier 1 languages for the next release (recommended)

| Language | iOS 1.14 | Android 1.3 | Why |
|:--|:--|:--|:--|
| **English** | yes | yes | Baseline. Every layer works. |
| **Spanish** (es-ES, es-MX, es-US; es-419 listing) | yes, finishing a partial localization | yes, new | iOS already has transcription, sentiment and names (Audit 1). Mexico is a top-5 download market (Audit 4 §2). iOS translations exist to reuse. |
| **French, German, Italian** | yes, finishing a partial localization | yes, new | The iOS UI ships in these today but covers only 62.4% of live keys (Audit 3 §1), so the work is finishing a promise already made. Android reuses the iOS copy. |
| **Portuguese (Brazil)** | yes, new | yes, new | Brazil is the #3 download market and 77.6% Android (Audit 4 §2). Transcription is on-device on both platforms: iOS SpeechTranscriber is measured, and pt-BR is in the Android Basic list. Latin script and LTR, so the cheapest new language. |
| **Hindi** | **conditional** on the iPhone probe (D2) | yes, if the handset probe passes | Largest reach of any candidate: 528M first-language speakers (Audit 4 §1). Day One and Rosebud ship it. hi-IN is in Apple's Dictation on-device list and Google's on-device Basic list (Audit 1 §1, Audit 2 §1). It ships as **interface + transcription only**, and every text-analysis feature is quietly off. |

**Not in Tier 1, and why:**
- Japanese needs a word tokenizer before word counts, search and share-card wrapping stop being wrong (Audit 3 rows 11, 13, 15).
- Tamil cannot be transcribed on iOS at all (Audit 1 §1).

### D2. The Hindi gate
Hindi ships on a platform only if a real device passes the probe on that platform:
- **iPhone:** `SFSpeechRecognizer(locale: hi-IN).supportsOnDeviceRecognition == true` after the Hindi dictation asset is installed, on iOS 26 and on iOS 17/18.
- **Android:** `checkRecognitionSupport` lists hi-IN as installed or supported on at least 2 of 3 cheap Indian handsets (Vivo, Samsung, Xiaomi).

If iOS fails, Hindi is Android-only in this release. **Approve or reject:** "Hindi ships per platform on probe pass."

### D3. Version numbers
- **iOS 1.14 = multilingual release.** This bumps the website roadmap: today v1.14 is long-horizon memory (`website/public/roadmap.html:1176`), followed by v1.15 learned emotion head, v1.15.5 Tamil/code-mixed and v1.16 trait validation (:1177-1179). Proposal: shift each of those down one slot, so memory moves to v1.15. Alternative: call this release 1.13.5 and leave the roadmap alone. I recommend 1.14, because a new language is a minor-version event and the store "What's New" will lead with it.
- **Android 1.3** (next after 1.2 / versionCode 6).

### D4. What a "supported language" includes
- **Recommended:** a language is listed only if the app can transcribe it on-device on that platform. **No UI-only languages.** For a voice-first app, a Tamil interface on an iPhone that cannot hear Tamil is a promise the product cannot keep.
- **Alternative:** ship UI-only languages for typed journaling. This is cheaper reach, but every store listing would then need a "voice not available" caveat.

### D5. Code-mixed speech (Hinglish, Tanglish)
- **Recommended:** not supported in 1.14 / 1.3, and the app says so. The user picks one speaking language. The app accepts whatever script the recogniser emits. All lexicon and keyword features stay off for a non-English entry, and also for an English entry that the language-ID step flags as mixed. No stock on-device recogniser offers a mixed mode; none is documented, but its absence is UNVERIFIED (Audit 4 §1).
- Code-mixed support stays a research track. It is the roadmap's v1.15.5 row, which must also be corrected (see D8).

### D6. Translation method
- **Recommended:** machine draft, then a mandatory native-speaker review using the checklist in section 5. **A language with no named reviewer by string freeze slips to the next release. It does not ship unreviewed.**
- **Alternative:** paid professional translation, roughly 1,000 iOS strings + 500 Android strings × 6 languages. Google Play also offers paid human translation for the listing (Audit 3 §2).

### D7. Ask your Twin outside English (iOS)
Today, in es/fr/de/it, Ask Twin is reachable but the engine's semantic leg uses English vectors on non-English text (`swift/Sources/DailyVoxTwinEngine/SemanticMemory.swift:102`; measured: an unrelated Spanish sentence ranked closer than the relevant one, Audit 1 §2). Choose one:
- **(a) Recommended:** keep Ask Twin for languages where `SystemLanguageModel.supportsLocale` is true (es, fr, de, it, pt) and ship the engine fix that picks the embedding by entry language (es/fr/de/it vectors exist; pt falls back to lexical-only). Copy says "answers draw on your entries; search is simpler outside English".
- **(b)** Gate Ask Twin to English until the engine fix is evaluated. This is a visible regression for today's es/fr/de/it users.

On Android, Ask is English templates, and its style and personality answers are made up on non-English text. Those answers are gated to English on Android regardless of this choice.

### D8. Roadmap conflicts to fix in the same release
- `ROADMAP.md:405-410` says Tamil and Kannada are "out". `roadmap.html:1178` lists Tamil end to end on iPhone at v1.15.5. Measurement supports the first statement **for iOS only** (no Apple speech API has Tamil; Audit 1 §1). The fix: make the Tamil row Android-only and keep the iOS cell honest.
- `ROADMAP.md:396` claims "NLTagger sentiment: 34". Measured sentiment covers 5 languages (en, es, fr, de, it).
- `ROADMAP.md:411-413` claims "journaling in any of the 34 has always worked". That is false: unsupported languages are transcribed with the en-US model (finding T1 below).

### D9. Fonts
- **Recommended:** accept the system fallback face for Devanagari (and later scripts) and do not bundle Noto. That keeps app size down, and Kohinoor/Noto are good faces.
- Cost: DVFont's "never fall back to SF" rule (`DVFont.swift:14-18`) is relaxed for non-Latin scripts.
- DM Mono gets a fallback chain for Cyrillic and Vietnamese only when those languages arrive (Tier 2/3).

### D10. Research pilot
The pilot's prompts and self-labels stay **English-only**. Translating them changes a pre-registered stimulus (Audit 3 row 19). The export records UI language and transcript language so mixed cohorts can be filtered.

### Tier 2 (the release after: iOS 1.15 / Android 1.4)
- **Japanese (iOS first):** Japan is 63.6% iOS. It needs the tokenizer work.
- **Korean.**
- **Indonesian:** iOS SF is on-device per the Dictation list, UNVERIFIED on a device. Android has id-ID only in Advanced mode on Pixel 10/11, so it is likely iOS-first.
- **Tamil (Android only, probe-gated):** no competitor ships it and it fits the founder story. iOS cannot transcribe it.
- **Turkish:** needs locale-aware casing (İ/ı) on both platforms.

### Tier 3 (later)
- **Android only, each probe-gated:** Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati.
- **Vietnamese:** needs the DM Mono fallback.
- **Russian:** case endings break name canonicalisation (`NameDetector.kt:101-102`).
- **Chinese (Simplified):** needs the tokenizer.
- **Arabic:** RTL sky, constellation and dial canvases. Highest UI cost.

---

## 2. Capability matrix

Legend:
- **ON**: works today, or after the listed fix.
- **GATE**: the feature must be switched off, and stay quiet, for this language.
- **OUT**: the language is not offered on this platform.
- **UNV**: UNVERIFIED and needs a device probe.

The table shows the state after the Phase B fixes. "Today" bugs are called out in the notes.

### iOS (1.14)

| Language | Transcription (on-device) | Sentiment / mood | Names | Search | Ask Twin | Fonts |
|:--|:--|:--|:--|:--|:--|:--|
| English | ON: SpeechTranscriber (iOS 26), SF on-device (17-25) | ON | ON | ON (hybrid) | ON | Nunito/Inter/DM Mono |
| Spanish / French / German / Italian | ON: SpeechTranscriber + SF | Sentiment ON (NLTagger measured). Suggested mood GATE: English lexicon (`SuggestedMood.swift:174-177`) | ON (`.nameType` measured) | Lexical ON. Semantic ON only after the engine per-language embedding fix (B-E1), otherwise semantic GATE | D7 | Full Latin |
| Portuguese (BR) | ON: SpeechTranscriber + SF | GATE: NLTagger returns "Other" | GATE: no `.nameType` | Lexical ON (stopword list needed), semantic GATE (no pt embedding) | D7 (FM supportsLocale true) | Full Latin |
| Hindi | SF on-device if probed (UNV). Not in SpeechTranscriber (`AssetInventory .unsupported`); T2 adds DictationTranscriber | GATE | GATE (quiet already: caseless) | Lexical only. Needs a Unicode tokenizer (Devanagari ok with `\p{L}\p{M}`); semantic GATE | GATE (`supportsLocale(hi)` false) | System fallback (Kohinoor/Noto Devanagari) |
| Tamil and other Indic except Hindi | **OUT.** Not in SF (63), SpeechTranscriber (30) or Dictation (54) | n/a | n/a | n/a | n/a | n/a |

### Android (1.3)

| Language | Transcription (on-device) | Sentiment / mood | Names | Search | Ask Twin | Fonts |
|:--|:--|:--|:--|:--|:--|:--|
| English | ON (`createOnDeviceSpeechRecognizer`) | ON (VADER, r=+0.663) | PARTIAL (depends on recogniser casing) | ON | ON (templates) | bundled |
| Spanish / French / Italian | ON if the pack is present (Basic beta; es-419 tags UNV) | **GATE**: today VADER false friends give "joy" on sad es/it entries | ON, but the grounded question is GATED until a localised sensitive list exists | ON after the Unicode tokenizer fix (accents fragment today) | Retrieval ON, style/personality answers GATE | bundled |
| German | ON if pack present | **GATE** ("die"/"war" score −2.9) | **GATE**: every noun is capitalised, so nouns become "people" | ON after tokenizer fix | style GATE, people GATE | bundled |
| Portuguese (BR) | ON if pack present (Basic beta) | GATE | ON, grounded question GATE | ON after tokenizer fix | style GATE | bundled |
| Hindi | ON if pack present (Basic beta) | GATE: today shows "fairly even" / "remarkably balanced" | GATE, and fix the CasingCheck copy | ON after Unicode tokenizer fix (today a Devanagari query **returns the whole journal**) | style GATE | system Noto |
| Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati | Tier 2/3, offered only where `checkRecognitionSupport` lists the tag (UNV; not in Google's published on-device lists) | GATE | GATE | ON after tokenizer fix | GATE | system Noto |

Full per-language rows for all 22 candidates, including Tier 2/3, are in Audits 1 and 2. The table above covers what this release touches.

---

## 3. What "supported" means, honestly

**Tier 1 language on a platform** means four things:
1. The whole interface is in that language. That covers permission prompts, widgets, Live Activities, notifications and share cards, with no half-English screens.
2. The app hears you in that language on-device. The audio never leaves the phone. Apple's or Google's speech model may be downloaded once.
3. Every feature that can read that language is on.
4. Every feature that cannot read it is **off and silent**. It never shows a guess.

**Never:** a feature that can't read the language outputs a neutral reading as if it were a finding. Examples are "fairly even", "remarkably balanced", "calm mind" and "Warmest month".

### User-facing copy (English source, to be translated)
- **Settings, "Language you speak":** "DailyVox listens in one language at a time. Pick the one you'll speak tonight. This can differ from the app's language."
- **When no on-device model exists for the chosen language:** "Your phone can't transcribe {language} on-device yet. Your recording is saved, and you can transcribe it later if a model becomes available." Never fall back to English.
- **When a model must be downloaded:** "{Language} needs a one-time download from {Apple/Google}. After that, everything you say stays on this phone."
- **Insights footer for a gated language:** "Some reflections read English only for now. In {language}, DailyVox keeps your words, your stars and your search, and stays quiet where it can't read well yet."
- **Store listing line** (both stores, in each Tier 1 language): "Speak in {language}. Transcribed on your phone. Mood reading and Twin insights are richest in English and are being extended."
- **Code-mixed (FAQ):** "Mixing languages in one entry, like Hinglish, isn't supported yet. Pick the language you'll mostly speak. Your entry is saved either way."

---

## 4. Engineering work breakdown

Sizes: **S** ≤ ½ day, **M** 1-2 days, **L** 3-5 days. Each bullet is one PR unless it is marked as grouped.

### Phase A0: English-only logic fixes (ship first, independent of new languages)
These fix live bugs for today's non-English users: iOS es/fr/de/it, and anyone typing or importing non-English text on Android.

| # | Platform | Task | Anchor | Size |
|:--|:--|:--|:--|:--|
| A0-1 | iOS | **Same-language-only transcription.** Remove the en-US fallback unless `Locale.current.language.languageCode == "en"`. Throw "no on-device model" instead (fixes T1). | `SpeechTranscriber.swift:85-90`, `:146-168` (candidate list `:153-159`), comment `:140-143` | S |
| A0-2 | Android | **Remove `langs.first()`.** Return ERROR_LANGUAGE_UNAVAILABLE (13) and offer the download. | `audio/SpeechCapture.kt:341-349` | S |
| A0-3 | Android | **Nullable valence.** Make valence null, not 0, when no lexicon token matched or the language is unsupported. Tone and drift then return null. Year One "Warmest month" shows "—" unless valence varies. | `system/Reflection.kt:79-96`, `data/Repo.kt:41,95,133`, `system/Shareables.kt:545-555` | M |
| A0-4 | Android | **Search returns nothing on an empty term set**, never the whole journal. | `data/Repo.kt:28-31` | S |
| A0-5 | Android | **CasingCheck** returns quiet when the dominant script is caseless. | `system/CasingCheck.kt:79-96`, copy `ui/screens/TwinScreen.kt:321-324` | S |
| A0-6 | iOS | **EntryReflection.make** returns nil for non-English transcripts. Stops "calm mind" on grief entries. | App `EntryReflection.swift:34-35`; engine `LocalAIEngine.swift:476-490` | S |
| A0-7 | both | **Add `\p{M}` to name lookarounds.** | `EntityMatch.swift:47-49`; `system/Reflection.kt:129` | S |
| A0-8 | iOS | Port Android's unspaced-script skip to EarlySignals repeats. Count words with `NLTokenizer`. | `EarlySignals.swift:172-217` | S |
| A0-9 | Android | Share-card text wrap uses `BreakIterator.getLineInstance` instead of splitting on spaces. | `system/ShareCard.kt:90-100` | S |
| A0-10 | both | **Grounded daily question gated to English** until a localised sensitive list exists. Today a Spanish bereavement entry can be asked about. | iOS `DailyQuestion.swift:201-208, 294-300`; Android `system/DailyQuestion.kt:89-97, 192-194` | S |

### Phase B: Infrastructure

| # | Platform | Task | Anchor | Size |
|:--|:--|:--|:--|:--|
| B-1 | iOS | **`transcriptLocale` attribute on Entry** (Core Data lightweight migration). Set it from the recogniser actually used. Backfill existing entries with `NLLanguageRecognizer` on first launch. | `solyn.xcdatamodeld`; set in `SpeechTranscriber.swift:61-76`, `LiveTranscriber.swift:98,182` | M |
| B-2 | Android | **`language` column on Entry** (Room migration). Take it from the recogniser tag. For typed or imported text use `TextClassifier.detectLanguage` (API 29, no new dependency). | `data/Entry.kt:18-58`, `data/Repo.kt:41,95,133` | M |
| B-3 | engine (Swift + Kotlin) | **`LanguageGate.supports(feature, locale)`** capability table, defaulting to English-only. Wire up the unused `languageRecognizer`. | Engine `LocalAIEngine.swift:213,244`; Kotlin engine new file | M |
| B-4 | iOS | **Apply the gate** to SuggestedMood, EntryReflection, DailyQuestion grounded, EarlySignals repeats, ShareableInsightGenerator (whole generator → English, or delete the legacy surface), recap topics, and LiveTranscriber valence and name blink. Also make the name blink match whole words. | `SuggestedMood.swift:40-107`, `DailyQuestion.swift:294-300`, `EarlySignals.swift:172`, `ShareableInsightGenerator.swift:166-579`, `Resurfacing.swift:315-358`, `LiveTranscriber.swift:318-348` | L |
| B-5 | Android | **Apply the gate** to MoodSuggestion, Reflection tone and drift, Insights (valence and person findings), TwinFacts style and personality, NameDetector (off for German and caseless scripts), EarlySignals stopwords, Year One. | `system/MoodSuggestion.kt:94-117`, `system/Reflection.kt`, engine `Insights.kt:60-125`, `TwinFacts.kt:183-217,275`, `NameDetector.kt:44-133`, `system/EarlySignals.kt:214` | L |
| B-6 | iOS | **"Language you speak" picker**, separate from UI language. List the locales `SpeechTranscriber.supportedLocales` plus those where `SFSpeechRecognizer.supportsOnDeviceRecognition` is true. Install the model through AssetInventory. VoiceSearch uses the same resolver. | `SpeechTranscriber.swift:85-106`, `VoiceSearchManager.swift:29,118` | M |
| B-7 | iOS | **DictationTranscriber route on iOS 26** for hi (and later id/tr/vi/ru/ar) instead of hopping to legacy SF (T2). | `SpeechTranscriber.swift:61-76` | M |
| B-8 | Android | **Speaking-language picker.** Read `getSupportedOnDeviceLanguages` as well as installed. `triggerModelDownload` for the chosen tag. Re-probe when the locale changes (drop the forever `PROBED_KEY`). FileTranscriber gets the stored tag. Match `cmn-Hans-CN` against `zh-CN`. | `audio/SpeechCapture.kt:113-156, 277, 318-349`; `FileTranscriber.kt:140`; `ui/screens/EntryDetailScreen.kt:620` | L |
| B-9 | Android | **Unicode tokenizer** for Retrieval and Repo search: letters plus combining marks, NFC, locale-aware lowercase. Fixes "mamá" → "mam". | engine `Retrieval.kt:80-83`; `data/Repo.kt:28-31` | M |
| B-10 | engine (Swift) | **B-E1: per-language sentence embedding.** Choose `NLEmbedding.sentenceEmbedding(for:)` by entry language (en/es/fr/de/it); otherwise lexical only. Add per-language stopwords. Never mix vectors across languages (MultilingualSuite.swift:27-33). Add an eval in MultilingualSuite before claiming search. | `SemanticMemory.swift:102, 282-286`; `TraitHead.swift:207` (TraitHead gated to English); `AnswerAudit.swift:231` | L |
| B-11 | engine (Swift) | **Ask Twin locale check:** `SystemLanguageModel.default.supportsLocale(_:)` in availability. Prompt dates use the user's locale, not en_US_POSIX. | `FoundationTwinChat.swift:50-60`; `TwinPersonaPrompt.swift:130`, `RetrievalAnswerComposer.swift:51`, `TwinChatTools.swift:90` | M |
| B-12 | iOS | **Locale formatting.** Replace 17 fixed `dateFormat` strings with `setLocalizedDateFormatFromTemplate` or `.formatted()`. Remove en_US_POSIX from share cards. Audit 29 `String(format:)` sites. Use locale quote delimiters. | `TodayView.swift:1578`, `EntryDetailView.swift:871`, `BackupService.swift:345-445`, `Shareables.swift:390`, `ResurfaceCards.swift:103,194` | M |
| B-13 | Android | **Locale formatting.** Remove `Locale.US`; use `DateTimeFormatter.ofLocalizedDate`; use locale-aware `uppercase()`. Read-aloud follows the entry language. | `system/Shareables.kt:244,552-553`; `ui/components/Common.kt:90`; `system/Speaker.kt:23` | S |
| B-14 | iOS | **String plumbing.** Add `InfoPlist.xcstrings` (8 usage strings, `Info.plist:9-24`) and resolve the duplicate `INFOPLIST_KEY_NS*` (pbxproj:642-643, 686-687). Give the widget target its own catalog. `Mood.displayName` → `String(localized:)` (`Mood.swift:16-27`). Move the error copy (`SpeechTranscriber.swift:36-47`, `VoiceSearchManager.swift:87`) and the ~949 bypassing literals into the catalog, worst files first. Delete 29 stale keys. Add pt-BR and hi to `knownRegions` (pbxproj:323-330). | as listed | L (split into ~4 PRs by file group) |
| B-15 | Android | **String extraction.** Move 75 `Text("…")` and about 440 literals to `strings.xml`, starting with Shareables.kt, OnboardingScreen.kt, SettingsScreen.kt, EntryDetailScreen.kt and SpeechCapture.kt:601-698. Leave DummyData.kt alone. Turn on `androidResources { generateLocaleConfig = true }` with `res/resources.properties`. | as listed | L (split into ~4 PRs) |
| B-16 | both | **RTL and font hygiene ahead of time:** `chevron.right` → `chevron.forward` (8 sites, e.g. `BodyTwinCard.swift:64`); verify the Android "‹" glyph. Relax the DVFont fallback rule for non-Latin scripts. | `DVFont.swift:14-18, 81-90` | S |
| B-17 | both | **On-device probe screen** in debug builds (Audit 1 `probe.swift`, plus an Android `checkRecognitionSupport` dump). Run it on iPhone (iOS 26 and 17/18, with and without dictation assets) and 3 Indian Android handsets. **This gates D2.** | debug menu | S |

### Phase C: Translations

| # | Platform | Task | Size |
|:--|:--|:--|:--|
| C-1 | iOS | Finish de/es/fr/it: 198 live untranslated keys + B-14 newly extracted strings + InfoPlist + widget catalog. Include all 28 daily questions (`DailyQuestion.swift:88-147`). | M per language with review |
| C-2 | iOS | Add pt-BR and hi catalogs. Plural variations for hi rather than relying on `inflect: true` (`ResurfaceCards.swift:162,168`; Hindi inflection UNVERIFIED). | M per language |
| C-3 | Android | `values-es`, `-fr`, `-de`, `-it`, `-pt-rBR`, `-hi`. Reuse iOS translations where the source matches. Cover each language's plural classes for the 15 `<plurals>`. | M per language |
| C-4 | both | Native review per section 5. Screenshot pass per language at default and largest Dynamic Type / font scale. Check German length under `lineLimit(1)`, and Devanagari stacks under `minimumScaleFactor`. | S per language per platform |

### Phase D: Store and web

| # | Task | Anchor | Size |
|:--|:--|:--|:--|
| D-1 | App Store localizations for es-ES, es-MX, fr-FR, de-DE, it, pt-BR, and hi if D2 passes. Fix the stale "1.11.0 (build 44)" reviewer note. | `ios/AppStore/metadata.json:15` | M |
| D-2 | Play listings for es-ES, es-419, fr-FR, de-DE, it-IT, pt-BR and hi-IN. Localized screenshots. | `android/playstore/STORE_LISTING.md`, `RELEASE_NOTES_1.2.md:3` | M |
| D-3 | Roadmap fixes (D3, D8): renumber the version table and correct the Tamil row and the ROADMAP.md claims. | `website/public/roadmap.html:1176-1179, 1236-1237`; `ROADMAP.md:391-413` | S |
| D-4 | Language-support page plus FAQ entries using the section 3 copy. Per-language landing pages are a later SEO decision, not this release. | website | M |
| D-5 | Privacy copy: mention the one-time model download from Apple/Google (T3, `SpeechTranscriber.swift:99-100`). | privacy page | S |

**Order:** A0 (can ship as 1.13.x / 1.2.x) → B-17 probe → B-1/2/3 → B-4/5/6/8/9 → B-14/15 → C → B-10/11 (engine, may trail into Tier 2 if the eval fails; Ask Twin then follows D7(b)) → D.

---

## 5. Translation approach and native-review checklist

**Approach**
1. Freeze English source strings after B-14/B-15 land. Add a translator comment to every key: where it shows, the character budget, and what the placeholder holds.
2. Claude drafts translations into the catalogs.
3. A **native-speaker reviewer** (one per language, named before freeze) reviews the drafts in context from screenshots, not from a spreadsheet.
4. Fixes go back into the catalogs, then there is a second screenshot pass.

Candidate reviewers to recruit: pilot participants, the professor's lab network (`project_academic_collaboration`), and Indian Hindi-speaking users from the Play beta. **Nothing ships unreviewed (D6).**

**Checklist (reviewer signs per language)**
- [ ] **Tone:** warm, calm, second person, never clinical or salesy. Choose the register deliberately: tú vs usted, tu vs vous, du vs Sie, você, aap vs tum. Recommended: informal everywhere except Hindi (aap).
- [ ] **Gender:** no gendered agreement about the user, since we don't know their gender. Rephrase to neutral forms. Templates with names ("How are things with %@?") must stay pronoun-free (`DailyQuestion.swift:356-378`).
- [ ] **Script:** Hindi in Devanagari, not romanised. Brand names (DailyVox, Twin) stay Latin unless the reviewer objects.
- [ ] **Numerals:** Western digits by default. Note whether Devanagari digits are expected; we follow the system locale.
- [ ] **Dates and times:** none hand-built in strings. Check that rendered dates follow locale order (B-12/13).
- [ ] **Plurals:** every count string is right at 0, 1, 2, 5 and 21 in that language.
- [ ] **The "42 seconds" ritual:** keep the number 42 literal. Keep "soft target, not a cutoff" ("or as long as you need") (`ConstellationView.swift:450`, `EmptyStateView.swift:127`, Android `ui/screens/SpeakScreen.kt:467`). Never render it as "at least" or "maximum". Seconds use the local unit word.
- [ ] **Stars and sky metaphor:** "star", "sky" and "constellation" read naturally and are not astrology terms.
- [ ] **Safety-adjacent copy** (grief, sensitive prompts, daily questions): nothing that pries or presumes.
- [ ] **Truncation:** no clipped text at largest font size, and German in particular.
- [ ] **Permission prompts:** clear about on-device processing.
- [ ] **Store listing:** claims match section 3 exactly. No "AI understands your feelings in Hindi".

---

## 6. Risks and what we will NOT claim

### Top risks
1. **The silent English fallback is live today** on both platforms (`SpeechTranscriber.swift:85-90,153-159`; `SpeechCapture.kt:348`). If a new language ships before A0-1/A0-2, users of that language get confident English gibberish saved as their entry and fed to the Twin. **A0 is a hard prerequisite.**
2. **Hindi on-device availability is unproven** on iPhone (`supportsOnDeviceRecognition` was false on the probe Mac without the asset) and on budget Android handsets. Mitigation: the D2 probe gate. Hindi may become Android-only.
3. **Translation quality with one founder and no in-house speakers.** A tone-deaf or gendered translation in an emotional app does more harm than English. Mitigation: no named reviewer, no ship (D6).
4. The English-only analysis already produces wrong output for es/it/de on Android (the "joy" suggestion on a sad entry; German nouns read as people). Gating it makes the app *quieter* in those languages, which could read as a downgrade. The copy in section 3 has to carry that honestly.
5. Engine embedding work (B-10) may fail its eval. Then semantic search stays English-only and D7 falls back to (b).
6. Scope: B-14/B-15 string extraction is the largest single cost (about 950 + 440 literals) and is easy to underestimate.

### What we will NOT claim
- No Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam or Gujarati on iOS. No iOS listing in those languages.
- No code-mixed (Hinglish/Tanglish) support.
- No mood reading, sentiment, personality traits or Twin "style" insights in pt or hi, and no mood suggestion outside English.
- No "semantic search in N languages" until B-10's eval passes for that language.
- No "works offline in every language". Models may need a one-time download, and availability depends on the phone.
- No "34 languages" anywhere (ROADMAP.md:396, :411-413 are corrected).
- No claim that the research pilot runs in any language other than English.
