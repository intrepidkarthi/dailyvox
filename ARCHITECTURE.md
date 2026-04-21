# DailyVox Architecture

This document describes the high-level architecture of DailyVox to help contributors understand the codebase.

## Data Flow

```
Microphone → AudioRecorder (AAC 44.1kHz)
    ↓
SpeechTranscriber (SFSpeechRecognizer, on-device)
    ↓
LocalAIEngine + InsightsEngine (NLTagger analysis)
    ↓
DigitalTwinEngine (personality modeling)
    ↓
Persistence (Core Data + optional CloudKit)
    ↓
UI (SwiftUI, WidgetKit, AppIntents)
```

## Module Overview

All source files are in `solyn/solyn/`.

### Core Pipeline

| Module | File | Responsibility |
|---|---|---|
| **AudioRecorder** | `AudioRecorder.swift` | AVAudioRecorder wrapper. Records AAC at 44.1kHz, provides real-time audio levels. Stores recordings in the app sandbox. |
| **SpeechTranscriber** | `SpeechTranscriber.swift` | On-device speech-to-text via SFSpeechRecognizer (`requiresOnDeviceRecognition = true`). Supports 60+ languages. Runs on Apple Neural Engine. |
| **LocalAIEngine** | `LocalAIEngine.swift` | NLP analysis using NaturalLanguage framework. Sentiment analysis, topic extraction, intent recognition. Maintains a UserProfile for learned patterns. |
| **InsightsEngine** | `InsightsEngine.swift` | Generates insight cards from journal data. Sentiment trends, topic frequency, journaling patterns. |
| **DigitalTwinEngine** | `DigitalTwinEngine.swift` | Core personality model with four sub-models (see below). Processes NLTagger output per entry. Serializes to JSON in Core Data (~12 KB). |
| **Persistence** | `Persistence.swift` | Core Data with NSPersistentCloudKitContainer. Stores entries, audio metadata, and AI state. App Group for WidgetKit data sharing. |

### Digital Twin Sub-Models

The Twin engine (`DigitalTwinEngine.swift`) maintains four interconnected models:

- **CommunicationStyle** — Vocabulary richness (TTR), directness, formality, signature words
- **EmotionalSignature** — Valence/arousal/dominance baselines, daily/weekly cycles, emotional volatility
- **PersonalKnowledgeGraph** — NER-extracted entities (people, places, orgs) with emotional weights and co-occurrence relationships
- **TwinPredictions** (`TwinPredictions.swift`) — Mood forecasting, trigger anticipation, temporal patterns, seasonal detection

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

1. Open `solyn/solyn.xcodeproj` in Xcode 15+
2. Select the `solyn` scheme
3. Build and run on an iOS 17+ Simulator or device
4. Tests: `solynTests` (unit) and `solynUITests` (UI)
