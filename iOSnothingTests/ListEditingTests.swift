//
//  ListEditingTests.swift
//  iOSnothingTests
//

import XCTest
@testable import Nothing

final class ListEditingTests: XCTestCase {

    // Applies a keystroke the way the editors do: smart edit if any, else the keystroke itself
    private func type(_ replacement: String, in text: String, at caret: Int, deleting length: Int = 0) -> (String, Int) {
        let ns = text as NSString
        let range = NSRange(location: caret - length, length: length)
        if let edit = ListEditing.edit(in: ns, range: range, replacement: replacement) {
            return (ns.replacingCharacters(in: edit.range, with: edit.replacement), edit.selection.location)
        }
        return (ns.replacingCharacters(in: range, with: replacement), range.location + (replacement as NSString).length)
    }

    func testReturnContinuesBulletList() {
        let (text, caret) = type("\n", in: "- milk", at: 6)
        XCTAssertEqual(text, "- milk\n- ")
        XCTAssertEqual(caret, 9)
    }

    func testReturnKeepsIndent() {
        let (text, _) = type("\n", in: "  - milk", at: 8)
        XCTAssertEqual(text, "  - milk\n  - ")
    }

    func testReturnOnEmptyItemEndsList() {
        let (text, caret) = type("\n", in: "- milk\n- ", at: 9)
        XCTAssertEqual(text, "- milk\n")
        XCTAssertEqual(caret, 7)
    }

    func testReturnOnPlainLineIsUntouched() {
        XCTAssertNil(ListEditing.edit(in: "milk" as NSString, range: NSRange(location: 4, length: 0), replacement: "\n"))
    }

    func testBackspaceAfterMarkerRemovesWholeMarker() {
        let (text, caret) = type("", in: "- milk\n- ", at: 9, deleting: 1)
        XCTAssertEqual(text, "- milk\n")
        XCTAssertEqual(caret, 7)
    }

    func testBackspaceInsideTextIsNormal() {
        let (text, _) = type("", in: "- milk", at: 6, deleting: 1)
        XCTAssertEqual(text, "- mil")
    }

    func testBracketsAndSpaceMakeATask() {
        let (text, caret) = type(" ", in: "[]", at: 2)
        XCTAssertEqual(text, "[ ] ")
        XCTAssertEqual(caret, 4)
    }

    func testReturnOnTaskContinuesWithOpenTask() {
        let (text, _) = type("\n", in: "[x] call mom", at: 12)
        XCTAssertEqual(text, "[x] call mom\n[ ] ")
    }

    func testToggleTask() {
        let text = "[ ] call mom" as NSString
        let edit = ListEditing.toggleTask(in: text, at: 1)
        XCTAssertEqual(edit.map { text.replacingCharacters(in: $0.range, with: $0.replacement) }, "[x] call mom")
        let done = "[x] call mom" as NSString
        let undo = ListEditing.toggleTask(in: done, at: 0)
        XCTAssertEqual(undo.map { done.replacingCharacters(in: $0.range, with: $0.replacement) }, "[ ] call mom")
        XCTAssertNil(ListEditing.toggleTask(in: text, at: 6), "Only the box toggles")
    }

    func testLinksAreDetected() {
        let storage = NSTextStorage(string: "see apple.com and https://lab01.dev today")
        ListStyler(text: .black, dim: .gray).apply(to: storage, range: NSRange(location: 0, length: storage.length))
        var links: [String] = []
        storage.enumerateAttribute(.noteLink, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if value != nil { links.append((storage.string as NSString).substring(with: range)) }
        }
        XCTAssertEqual(links, ["apple.com", "https://lab01.dev"])
    }

    func testStyles() {
        let text = "intro\n- a\n[x] done\n[ ] open" as NSString
        let styles = ListEditing.styles(in: text, range: NSRange(location: 0, length: text.length))
        XCTAssertEqual(styles.markers.map { text.substring(with: $0) }, ["- ", "[x] ", "[ ] "])
        XCTAssertEqual(styles.done.map { text.substring(with: $0) }, ["done"])
    }
}
