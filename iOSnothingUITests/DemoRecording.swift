//
//  DemoRecording.swift
//  iOSnothingUITests
//
//  Scripted walkthroughs for App Store previews and the website. Skipped in normal
//  test runs; run with TEST_RUNNER_RECORD_DEMO=1 while recording the simulator.
//

import XCTest

final class DemoRecording: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RECORD_DEMO"] == "1", "Demo recording only")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(pro: Bool = true) {
        app = XCUIApplication()
        app.launchArguments += ["-demoContent", "YES", "-demoPrice", "$9.99"]
        if pro { app.launchArguments += ["-debugProUnlocked", "YES"] }
        app.launch()
        pause(1.5)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func type(_ text: String, into element: XCUIElement) {
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            element.typeText(String(word) + " ")
        }
    }

    func testWrite() {
        launch()
        app.buttons["New"].tap(); pause(0.6)
        app.buttons["New Note"].tap(); pause(0.8)
        app.buttons["Untitled"].firstMatch.tap(); pause(0.8)
        let editor = app.textViews.firstMatch
        editor.tap(); pause(0.4)
        type("Nothing here but words.\n\nNo bold, no bullets, no noise. Just the page and an orange caret.", into: editor)
        pause(1.2)
        app.buttons["Hide keyboard"].tap(); pause(0.8)
        app.buttons["Back"].tap(); pause(1.5)
    }

    func testFolders() {
        launch()
        app.staticTexts["Novel"].tap(); pause(1.2)
        app.staticTexts["Novel"].tap(); pause(1.0)
        app.buttons["New"].tap(); pause(0.6)
        app.buttons["New Folder"].tap(); pause(0.8)
        let name = app.textFields["Folder name"]
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        type("Poems", into: name); name.typeText("\n"); pause(1.2)
        app.buttons["Chapter one"].firstMatch.tap(); pause(3)
        app.buttons["Back"].tap(); pause(1)
    }

    func testThemes() {
        launch()
        for theme in ["Dark Sepia", "Midnight", "Light", "Dark"] {
            app.buttons["More"].tap(); pause(0.5)
            app.buttons["Theme"].tap(); pause(0.5)
            app.buttons[theme].tap(); pause(1.8)
        }
    }

    func testLists() {
        launch()
        app.buttons["New"].tap(); pause(0.6)
        app.buttons["New Note"].tap(); pause(0.8)
        app.buttons["Untitled"].firstMatch.tap(); pause(0.8)
        let editor = app.textViews.firstMatch
        editor.tap(); pause(0.4)
        type("Groceries\n- milk\nbread\napples\n\n", into: editor)
        type("[] call mom\nwater the plants", into: editor)
        pause(0.8)
        app.buttons["Hide keyboard"].tap(); pause(0.8)
        // tick the first task
        let frame = editor.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.minX + 18, dy: frame.minY + 150)).tap()
        pause(2.5)
    }

    func testImages() {
        launch()
        app.buttons["New"].tap(); pause(0.6)
        app.buttons["New Note"].tap(); pause(0.8)
        app.buttons["Untitled"].firstMatch.tap(); pause(0.8)
        let editor = app.textViews.firstMatch
        editor.tap(); pause(0.4)
        type("Lisbon, day one\n", into: editor)
        if let path = ProcessInfo.processInfo.environment["DEMO_IMAGE"], let image = UIImage(contentsOfFile: path) {
            UIPasteboard.general.image = image
        }
        editor.typeKey("v", modifierFlags: .command); pause(2.0)
        type("Warm light, slow afternoon.", into: editor)
        pause(0.8)
        app.buttons["Hide keyboard"].tap(); pause(0.8)
        let frame = editor.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.minY + 130)).tap()
        pause(2.5)
        app.images["Image"].tap(); pause(1.2)
    }

    func testMoveToFolder() {
        launch()
        app.buttons["Reading list"].firstMatch.press(forDuration: 1.0); pause(0.6)
        app.buttons["Move to"].tap(); pause(0.6)
        app.buttons["New Folder"].tap(); pause(0.6)
        let name = app.textFields["Folder name"]
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        type("Books", into: name); name.typeText("\n")
        pause(2.5)
    }

    func testPro() {
        launch(pro: false)
        app.buttons["New"].tap(); pause(0.6)
        app.buttons["New Folder · Pro"].tap(); pause(4)
    }
}
