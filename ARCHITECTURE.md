# DailyVox Architecture

This document describes the high-level architecture of DailyVox to help contributors understand the codebase.

## Data Flow

```
Microphone → AudioRecorder (AAC 44.1kHz)              ── app
    ↓
SpeechTranscriber (SFSpeechRecognizer, on-device)     ── app
    ↓
─────────────── engine boundary ───────────────
DigitalTwinEngine.processEntry(…)                     ── DailyVoxTwinEngine package
  LocalAIEngine (NLTagger) · InsightsEngine
  personality models · entity graph · semantic memory
─────────────── engine boundary ───────────────
    ↓
TwinStateStore (host-supplied persistence)            ── app
    ↓
Persistence (Core Data + optional CloudKit)           ── app
    ↓
UI (SwiftUI, WidgetKit, AppIntents)                   ── app
```

## The engine boundary

**The Digital Twin engine is not in this repository.** It is a separate Swift
package, `DailyVoxTwinEngine`, consumed through a local Swift Package Manager
reference (`project.pbxproj` → `relativePath = ../DailyVoxTwin`). 25 files under
`ios/solyn/` reach it with `import DailyVoxTwinEngine`; none of them contain
engine code, and `.githooks/pre-commit` blocks engine sources from being added
here.

This is the seam that matters for anyone reading the codebase, so it is worth
stating precisely what crosses it.

**Into the engine** — the app hands over text and metadata, never storage:

| Entry point | Purpose |
|---|---|
| `processEntry(text:mood:date:duration:now:prosody:entryId:)` | fold one entry into every model |
| `reprocessEditedEntry(oldText:newText:…)` | re-fold after an edit, re-keying renamed entities |
| `forgetEntry(_:)` | detach a deleted entry from the mention index |
| `LocalAIEngine.analyze(text:)` | per-entry NLP read (people, places, topics, sentiment) |

**Out of the engine** — derived state and retrieval:
`graphRetrieval()` for entity traversal, `SemanticMemoryIndex` for meaning
search, plus the published personality models the Twin views render.

**Persistence is injected, not assumed.** The engine never touches Core Data or
the filesystem. The host supplies a `TwinStateStore`:

```swift
protocol TwinStateStore {
    func loadState(forKey key: String) -> Data?
    func saveState(_ data: Data, forKey key: String)
}
```

Three stores are wired at launch in `solynApp.swift`, and which one a model gets
is a privacy decision, not a technical one:

- `CoreDataTwinStateStore` — the CloudKit-synced Twin blob
- `FileBodyTwinStateStore` — Body Twin state, local-only and backup-excluded (guideline 2.5.1)
- `LocalFileTwinStateStore` — the semantic index and entity mention index, per-entry data that must never enter the synced blob

Because storage is injected and the models are plain Swift, the engine's
portability is bounded by its *Apple framework* dependencies (`NaturalLanguage`
for embeddings, NER and sentiment; `CoreML` for trait heads) rather than by its
architecture. Those dependencies are concentrated in a small number of call
sites; the graph, retrieval and scoring code is Foundation-only.

## Module Overview

App source files are in `ios/solyn/` (Swift) and `android/app/src/main/kotlin/`
(Kotlin). Engine source lives in the separate package described above.

### The engine boundary applies to BOTH platforms

> **Anything that computes something about the user is private.
> Anything that plumbs a platform API is public.**

No exceptions, including for algorithms implementing published research. A
boundary with exceptions requires a judgement call per file, and drifts.

