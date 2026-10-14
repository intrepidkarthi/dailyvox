# Contributing to DailyVox

Thanks for your interest in contributing to DailyVox! This guide will help you get started.

## Before you clone: the engine is private

This repository is the app. The Digital Twin engine it depends on is a separate,
**private** on-device package (`DailyVoxTwinEngine`), and both apps expect it
checked out at `DailyVoxTwin/` in the root of this repository. The Xcode project
points at `../DailyVoxTwin` from `ios/`, and the Android build at
`../DailyVoxTwin/kotlin/engine` from `android/`. The folder is gitignored.

What that means for you:

| | With engine access | Without engine access |
|---|---|---|
| **iOS** | Builds and runs | **Does not build.** Xcode cannot resolve the `DailyVoxTwin` package, and there is no stub for it |
| **Android** | Builds, runs, unit tests pass | Compiles against a generated stub (`android/tools/make-engine-stub.sh`). A stub build detects no names, scores every mood 0.0 and reports no prosody, so it is for checking that your change compiles, not for judging behaviour |

No API keys and no server setup in either case. Everything runs on-device.

## Quick Start

1. **Fork & clone**
   ```bash
   git clone https://github.com/<your-username>/dailyvox.git
   cd dailyvox
   ```
2. **Add the engine** — with access:
   ```bash
   git clone git@github.com:intrepidkarthi/DailyVoxTwin.git   # lands at dailyvox/DailyVoxTwin
   ```
   Without access, for Android only:
   ```bash
   android/tools/make-engine-stub.sh
   ```
3. **iOS** — open `ios/solyn.xcodeproj` in Xcode 26 or later (the shared `solyn` scheme is included), pick an iOS 17+ Simulator and hit `Cmd+R`. `Cmd+U` runs the tests.
4. **Android** — see [`android/README.md`](android/README.md): JDK 21, an Android SDK, then `./gradlew :app:assembleDebug` from `android/`.
5. **Pick an issue** — look for [`good first issue`](https://github.com/intrepidkarthi/dailyvox/labels/good%20first%20issue) or [`help wanted`](https://github.com/intrepidkarthi/dailyvox/labels/help%20wanted) labels

If you have no engine access and want to work on the iOS app, open an issue
first, so we can find a piece of work that can be checked without a local build
(copy, accessibility labels, docs) or agree another way to test it.

## Where to Start

Not sure what to work on? Here are some ways to jump in:

### No-code contributions
- **Report a bug** — [open a bug report](https://github.com/intrepidkarthi/dailyvox/issues/new?template=bug_report.md)
- **Suggest a feature** — [open a feature request](https://github.com/intrepidkarthi/dailyvox/issues/new?template=feature_request.md)
- **Improve docs** — Fix typos, clarify instructions, add examples
- **Test on your device** — Try the app and report anything unexpected

### Beginner-friendly code tasks
- Fix UI issues (alignment, colors, spacing)
- Add unit tests for existing modules (see `solynTests/`)
- Improve accessibility labels on views
- Add new themes to `ThemeManager.swift`

### Intermediate tasks
- Improve the Twin chat interface in `TwinChatView.swift`
- Add new export formats in `BackupService.swift`
- Bring an iOS-only detail to Android, or the other way round (see the parity matrix in [ROADMAP.md](ROADMAP.md#platforms))

Insight types, the knowledge graph and the personality models live in the
private engine, so they are not open to outside changes.

### Advanced tasks (check the [Roadmap](ROADMAP.md))
- **v1.4**: Body Twin — HealthKit integration + Apple Watch companion app
- **v1.5**: Semantic search with NLEmbedding (cosine similarity, K-means clustering, anomaly detection)
- **v1.6**: Apple Foundation Models integration (on-device 3B LLM Twin chat)
- **v1.7**: multi-language String Catalogs *(shipped in v1.10)*

These are historical suggestions and several have since shipped or been dropped —
check [ROADMAP.md](ROADMAP.md) for what is actually open before starting work.

## Prerequisites

For the iOS app:

- **Xcode 26 or later.** The app runs on iOS 17, but it calls iOS 26 APIs
  (`SpeechAnalyzer`) behind availability checks, so it needs the iOS 26 SDK to compile
- The private engine at `DailyVoxTwin/` (see above)

For the Android app: JDK 21, an Android SDK (`ANDROID_HOME`, or `sdk.dir` in
`android/local.properties`) and the Gradle wrapper — details in
[`android/README.md`](android/README.md). Neither app requires the other's toolchain.

No third-party libraries or tools beyond those.

## Development Workflow

1. **Check existing issues** — look for an issue to work on, or open one to discuss your idea first
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** — keep commits focused and atomic
4. **Test thoroughly** — ensure the app builds and runs correctly on the Simulator (`Cmd+U` for tests)
5. **Open a Pull Request** against `main` with a clear description of your changes

CI runs on pull requests that touch `ios/` or `android/`. The Android workflow
builds against the stub when it has no engine access, so it checks that the app
compiles and that no network permission or Auto Backup has crept in; it runs the
unit tests only with the real engine. The iOS workflow has no engine access
either, so at present it cannot build the app: treat its result as no signal,
and say in your PR how you built and tested.

## Understanding the Codebase

iOS app code lives in `ios/solyn/`, Android app code in `android/app/src/main/kotlin/`. Read [ARCHITECTURE.md](ARCHITECTURE.md) for the full module map, but here's the quick version for iOS:

```
Microphone → AudioRecorder → SpeechTranscriber → [private engine] → Core Data → UI Views
```

Key files to know:
| File | What it does |
|---|---|
| `ContentView.swift` | Main tab navigation |
| `TodayView.swift` | Daily journaling & recording |
| `Persistence.swift` | Core Data layer |
| `SuggestedMood.swift` | The suggested mood, and the rule that never overwrites one the user chose |
| `ReminderManager.swift` | Daily reminders |
| `TwinChatView.swift` | "Ask Your Twin" chat interface |

## Code Style

- Follow existing Swift conventions in the codebase
- Use meaningful variable and function names
- Keep views and logic separated where possible
- SwiftLint is configured (`.swiftlint.yml`) — run it locally if you have it installed

## Privacy First

DailyVox is a privacy-focused app. All processing happens on-device. When contributing, please ensure:

- **No network calls** for user data — everything stays on-device
- **No third-party analytics or tracking SDKs**
- **No cloud dependencies** for core functionality
- **No new framework dependencies** without discussion first

Any PR that introduces external data transmission for user content will be declined.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Questions?

Open a [discussion](https://github.com/intrepidkarthi/dailyvox/discussions) or file an issue. We're happy to help!
