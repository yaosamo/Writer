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
        XCUIDevice.shared.orientation = .portrait
    }

    // Create a note, type into it, go back and confirm the list shows its first line
    func testCreateNoteTypeAndReturn() throws {
        let app = XCUIApplication()
        app.launch()
        attachScreenshot(app, "1 List")

        app.buttons["New"].tap()
        app.buttons["New Note"].tap()
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

    // Free users see the paywall when they try a Pro feature
    func testFreeUserSeesPaywallForFolders() throws {
        let app = XCUIApplication()
        app.launch()

        // + offers New Folder, marked Pro for free users
        app.buttons["New"].tap()
        app.buttons["New Folder · Pro"].tap()

        XCTAssertTrue(app.staticTexts["Nothing Pro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore purchase"].exists)
        attachScreenshot(app, "Paywall")

        app.buttons["Close"].tap()
        XCTAssertFalse(app.staticTexts["Nothing Pro"].waitForExistence(timeout: 2))
    }

    // Pro: create a folder, file a note into it, switch theme
    func testProFoldersAndThemes() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-debugProUnlocked", "YES"]
        app.launch()

        app.buttons["New"].tap()
        app.buttons["New Folder"].tap()
        // The new folder appears in the list with its name field focused
        let nameField = app.textFields["Folder name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "Ideas\n")
        XCTAssertTrue(app.staticTexts["Ideas"].waitForExistence(timeout: 5))
        attachScreenshot(app, "Folder named inline")

        app.buttons["New"].tap()
        app.buttons["New Note"].tap()
        let note = app.buttons["Untitled"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.press(forDuration: 1.2)
        app.buttons["Move to"].tap()
        app.buttons["Ideas"].tap()
        attachScreenshot(app, "Note filed in folder")

        app.buttons["More"].tap()
        app.buttons["Theme"].tap()
        app.buttons["Dark Sepia"].tap()
        attachScreenshot(app, "Dark Sepia")
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
