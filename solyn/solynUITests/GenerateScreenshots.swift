//
//  GenerateScreenshots.swift
//  solynUITests
//
//  Automated App Store screenshot generation.
//  Seeds realistic data via -ScreenshotMode launch argument,
//  then navigates each screen and captures screenshots.
//
//  Usage:
//  xcodebuild test -scheme solyn \
//    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
//    -only-testing:solynUITests/ScreenshotTests \
//    -resultBundlePath ./screenshots.xcresult
//

import XCTest

class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["-UITesting", "-ScreenshotMode"]
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        app.launch()
    }

    // MARK: - Screenshot 1: Today View

    func test01_TodayView() throws {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()
        sleep(2)
        takeScreenshot(named: "01_TodayView")
    }

    // MARK: - Screenshot 2: Timeline

    func test02_Timeline() throws {
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        timelineTab.tap()
        sleep(2)
        takeScreenshot(named: "02_Timeline")
    }

    // MARK: - Screenshot 3: Insights

    func test03_Insights() throws {
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5))
        insightsTab.tap()
        sleep(2)

        // Dismiss the milestone overlay if it appears
        let keepGoingButton = app.buttons["Keep Going"]
        if keepGoingButton.waitForExistence(timeout: 3) {
            keepGoingButton.tap()
            sleep(1)
        }

        takeScreenshot(named: "03_Insights")
    }

    // MARK: - Screenshot 4: Digital Twin Overview

    func test04_DigitalTwin() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(2)
        takeScreenshot(named: "04_DigitalTwin")
    }

    // MARK: - Screenshot 5: Digital Twin Emotions

    func test05_DigitalTwinEmotions() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(1)

        let emotionsButton = app.buttons["Emotions"]
        if emotionsButton.waitForExistence(timeout: 3) {
            emotionsButton.tap()
            sleep(2)
        }
        takeScreenshot(named: "05_DigitalTwinEmotions")
    }

    // MARK: - Screenshot 6: Digital Twin My World

    func test06_DigitalTwinWorld() throws {
        let twinTab = app.tabBars.buttons["Twin"]
        XCTAssertTrue(twinTab.waitForExistence(timeout: 5))
        twinTab.tap()
        sleep(1)

        // "My World" is the 4th button in a horizontal ScrollView — swipe left to reveal it
        let emotionsButton = app.buttons["Emotions"]
        if emotionsButton.waitForExistence(timeout: 3) {
            emotionsButton.swipeLeft()
            sleep(1)
        }

        let worldButton = app.buttons["My World"]
        if worldButton.waitForExistence(timeout: 3) {
            worldButton.tap()
            sleep(2)
        }
        takeScreenshot(named: "06_DigitalTwinWorld")
    }

    // MARK: - Screenshot 7: Entry Detail

    func test07_EntryDetail() throws {
        let timelineTab = app.tabBars.buttons["Timeline"]
        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        timelineTab.tap()
        sleep(2)

        // Tap the first NavigationLink row containing entry text
        let firstLink = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "cherry blossoms")).firstMatch
        if firstLink.waitForExistence(timeout: 3) {
            firstLink.tap()
        } else {
            // Fallback: tap first cell-like element in the list
            let staticTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "cherry blossoms"))
            if staticTexts.firstMatch.waitForExistence(timeout: 3) {
                staticTexts.firstMatch.tap()
            }
        }
        sleep(2)
        takeScreenshot(named: "07_EntryDetail")
    }

    // MARK: - Screenshot 8: Settings

    func test08_Settings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        sleep(2)
        takeScreenshot(named: "08_Settings")
    }

    // MARK: - Helpers

    private func takeScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
