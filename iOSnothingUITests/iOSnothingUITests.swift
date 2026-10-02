//
//  iOSnothingUITests.swift
//  iOSnothingUITests
//
//  Created by Yaroslav Samoylov on 1/21/22.
//

import XCTest

class iOSnothingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Create a note, type into it, go back and confirm the list shows its first line
    func testCreateNoteTypeAndReturn() throws {
        let app = XCUIApplication()
        app.launch()
        attachScreenshot(app, "1 List")

        app.buttons["New note"].tap()
        let newRow = app.buttons["Untitled"].firstMatch
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        attachScreenshot(app, "2 Empty editor")

        editor.tap()
        editor.typeText("Groceries\n- milk\n- bread")
        attachScreenshot(app, "3 Typing")

        // Tapping inside the text again (to move the caret) must keep the keyboard up
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.01)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Tapping the editor dismissed the keyboard")

        app.buttons["Hide keyboard"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Groceries"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(app, "4 List after edit")
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
