//
//  ChordmarkUITestsLaunchTests.swift
//  ChordmarkUITests
//
//  Created by Rhet Turnbull on 9/2/26.
//

import XCTest

final class ChordmarkUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-capture"]
        app.launch()

        XCTAssertTrue(app.windows["Capture Shortcut"].waitForExistence(timeout: 2))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
