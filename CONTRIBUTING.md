# Contributing to DailyVox

Thanks for your interest in contributing to DailyVox! This guide will help you get started.

## Quick Start (5 minutes)

1. **Fork & clone**
   ```bash
   git clone https://github.com/<your-username>/dailyvox.git
   cd dailyvox
   ```
2. **Open in Xcode** — `solyn/solyn.xcodeproj` (shared scheme is included, no setup needed)
3. **Build & run** — select any iOS 17+ Simulator and hit `Cmd+R`
4. **Run tests** — `Cmd+U` to run the unit test suite
5. **Pick an issue** — look for [`good first issue`](https://github.com/intrepidkarthi/dailyvox/labels/good%20first%20issue) or [`help wanted`](https://github.com/intrepidkarthi/dailyvox/labels/help%20wanted) labels

That's it — no API keys, no server setup, no dependencies to install. Everything runs on-device.

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
- Add new insight types in `InsightsEngine.swift`
- Extend the knowledge graph in `DigitalTwinEngine.swift`
- Improve Twin chat responses in `TwinChatView.swift`
- Add new export formats in `BackupService.swift`

### Advanced tasks (check the [Roadmap](ROADMAP.md))
- **v1.3**: Semantic search with NLEmbedding
- **v1.4**: Apple Watch companion app
- **v2.0**: Foundation Models integration

## Prerequisites

- **Xcode 15+** (latest stable recommended)
- **iOS 17+ SDK**
- A Mac with macOS Sonoma or later
- No third-party tools required — zero external dependencies

## Development Workflow

1. **Check existing issues** — look for an issue to work on, or open one to discuss your idea first
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** — keep commits focused and atomic
4. **Test thoroughly** — ensure the app builds and runs correctly on the Simulator (`Cmd+U` for tests)
5. **Open a Pull Request** against `main` with a clear description of your changes

CI will automatically build and run tests on your PR.

## Understanding the Codebase

All app code lives in `solyn/solyn/`. Read [ARCHITECTURE.md](ARCHITECTURE.md) for the full module map, but here's the quick version:

```
Microphone → AudioRecorder → SpeechTranscriber → LocalAIEngine → DigitalTwinEngine → Core Data
                                                       ↓
                                                 InsightsEngine → UI Views
```

Key files to know:
| File | What it does |
|---|---|
| `ContentView.swift` | Main tab navigation |
| `TodayView.swift` | Daily journaling & recording |
| `DigitalTwinEngine.swift` | Core Twin personality model |
| `LocalAIEngine.swift` | NLP analysis (sentiment, entities) |
| `Persistence.swift` | Core Data layer |
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
