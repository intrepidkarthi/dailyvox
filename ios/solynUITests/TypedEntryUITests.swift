import XCTest

/// "I can't talk right now" on Today: the persistent typed entry.
///
/// Asked for by a user who journals at work and at home, around people, where
/// speaking out loud is not an option. Until 1.12 the typed path existed only in
/// onboarding, so after the first entry the app was voice or nothing.
final class TypedEntryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTypeAnEntryFromToday() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-hasCompletedOnboarding", "YES",
                                "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let link = app.buttons["Type an entry instead"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "the typed-entry link is missing from Today")
        attach(app, "1-today")
        link.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "the composer did not open")
        editor.tap()
        let words = "Quiet lunch with Priya. Typed, because the office was full."
        editor.typeText(words)
        attach(app, "2-composer")

        app.buttons["Save"].tap()
        XCTAssertFalse(editor.waitForExistence(timeout: 2), "the composer did not close after Save")

        let saved = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Quiet lunch with Priya")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "the typed entry is not on Today")
        attach(app, "3-saved")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
