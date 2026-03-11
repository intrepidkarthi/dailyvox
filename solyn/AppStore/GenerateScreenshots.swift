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
    func test01_TodayView() throws {
        // Navigate to Today tab
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        // Wait for view to load
        sleep(1)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "01_TodayView"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 2: Digital Twin
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

    // MARK: - Screenshot 3: Insights
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

    // MARK: - Screenshot 4: Timeline
    func test04_Timeline() throws {
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        timelineTab.tap()

        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "04_Timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screenshot 5: Settings
    func test05_Settings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "05_Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