| | iOS | Android |
|---|---|---|
| Private engine | `Sources/DailyVoxTwinEngine` (SPM) | `kotlin/engine` (Gradle module) |
| NER | `HeuristicNER.swift` | `NameDetector.kt` |
| Prosody contract + DSP | `ProsodyFeatures.swift` | `Prosody.kt` |
| Graph | `EntityGraph.swift` | `EntityGraph.kt` |
| Sentiment | `NLTagger` (Apple's, not ours) | `Sentiment.kt` |
| Public app holds | UI, AVFoundation capture, Core Data | UI, MediaCodec decode, Room, assets |

#### A note on the history of this repository

`NameDetector.kt` and `Sentiment.kt` were committed to this public repository
before the boundary above was applied, and they remain in its **git history**.

That is a deliberate, recorded decision, not an oversight. Scrubbing history
requires a force-push that invalidates every existing clone and every commit
reference, and the practical exposure is low: both files are ports whose method
is already described in public write-ups, and the current HEAD is correct.

**Do not rewrite this history to "fix" it.** If the exposure ever needs closing,
the answer is a fresh repository, not a rewritten one.

### Two apps, one set of contracts

The Android app is a native port, not a wrapper, and it is deliberately NOT a
line-by-line translation. Where Apple provides a framework, iOS calls it; where
Android provides nothing equivalent, the Android app carries its own
implementation and that implementation was **measured against the Apple one**
before it shipped.

| Capability | iOS | Android | How the substitution was justified |
|---|---|---|---|
| Transcription | `SFSpeechRecognizer` / `SpeechAnalyzer` | `createOnDeviceSpeechRecognizer` | Fails rather than falling back to a network; the error is surfaced with the Settings path that fixes it |
| Sentiment | `NLTagger` sentiment | Bundled VADER, 7,517 entries | r = +0.663 vs NLTagger's +0.594 on 1,459 labelled entries |
| Entities | `NLTagger` NER | Capitalisation heuristic | 99.1% recall vs 94.6% on 28 transcribed entries, 111 gold spans |
| Prosody | AVFoundation + Accelerate | MediaCodec + autocorrelation | Same `ProsodyFeatures` field contract; DSP unit-tested against synthesised signals |
| Storage | Core Data + CloudKit | Room, no sync | Same schema shape; encrypted export is byte-compatible in both directions |
| Backup | iCloud (opt-out) | Manual export only | Android Auto Backup explicitly disabled — see below |
| Lock | Face ID + Secure Enclave | `BiometricPrompt` + Keystore | — |
| Body | HealthKit | Health Connect | Opt-in, read-only, four record types |

**The Android backup decision is load-bearing.** `allowBackup` defaults to true,
and Android Auto Backup copies `filesDir` — the Room database and every audio
recording — to the user's Google Drive. The *system* performs that copy, so it
needs no INTERNET permission from the app: every privacy claim could remain
technically true while the journal sat on a server. It is disabled explicitly in
`data_extraction_rules.xml`, with device-to-device transfer left enabled because
that is local and losing a diary when changing phones is its own harm.

**Encrypted exports are cross-platform by construction.** Both platforms write
`[4-byte "DVX1"][32-byte salt][12-byte nonce][ciphertext+tag]`, AES-256-GCM with
HKDF-SHA256 over a user passphrase. Verified in both directions across
toolchains: a file written by Kotlin opens under Apple's CryptoKit, and a file
written by CryptoKit is a test fixture the Kotlin suite opens.

### Core Pipeline

| Module | File | Responsibility |
|---|---|---|
| **AudioRecorder** | `AudioRecorder.swift` | AVAudioRecorder wrapper. Records AAC at 44.1kHz, provides real-time audio levels. Stores recordings in the app sandbox. |
| **SpeechTranscriber** | `SpeechTranscriber.swift` | On-device speech-to-text via SFSpeechRecognizer (`requiresOnDeviceRecognition = true`). Supports 60+ languages. Runs on Apple Neural Engine. |
| **Persistence** | `Persistence.swift` | Core Data with NSPersistentCloudKitContainer. Stores entries, audio metadata, and AI state. App Group for WidgetKit data sharing. Also provides `CoreDataTwinStateStore`. |
| **SemanticSearchManager** | `SemanticSearchManager.swift` | Owns the engine's `SemanticMemoryIndex` over a local file store, keeps it in step with Core Data, and answers phrase queries. |
| *LocalAIEngine, InsightsEngine, DigitalTwinEngine, TwinPredictions* | *(engine package)* | NLP analysis, insight cards, the personality models and forecasting. **These moved out of this repo** — see the engine boundary above. |

### Digital Twin Sub-Models

The engine maintains four interconnected models:

- **CommunicationStyle** — Vocabulary richness (TTR), directness, formality, signature words
- **EmotionalSignature** — Valence/arousal/dominance baselines, daily/weekly cycles, emotional volatility
- **PersonalKnowledgeGraph** — NER-extracted entities (people, places, orgs) with emotional weights and co-occurrence relationships. Entities are additionally attached to the entries they came from, through a device-local mention index that never enters the synced blob.
- **TwinPredictions** — Mood forecasting, trigger anticipation, temporal patterns, seasonal detection

### Views

| View | File | Purpose |
|---|---|---|
| **ContentView** | `ContentView.swift` | Main TabView container. Adapts to sidebar on iPadOS 18+. |
| **TodayView** | `TodayView.swift` | Daily journaling interface with recording |
| **TimelineView** | `TimelineView.swift` | Historical entry browsing |
| **DigitalTwinView** | `DigitalTwinView.swift` | Twin personality display and insights |
| **TwinChatView** | `TwinChatView.swift` | "Ask Your Twin" conversational interface |
| **EntryDetailView** | `EntryDetailView.swift` | Entry viewing and editing |
| **InsightsView** | `StatsView.swift` | Mood trends, streaks, analytics |
| **SettingsView** | `SettingsView.swift` | Preferences and configuration |
| **OnboardingView** | `OnboardingView.swift` | First-launch setup flow |
| **BackupExportView** | `BackupExportView.swift` | Export and import data |

### Support Modules

| Module | File | Purpose |
|---|---|---|
| **EncryptionService** | `EncryptionService.swift` | AES-256-GCM via CryptoKit. File format: `[DVX1 magic][salt][nonce][ciphertext+tag]` |
| **AppLockManager** | `AppLockManager.swift` | Face ID / Touch ID via LocalAuthentication |
| **ThemeManager** | `ThemeManager.swift` | 8 themes (System, Light, Sage, Lavender, Rose, Ocean, Warm, Dark) |
| **PhotoStorageManager** | `PhotoStorageManager.swift` | On-device photo attachment storage (up to 5 per entry) |
| **GoalManager** | `GoalManager.swift` | Journaling goals, streaks, milestones |
| **ReviewManager** | `ReviewManager.swift` | App Store review prompts via SKStoreReviewController |
| **BackupService** | `BackupService.swift` | Export/import orchestration |
| **PDFExportService** | `PDFExportService.swift` | PDF generation from entries |
| **HapticManager** | `HapticManager.swift` | Haptic feedback patterns |
| **ReminderManager** | `ReminderManager.swift` | Daily reminder notifications |
| **AppIntents** | `AppIntents.swift` | Siri Shortcuts integration |

## Apple Frameworks Used

| Framework | Purpose |
|---|---|
| Speech | On-device speech recognition |
| NaturalLanguage | NLP (sentiment, NER, POS tagging) |
| CoreData | Local persistence |
| CloudKit | Optional iCloud sync |
| CryptoKit | AES-256-GCM encryption |
| LocalAuthentication | Biometric security |
| WidgetKit | Home & Lock Screen widgets |
| AppIntents | Siri Shortcuts |
| AVFoundation | Audio recording & playback |

## Key Constraints

- **Zero external dependencies** — No third-party SDKs, analytics, crash reporting, or ad networks
- **On-device only** — All audio, transcription, and AI processing stays on the device
- **No network calls** for user data — Optional iCloud sync is user-initiated and Apple-encrypted
- **Privacy label** — Apple "Data Not Collected"

## Building

1. Open `ios/solyn.xcodeproj` in Xcode 15+
2. Select the `solyn` scheme
3. Build and run on an iOS 17+ Simulator or device
4. Tests: `solynTests` (unit) and `solynUITests` (UI)
