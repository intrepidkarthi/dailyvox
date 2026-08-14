# DailyVox - App Store Submission Checklist

## Pre-Submission

### Code & Build
- [ ] All source files compile without errors
- [ ] No warnings in Release build
- [ ] Minimum deployment target set (iOS 16.0 recommended)
- [ ] Bundle identifier: `com.dailyvox.app`
- [ ] Version: 1.0.0
- [ ] Build number: 1
- [ ] App Group configured: `group.com.dailyvox.app`
- [ ] Archive builds successfully in Release configuration

### App Icon
- [ ] 1024x1024 App Store icon (already in Assets.xcassets)
- [ ] No transparency or alpha channel
- [ ] No rounded corners (iOS applies them automatically)

### Screenshots (Required)
- [ ] iPhone 6.7" display (1290 x 2796) - at least 3 screenshots
- [ ] iPhone 6.5" display (1284 x 2778) - at least 3 screenshots
- [ ] iPhone 5.5" display (1242 x 2208) - at least 3 screenshots
- [ ] iPad 12.9" display (2048 x 2732) - if supporting iPad
- See `ScreenshotAssets.md` for caption text and layout guide

### Metadata (Ready in AppStoreMetadata.md)
- [x] App Name: "DailyVox - AI Voice Diary"
- [x] Subtitle: "Your Private Digital Twin"
- [x] Description (under 4000 chars)
- [x] Keywords (under 100 chars)
- [x] Promotional Text
- [x] What's New text
- [x] Category: Health & Fitness / Lifestyle
- [x] Age Rating: 4+
- [x] Copyright
- [x] Support URL
- [x] Privacy Policy URL

### Privacy (Ready in PrivacyPolicy.md)
- [x] Privacy Policy written
- [x] Privacy Policy hosted at URL
- [x] App Privacy labels configured (Data Not Collected)

### App Review
- [x] Review notes prepared (in metadata.json)
- [ ] Demo video prepared (optional but recommended)
- [ ] No placeholder content in screenshots
- [ ] All links in app work (support URL, privacy URL)

## App Store Connect Setup

### Create App Record
1. Go to App Store Connect > My Apps > "+"
2. Platform: iOS
3. Name: DailyVox - AI Voice Diary
4. Primary Language: English (US)
5. Bundle ID: com.dailyvox.app
6. SKU: dailyvox-ios-v1

### App Information
1. Category: Health & Fitness
2. Secondary Category: Lifestyle
3. Content Rights: Does not contain third-party content
4. Age Rating: Configure with `rating_config.json`

### Pricing and Availability
1. Price: Free
2. Availability: All territories

### App Privacy
1. Data Collection: "No, we do not collect data from this app"
2. No data types to declare

### Version Information
1. Upload screenshots for each device size
2. Add promotional text
3. Add description
4. Add keywords
5. Add What's New
6. Add support URL
7. Add marketing URL (optional)

## Upload Process

### Using Xcode
1. Archive: Product > Archive
2. Distribute App > App Store Connect
3. Upload
4. Wait for processing (5-30 minutes)

### Using Fastlane (Recommended)
```bash
# Install fastlane
gem install fastlane

# Initialize (first time)
cd dailyvox
fastlane init

# Upload metadata
fastlane deliver

# Build and upload
fastlane gym
fastlane deliver --ipa path/to/dailyvox.ipa
```

### Using xcrun
```bash
# Archive
xcodebuild archive \
  -project dailyvox.xcodeproj \
  -scheme dailyvox \
  -archivePath build/dailyvox.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/dailyvox.xcarchive \
  -exportPath build/ \
  -exportOptionsPlist ExportOptions.plist

# Upload
xcrun altool --upload-app \
  -f build/dailyvox.ipa \
  -t ios \
  -u YOUR_APPLE_ID \
  -p YOUR_APP_SPECIFIC_PASSWORD
```

## Post-Submission

- [ ] Monitor App Store Connect for review status
- [ ] Respond to any App Review feedback within 24 hours
- [ ] Prepare marketing materials for launch day
- [ ] Set up App Store page URL for sharing
- [ ] Monitor crash reports via Xcode Organizer
- [ ] Plan v1.1 features based on user feedback
