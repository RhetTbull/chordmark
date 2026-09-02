import XCTest

final class ChordmarkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesFormatsAndDismissesWithReturn() {
        let app = launchIntoCapture()
        let panel = app.windows["Capture Shortcut"]
        XCTAssertTrue(panel.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["copyShortcutButton"].isEnabled)

        app.typeKey("g", modifierFlags: [.shift, .command])

        XCTAssertTrue(app.staticTexts["Captured shortcut ⇧⌘G"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["copyShortcutButton"].isEnabled)

        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        XCTAssertFalse(panel.waitForExistence(timeout: 0.5))
    }

    @MainActor
    func testEscapeDismissesWithoutCapturing() {
        let app = launchIntoCapture()
        let panel = app.windows["Capture Shortcut"]
        XCTAssertTrue(panel.waitForExistence(timeout: 2))

        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertFalse(panel.waitForExistence(timeout: 0.5))
    }

    @MainActor
    private func launchIntoCapture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--show-capture"]
        app.launch()
        return app
    }
}
