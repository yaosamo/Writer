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
        XCTAssertTrue(app.buttons["Restore"].exists)
        attachScreenshot(app, "Paywall")

        // No close button: the sheet is dismissed by swiping down
        app.swipeDown(velocity: .fast)
        XCTAssertFalse(app.staticTexts["Nothing Pro"].waitForExistence(timeout: 3))
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

    // Smart lists and tasks while typing
    func testListsAndTasks() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["New"].tap()
        app.buttons["New Note"].tap()
        app.buttons["Untitled"].firstMatch.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()

        // Return continues the list; Return on an empty item ends it
        editor.typeText("- milk\nbread\n\nAfter\n")
        // "[] " becomes a task, which continues on Return
        editor.typeText("[] call mom\nwater plants")
        attachScreenshot(app, "Lists and tasks")

        XCTAssertEqual(editor.value as? String, "- milk\n- bread\nAfter\n[ ] call mom\n[ ] water plants")

        // Tapping the first task's box completes it
        app.buttons["Hide keyboard"].tap()
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 42, dy: 365)).tap()
        attachScreenshot(app, "Task done")
        XCTAssertEqual(editor.value as? String, "- milk\n- bread\nAfter\n[x] call mom\n[ ] water plants")
    }

    // Long-press a note → Move to → New Folder: the folder is created around the note
    func testMoveToNewFolder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-debugProUnlocked", "YES", "-demoContent", "YES"]
        app.launch()
        app.buttons["Reading list"].firstMatch.press(forDuration: 1.2)
        app.buttons["Move to"].tap()
        app.buttons["New Folder"].tap()
        let name = app.textFields["Folder name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "Errands\n")
        XCTAssertTrue(app.staticTexts["Errands"].waitForExistence(timeout: 5))
        attachScreenshot(app, "Moved to new folder")
        // The note now sits below its new folder
        let folder = app.staticTexts["Errands"].frame
        let note = app.buttons["Reading list"].firstMatch.frame
        XCTAssertGreaterThan(note.minY, folder.minY)
        XCTAssertGreaterThan(note.minX, folder.minX - 1)
    }

    private func samplePhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1000)).image { context in
            let colors = [UIColor(red: 0.85, green: 0.42, blue: 0.16, alpha: 1).cgColor, UIColor(red: 0.12, green: 0.05, blue: 0.03, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1600, y: 1000), options: [])
        }
    }

    // Pasting an image (Pro): shows inline, tap opens it full size
    func testPasteImage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-debugProUnlocked", "YES"]
        app.launch()
        app.buttons["New"].tap()
        app.buttons["New Note"].tap()
        app.buttons["Untitled"].firstMatch.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Trip\n")

        UIPasteboard.general.image = samplePhoto()
        editor.typeKey("v", modifierFlags: .command)
        sleep(2)
        editor.typeText("Below the photo")
        attachScreenshot(app, "Pasted image")
        let stored = editor.value as? String ?? ""
        XCTAssertTrue(stored.hasPrefix("Trip\n"), "Text before the image stays: \(stored.debugDescription)")
        XCTAssertTrue(stored.hasSuffix("\nBelow the photo"))

        // The stored note keeps a token line, and the list title skips it
        app.buttons["Hide keyboard"].tap()
        let frame = editor.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.minY + 120)).tap()
        XCTAssertTrue(app.images["Image"].waitForExistence(timeout: 5), "Tapping the image opens the full-size view")
        sleep(1)
        attachScreenshot(app, "Image preview")
        app.images["Image"].tap()
        XCTAssertFalse(app.images["Image"].waitForExistence(timeout: 2))
    }

    // Free users see the paywall instead of an image
    func testPasteImageNeedsPro() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["New"].tap()
        app.buttons["New Note"].tap()
        app.buttons["Untitled"].firstMatch.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Trip\n")
        UIPasteboard.general.image = samplePhoto()
        editor.typeKey("v", modifierFlags: .command)
        sleep(2)
        attachScreenshot(app, "Free paste")
        XCTAssertTrue(app.staticTexts["Nothing Pro"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
