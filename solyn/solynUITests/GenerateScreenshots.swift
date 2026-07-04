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

    // MARK: - Navigation Helper

    /// Navigate to a tab by name. Handles both iPhone (bottom tab bar) and iPad (top tab bar / sidebar) layouts.
    /// Uses .firstMatch to handle iPadOS where tab buttons appear as nested duplicates.
    private func navigateToTab(_ name: String) {
        // Try iPhone bottom tab bar first
        let tabButton = app.tabBars.buttons[name]
        if tabButton.waitForExistence(timeout: 3) {
            tabButton.tap()
            return
        }

        // iPad: buttons may exist outside tabBars (top tab bar or sidebar).
        // Use .firstMatch to avoid "multiple matches" error from nested button elements.
        let button = app.buttons[name].firstMatch
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }

        // Fallback: look for a static text and tap it
        let text = app.staticTexts[name].firstMatch
        if text.waitForExistence(timeout: 3) {
            text.tap()
            return
        }

        XCTFail("Could not find tab: \(name)")
    }

    // MARK: - Screenshot 0: Onboarding — "Speak your first star" (voice-first)

    func test00_OnboardingFlow() throws {
        // -OnboardingDemo autoplays invite → speak → star born → claim with
        // synthetic audio, so we can capture the moment without a mic.
        app.terminate()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-OnboardingDemo",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        sleep(4)   // live waveform — "How was your day, really?"
        takeScreenshot(named: "OB1_Speak")
        sleep(6)   // star ignition — "A star is born"
        takeScreenshot(named: "OB2_StarBorn")
        sleep(3)   // claim — "That star is yours"
        takeScreenshot(named: "OB3_Claim")
    }

    // MARK: - Screenshot 1: Today View

    func test01_TodayView() throws {
        navigateToTab("Record")
        sleep(2)
        takeScreenshot(named: "01_TodayView")
    }

    // MARK: - Screenshot 2: Timeline

    func test02_Timeline() throws {
        navigateToTab("Journal")
        sleep(2)
        takeScreenshot(named: "02_Timeline")
    }

    // MARK: - Screenshot 3: Insights

    func test03_Insights() throws {
        navigateToTab("Insights")
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
        navigateToTab("Twin")
        sleep(2)
        takeScreenshot(named: "04_DigitalTwin")
    }

    // MARK: - Screenshot 5: Digital Twin Emotions

    func test05_DigitalTwinEmotions() throws {
        navigateToTab("Twin")
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
        navigateToTab("Twin")
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
        navigateToTab("Journal")
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
        navigateToTab("Settings")
        sleep(2)
        takeScreenshot(named: "08_Settings")
    }

    // MARK: - Screenshot 10: Twin tab — Body Twin card

    func test10_TwinTabBodyCard() throws {
        navigateToTab("Twin")
        sleep(2)

        // BodyTwinCard sits below the orb header / Ask / Twin Resolution —
        // scroll until it is on screen, then lift it clear of the tab bar.
        let bodyCard = app.staticTexts["Body Twin"].firstMatch
        scrollUntilHittable(bodyCard)
        liftAboveTabBar()
        takeScreenshot(named: "10_Twin_BodyCard")
    }

    // MARK: - Screenshot 11: Review-before-learning sheet (2 pending)

    func test11_BodyReviewSheet() throws {
        navigateToTab("Twin")
        sleep(2)

        let bodyCard = app.staticTexts["Body Twin"].firstMatch
        scrollUntilHittable(bodyCard)
        XCTAssertTrue(bodyCard.waitForExistence(timeout: 3), "Body Twin card not found on Twin tab")
        bodyCard.tap()
        sleep(2)

        XCTAssertTrue(app.staticTexts["Your body had a say"].waitForExistence(timeout: 3),
                      "Review sheet did not open")
        takeScreenshot(named: "11_Twin_ReviewSheet")
    }

    // MARK: - Screenshot 12: Settings — Health section

    func test12_SettingsHealth() throws {
        navigateToTab("Settings")
        sleep(2)

        // Anchor on the section's last row, then nudge so the master toggle
        // (section top) sits just under the nav bar — whole section framed.
        let wipeButton = app.buttons["Wipe All Health Snapshots"].firstMatch
        scrollUntilHittable(wipeButton, maxSwipes: 8)
        let masterToggle = app.staticTexts["Body Twin"].firstMatch
        let topY = masterToggle.frame.minY
        if topY < 140 {
            nudgeContentDown(by: 150 - topY)
        }
        takeScreenshot(named: "12_Settings_Health")
    }

    // MARK: - Screenshot 13: Today idle — body whisper

    func test13_TodayWhisper() throws {
        navigateToTab("Record")
        sleep(3)   // whisper computes in TodayView's .task
        takeScreenshot(named: "13_Today_Whisper")
    }

    // MARK: - Screenshot 14: Insights — Body & Mood card

    func test14_InsightsBodyMood() throws {
        navigateToTab("Insights")
        sleep(2)

        let keepGoingButton = app.buttons["Keep Going"]
        if keepGoingButton.waitForExistence(timeout: 3) {
            keepGoingButton.tap()
            sleep(1)
        }

        // Scroll to the card's footer line so the whole card is framed.
        let footer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "a noticing, not a prescription")).firstMatch
        scrollUntilHittable(footer, maxSwipes: 10)
        liftAboveTabBar()
        takeScreenshot(named: "14_Insights_BodyMood")
    }

    // MARK: - Screenshot 15: Today idle — one-time Health invite

    func test15_TodayInviteCard() throws {
        // Relaunch in the not-yet-authorized state (same pattern as
        // test00's -OnboardingDemo relaunch).
        app.terminate()
        app.launchArguments = ["-UITesting", "-ScreenshotMode", "-BodyTwinInviteDemo",
                               "-hasCompletedOnboarding", "YES",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        navigateToTab("Record")
        sleep(2)
        XCTAssertTrue(app.staticTexts["Your Twin can learn what your body felt"]
            .waitForExistence(timeout: 5), "Invite card not shown under -BodyTwinInviteDemo")
        takeScreenshot(named: "15_Today_InviteCard")
    }

    // MARK: - Helpers

    /// Swipes up until `element` reports hittable (or swipes run out).
    private func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 4) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
            sleep(1)
        }
    }

    /// Gentle partial scroll (~30% of the screen) so a just-revealed card sits
    /// clear of the floating tab bar; slow velocity + hold suppress inertia.
    private func liftAboveTabBar() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        start.press(forDuration: 0.1, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        sleep(1)
    }

    /// Reverse-scrolls by an exact number of points (drag downward), used to
    /// re-reveal content that a full swipe carried off the top.
    private func nudgeContentDown(by points: CGFloat) {
        guard points > 0 else { return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = start.withOffset(CGVector(dx: 0, dy: points))
        start.press(forDuration: 0.1, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        sleep(1)
    }

    private func takeScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
