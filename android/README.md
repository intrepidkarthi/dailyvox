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

## Tools

```bash
tools/capitalisation-probe.sh    # the release blocker, answered on a real phone
tools/make-engine-stub.sh        # build without engine access
```

`capitalisation-probe.sh` answers the one question no emulator can: does this
phone's recogniser capitalise names? The entity graph is built entirely from
capitalisation evidence, so on a device that returns lowercase the Twin screen
is empty however many entries are recorded. Speak the three sentences it prints,
and it reads the entries back out of the app's own database and shows the raw
transcript so the casing is visible directly.

`make-engine-stub.sh` generates a non-functional stub of the private engine so
the app compiles without it. Name detection returns nothing and every mood
scores 0.0 — it exists to typecheck the app, and CI uses it for pull requests
from forks.
