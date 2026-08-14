# v1.3.5 — Final verification & ship checklist

The Widget Extension target (`DailyVoxWidgets`) has been added to the Xcode project programmatically via the `xcodeproj` Ruby gem. Verified by `xcodebuild` clean build → **BUILD SUCCEEDED**, 0 errors, 0 warnings. The widget binary is embedded into `solyn.app/PlugIns/DailyVoxWidgets.appex` and contains all five new types (`RecordingActivityAttributes`, `StarBirthActivityAttributes`, `StreakActivityAttributes`, `ConstellationLockScreenWidget`, `DailyVoxWidgetBundle`).

You can open `solyn.xcodeproj` in Xcode and it'll just build. No manual target wiring needed.

A safety backup of the original `project.pbxproj` is at `/tmp/project.pbxproj.before-widget-target` if you ever want to revert.

## 1. Sanity check in Xcode

Open `ios/solyn.xcodeproj`. In the project navigator you should see four targets in the scheme list:
- `solyn` (the app)
- `solynTests`
- `solynUITests`
- `DailyVoxWidgets` (new — Widget Extension)

Select the **DailyVoxWidgets** scheme briefly and confirm:
- **General → Minimum Deployments**: iOS 17.0
- **General → Bundle Identifier**: `com.dailyvox.app.DailyVoxWidgets`
- **Signing & Capabilities → Team**: same as the main app (auto-managed should already match)
- **Signing & Capabilities → App Groups**: this needs to be added once via the UI. Click **+ Capability** → **App Groups**, then check `group.com.dailyvox.app`. The entitlements file at `SolynWidget/SolynWidget.entitlements` already declares it, but Xcode's signing service needs the capability registered in App Store Connect under your team's identifiers.

Build the `solyn` scheme (⌘B). Should be clean.

## 2. Test each Live Activity on a real device

Live Activities don't render in the simulator. Plug in an iPhone 14 Pro or newer (Dynamic Island devices) and run `solyn` on it.

- **Recording timer**: Open the Today tab. Tap the mic. Dynamic Island should show a red `mic.fill` glyph (compact-leading) and the elapsed time counting up (compact-trailing). Long-press the island to see the expanded view with the live waveform. Keep talking past 0:42 — the timer keeps counting up and the progress line changes to "Past your daily 42 — keep going as long as you like."
- **Star birth**: Finish the recording (tap the mic again to stop). Wait ~1 second for transcription. A brief star-fill Live Activity appears in the Dynamic Island for ~8 seconds, then auto-dismisses.
- **Streak (opt-in)**: Settings tab → scroll to **Live Activities** → toggle **"Show streak in Dynamic Island"** on. A `★ Day N` activity pins to the Dynamic Island and Lock Screen. Toggle off to end it.
- **Lock Screen constellation widget**: Lock the phone. Long-press the Lock Screen → **Customise** → tap the rectangular widget slot → search **DailyVox** → select **Constellation**. A tiny canvas of your recent entries appears as stars connected by faint lines.

On non-Pro iPhones (without Dynamic Island), Live Activities still appear as Lock Screen banners and in the notification centre — they just don't get the pill/expanded presentations.

## 3. Submit to App Store

1. **Product → Archive** (top menu in Xcode).
2. In the Organizer window, **Distribute App** → **App Store Connect** → **Upload**.
3. In App Store Connect, create a new v1.3.5 build and paste this release notes block:

```
DailyVox 1.3.5

• Brand new app icon — a golden mic on warm sage, with iOS 18 dark mode + tinted variants
• Dynamic Island: a live recording timer with waveform, so you can see how long you've been speaking at a glance
• A celebratory "new star" Live Activity appears the moment your entry is saved
• Opt-in: pin your current streak to the Dynamic Island and Lock Screen (Settings → Live Activities)
• New Constellation Lock Screen widget — your inner sky, one star per recent entry
• 42 seconds is still the sweet spot, but you can now speak for as long as you need
```

## Common gotchas (if something goes wrong)

- **App Group capability error during sign**: Add the App Group capability to the `DailyVoxWidgets` target in Xcode (Signing & Capabilities → + Capability → App Groups → `group.com.dailyvox.app`). The entitlements file is already correct; this just registers it with App Store Connect.
- **Live Activities don't appear at all on the device**: System Settings → DailyVox → "Live Activities" toggle. This is iOS's user-facing permission, separate from the in-app opt-in for the streak activity.
- **Dynamic Island only shows minimal/compact**: That's expected on devices without Dynamic Island (iPhone 14 standard or older). Lock Screen presentation always works on iOS 16.1+.

## How the target was added (for reference)

The Widget Extension target was added by running `/tmp/add_widget_target.rb` against the project file. The script used the `xcodeproj` Ruby gem (the same library CocoaPods uses) to:

1. Create a `DailyVoxWidgets` PBXNativeTarget (app extension, iOS 17)
2. Configure Debug + Release build settings (bundle id, Info.plist path, entitlements path, marketing/build version, SKIP_INSTALL, runpath search paths)
3. Add the 5 widget Swift files from `SolynWidget/` to the target's Sources phase
4. Add a second file reference to `solyn/LiveActivityAttributes.swift` so it compiles into both targets (main app gets it via the synchronized `solyn/` group; widget gets it via this explicit reference)
5. Add a new "Embed App Extensions" copy-files phase to the main `solyn` target with PlugIns subfolder spec
6. Add a target dependency `solyn → DailyVoxWidgets` so the widget builds first

The script is idempotent — running it again is a no-op if the target already exists.
