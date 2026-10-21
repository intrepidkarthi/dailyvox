# DailyVox - App Store Submission Checklist

The steps every iOS update goes through. The App Store record already exists, so
there is no "create the app" step any more. Each release also gets its own
`Submission_<version>.md` in this folder (version and build, What's New,
Promotional Text, review notes, anything release-specific), and that file wins
where the two differ.

## Pre-Submission

### Code & Build
- [ ] The private engine is checked out at `DailyVoxTwin/` in the repository root (see `CONTRIBUTING.md`); without it the app does not build
- [ ] Builds in Xcode 26 or later; `solynTests` green
- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` bumped in `ios/solyn.xcodeproj` (all targets, including the widget)
- [ ] Minimum deployment target unchanged at iOS 17.0
- [ ] Bundle identifier: `com.dailyvox.app` (widget: `com.dailyvox.app.DailyVoxWidgets`)
- [ ] App Group: `group.com.dailyvox.app`
- [ ] `ITSAppUsesNonExemptEncryption = false` still in `Info.plist`, so App Store Connect does not ask about export compliance
- [ ] Archive builds in Release configuration

### Data model and CloudKit
- [ ] If the Core Data model changed, the new fields are deployed to the CloudKit **Production** schema before the build ships, then checked with a TestFlight build: turn sync on, save an entry, and look for the record in Production

### Device pass
- [ ] Every new screen and card looked at on a real iPhone, at the largest Dynamic Type size and with VoiceOver
- [ ] With the phone **online**, recording still transcribes on-device (airplane mode cannot catch a network fallback, because with no network there is nothing to leak to)

### Screenshots
- [ ] Unchanged screens are still accurate; regenerate only if the release changes what they show: `bash ios/AppStore/screenshot-src/make_screenshots.sh`
- Current sets live in `screenshots/` (iPhone 6.1", 6.3", 6.5", 6.9", and the Dynamic Island medium size)

### Metadata (`AppStoreMetadata.md`)
- [ ] App Name: "DailyVox: Voice Journal Diary"
- [ ] Subtitle: "Private On-Device Audio Diary"
- [ ] Description, keywords and Promotional Text current
- [ ] A "What's New (Version x.y.z)" section added at the top of the What's New list, matching what goes into App Store Connect
- [ ] Category: Health & Fitness / Productivity
- [ ] Age Rating: 4+
- [ ] Support URL: https://getdailyvox.com/support
- [ ] Privacy Policy URL: https://getdailyvox.com/privacy

### Privacy
- [ ] App Privacy label still "Data Not Collected" (nothing new leaves the device)
- [ ] If the release changes what the app reads or shows, the published policy at getdailyvox.com/privacy and `PrivacyPolicy.md` both say so

### App Review
- [ ] Review notes: the latest `ReviewNotes_<version>.md`, plus anything the release's `Submission_<version>.md` adds
- [ ] Demo account: none required. No accounts exist

## Upload

1. Xcode → Product → Archive
2. Window → Organizer → Distribute App → App Store Connect
3. Wait for processing, then attach the build to the new version in App Store Connect
4. Paste What's New, Promotional Text and the review notes from `Submission_<version>.md`
5. Submit

`Deliverfile` in this folder is from the first release and is out of date; it is not part of this process.

## Post-Submission

- [ ] Monitor App Store Connect for review status
- [ ] Respond to any App Review feedback within 24 hours
- [ ] Monitor crash reports via Xcode Organizer

## After the release is live

Update the versions the website shows (top-bar badge, footer on every page, schema, "latest" lines), once the store actually serves the new build:

```bash
python3 website/set_version.py --ios <version> --android <version>   # the numbers now live
```

Then add the release to website/public/changelog.html and the roadmap table by hand.
