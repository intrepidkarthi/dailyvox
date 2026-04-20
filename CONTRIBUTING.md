# Contributing to DailyVox

Thanks for your interest in contributing to DailyVox! This guide will help you get started.

## Getting Started

### Prerequisites

- **Xcode 15+** (latest stable recommended)
- **iOS 17+ SDK**
- A Mac with macOS Sonoma or later

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/dailyvox.git
   cd dailyvox
   ```
3. Open `solyn/solyn.xcodeproj` in Xcode
4. Build and run on the iOS Simulator

## How to Contribute

### Reporting Bugs

- Use the [Bug Report](https://github.com/intrepidkarthi/dailyvox/issues/new?template=bug_report.md) issue template
- Include steps to reproduce, expected vs actual behavior, and device/OS details
- Screenshots or screen recordings are very helpful

### Suggesting Features

- Use the [Feature Request](https://github.com/intrepidkarthi/dailyvox/issues/new?template=feature_request.md) issue template
- Explain the use case and why it matters

### Submitting Code

1. **Check existing issues** — look for an issue to work on, or open one to discuss your idea first
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** — keep commits focused and atomic
4. **Test thoroughly** — ensure the app builds and runs correctly on the Simulator
5. **Open a Pull Request** against `main` with a clear description of your changes

### Code Style

- Follow existing Swift conventions in the codebase
- Use meaningful variable and function names
- Keep views and logic separated where possible

## Privacy First

DailyVox is a privacy-focused app. All processing happens on-device. When contributing, please ensure:

- **No network calls** for user data — everything stays on-device
- **No third-party analytics or tracking SDKs**
- **No cloud dependencies** for core functionality

Any PR that introduces external data transmission for user content will be declined.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Questions?

Open a [discussion](https://github.com/intrepidkarthi/dailyvox/discussions) or file an issue. We're happy to help!
