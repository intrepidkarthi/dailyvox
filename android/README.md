# DailyVox for Android

On [Google Play](https://play.google.com/store/apps/details?id=com.dailyvox.app)
since 2026-10-02, for Android 13 or newer. Android has its own version line,
not a counterpart to any iOS version: `versionCode` and `versionName` are in
`app/build.gradle.kts`, and what each release contains is in the repository's
[`CHANGELOG.md`](../CHANGELOG.md).

## The Twin engine is not in this repository

The algorithms that compute anything about you — name detection, sentiment
scoring, prosody, the entity graph — live in a separate **private** package,
`github.com/intrepidkarthi/DailyVoxTwin`, exactly as they do on iOS. This
repository is the app: UI, recording, storage, export, widgets.

Check it out inside the root of this repository, beside `android/` and `ios/`.
It is gitignored there, and both apps look for it in the same place:

```
dailyvox/            <- this repository
  android/           <- you are here
  ios/
  DailyVoxTwin/      <- the engine (private)
```

The Gradle build includes the engine by relative path
(`../DailyVoxTwin/kotlin/engine`) and **fails with an explicit message** if it is
missing. That is deliberate: a build that silently produced an app with no name
detection and every mood reading 0.00 would look like a working app right up
until someone trusted it.

## Building

You need **JDK 21** and an **Android SDK**. Gradle finds the SDK through
`ANDROID_HOME` or through `sdk.dir` in `android/local.properties` (gitignored);
without either the build stops with "SDK location not found".

The Kotlin compiler in this toolchain cannot parse a JDK 26 version string and
dies with `IllegalArgumentException: 26.0.2`, so set JDK 21 explicitly:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null || echo /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home)
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest     # needs the real engine
```

The fallback is not belt and braces. Homebrew's `openjdk@21` is **keg-only**, so
it is never symlinked into `/Library/Java/JavaVirtualMachines` and
`/usr/libexec/java_home` cannot see it. Worse, `java_home -v 21` does not fail
when 21 is absent — it returns whatever JDK it *does* have. On a machine with
only JDK 26 installed the export silently sets 26, `:app` still builds because
AGP forks its own compiler, and only `:engine` dies, with
`IllegalArgumentException: 26.0.2` and no mention of Java anywhere in it.

Verify rather than assume:

```bash
java -version   # must say 21
```

The store screenshots come from a seeded demo journal, which is off in every
build unless you ask for it: `./gradlew installDebug -PseedDemo`.

### Without engine access

Generate a stub of the engine and build against that:

```bash
tools/make-engine-stub.sh            # writes ../DailyVoxTwin/kotlin/engine
./gradlew :app:assembleDebug
```

The stub has the same signatures as the engine and none of its behaviour: no
names are detected, every mood scores 0.0 and prosody is unavailable. It is
there so the app compiles, which is what CI uses it for on pull requests from
forks. The app's unit tests read the shipped sentiment asset and assert real
scores, so they need the real engine; CI skips them on a stub build.

The script refuses to overwrite a real engine. If you add an engine call to the
app, add it to the stub too, or outside contributors' builds stop compiling.

## Tools

```bash
tools/capitalisation-probe.sh    # does this phone's recogniser capitalise names?
tools/recogniser-probe.sh        # what speech recogniser this phone really has
tools/make-engine-stub.sh        # build without engine access
```

`capitalisation-probe.sh` answers the one question no emulator can: does this
phone's recogniser capitalise names? The entity graph is built entirely from
capitalisation evidence, so on a device that returns lowercase the Twin screen
is empty however many entries are recorded. Speak the three sentences it prints,
and it reads the entries back out of the app's own database and shows the raw
transcript so the casing is visible directly.

`recogniser-probe.sh` asks the platform, over adb, what on-device recogniser the
phone actually has. The in-app check only reads a config string and returns true
on phones where nothing works.

## Releasing

From 1.2 on, each release has a `playstore/RELEASE_NOTES_<version>.md` with the Play release
notes and its own pre-upload checks. The steps every update goes through are in
[`playstore/SUBMISSION_CHECKLIST.md`](playstore/SUBMISSION_CHECKLIST.md). Run
`python3 playstore/verify.py` before any upload: it checks the permission list in
`DATA_SAFETY.md` against the built APK and the store listing against Play's
limits and the source.
