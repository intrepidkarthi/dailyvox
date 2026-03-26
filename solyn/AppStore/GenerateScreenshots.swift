//
//  GenerateScreenshots.swift
//  solyn
//
//  Xcode UI Test plan for automated App Store screenshot generation.
//  Use with fastlane snapshot or Xcode Test Plans.
//
//  Usage:
//  1. Add this file to solynUITests target
//  2. Run: fastlane snapshot
//  3. Or run these tests manually with Cmd+U
//

import XCTest

class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["-UITesting", "-ScreenshotMode"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        setupSnapshotConfiguration()
        app.launch()
    }

    func setupSnapshotConfiguration() {
        // Configure snapshot helper if using fastlane
        // Snapshot.setupSnapshot(app)
    }

    // MARK: - Screenshot 1: Today View (Voice Recording)
    // Caption: "Voice Journal — Just Talk, We Transcribe"
    func test01_TodayView() throws {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "01_TodayView"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 2: Digital Twin Overview (with Predictions + Profile Card)
    // Caption: "Your AI Digital Twin Learns Your Patterns"
    func test02_DigitalTwin() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "02_DigitalTwin"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 3: Insights (with Weekly Insight Cards)
    // Caption: "Automatic Mood Tracking from Your Words"
    func test03_Insights() throws {
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5))
        insightsTab.tap()
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "03_Insights"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 4: Digital Twin Emotions
    // Caption: "9 Emotions Tracked. Zero Manual Input."
    func test04_DigitalTwinEmotions() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(1)

        // Scroll to emotions section or tap emotions segment
        let emotionsButton = app.buttons["Emotions"]
        if emotionsButton.waitForExistence(timeout: 3) {
            emotionsButton.tap()
            sleep(1)
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "04_DigitalTwinEmotions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 5: Timeline
    // Caption: "Search Across All Your Entries Instantly"
    func test05_Timeline() throws {
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        timelineTab.tap()
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "05_Timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 6: Digital Twin Knowledge Graph / My World
    // Caption: "People, Places & Topics — Your Knowledge Graph"
    func test06_DigitalTwinWorld() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(1)

        let worldButton = app.buttons["My World"]
        if worldButton.waitForExistence(timeout: 3) {
            worldButton.tap()
            sleep(1)
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "06_DigitalTwinWorld"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 7: Entry Detail with Photos
    // Caption: "8 Themes. Face ID Lock. Encrypted Backups."
    func test07_EntryDetail() throws {
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        timelineTab.tap()
        sleep(1)

        // Tap first entry
        let firstEntry = app.cells.firstMatch
        if firstEntry.waitForExistence(timeout: 3) {
            firstEntry.tap()
            sleep(1)
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "07_EntryDetail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 8: Settings / Privacy
    // Caption: "100% On-Device. Your Diary Never Leaves Your Phone."
    func test08_Settings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "08_Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
