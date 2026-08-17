# DailyVox for Android

## The Twin engine is not in this repository

The algorithms that compute anything about you — name detection, sentiment
scoring, prosody, the entity graph — live in a separate **private** package,
`github.com/intrepidkarthi/DailyVoxTwin`, exactly as they do on iOS. This
repository is the app: UI, recording, storage, export, widgets.

Check the two out side by side:

```
voicetotext/
  android/          <- this repo
  DailyVoxTwin/     <- the engine (private)
```

The Gradle build includes the engine by relative path and **fails with an
explicit message** if it is missing. That is deliberate: a build that silently
produced an app with no name detection and every mood reading 0.00 would look
like a working app right up until someone trusted it.

Requires **JDK 21** — the Kotlin compiler in this toolchain cannot parse a JDK 26
version string and dies with `IllegalArgumentException: 26.0.2`:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
./gradlew :app:assembleDebug
```

### Without engine access

Contributors without access can still build everything else by creating a local
stub module that satisfies the same signatures. The app calls exactly four
entry points: `NameDetector.detect/vocabulary/extract`, `Sentiment.valence/
parseLexicon/install`, `Prosody.analyse`, and `EntityGraph`.
