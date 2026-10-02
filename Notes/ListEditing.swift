//
//  ListEditing.swift
//  Notes
//
//  Smart lists and tasks for plain text, shared by the macOS and iOS editors.
//  Notes stay plain text: "- item", "[ ] task", "[x] done task".
//

import Foundation

enum ListEditing {

    // A replacement the editor should apply instead of the user's keystroke
    struct Edit: Equatable {
        let range: NSRange
        let replacement: String
        let selection: NSRange
    }

    enum Marker: Equatable {
        case bullet      // "- "
        case task        // "[ ] "
        case doneTask    // "[x] "

        var text: String {
            switch self {
            case .bullet: "- "
            case .task: "[ ] "
            case .doneTask: "[x] "
            }
        }

        // What the next line gets when pressing Return
        var continuation: Marker { self == .bullet ? .bullet : .task }
    }

    struct LinePrefix: Equatable {
        let lineRange: NSRange      // the whole line, without its newline
        let indent: String          // leading spaces / tabs
        let marker: Marker?

        var markerRange: NSRange? {
            guard let marker else { return nil }
            return NSRange(location: lineRange.location + (indent as NSString).length, length: (marker.text as NSString).length)
        }
        var contentStart: Int { lineRange.location + (indent as NSString).length + ((marker?.text ?? "") as NSString).length }
    }

    // MARK: Parsing

    static func line(at index: Int, in text: NSString) -> LinePrefix {
        let safe = min(max(index, 0), text.length)
        var start = 0, end = 0, contentsEnd = 0
        text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: safe, length: 0))
        let range = NSRange(location: start, length: contentsEnd - start)
        let line = text.substring(with: range) as NSString

        var i = 0
        while i < line.length, let scalar = UnicodeScalar(line.character(at: i)), scalar == " " || scalar == "\t" { i += 1 }
        let indent = line.substring(to: i)
        let rest = line.substring(from: i)
        let marker: Marker?
        if rest.hasPrefix("- ") { marker = .bullet }
        else if rest.hasPrefix("[ ] ") { marker = .task }
        else if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") { marker = .doneTask }
        else { marker = nil }
        return LinePrefix(lineRange: range, indent: indent, marker: marker)
    }

    // MARK: Typing

    // Called before `replacement` replaces `range`. Returns an edit to apply instead, or nil
    // to let the keystroke through unchanged.
    static func edit(in text: NSString, range: NSRange, replacement: String) -> Edit? {
        if replacement == "\n", range.length == 0 {
            return returnKey(in: text, at: range.location)
        }
        if replacement.isEmpty, range.length == 1 {
            return backspace(in: text, deleting: range)
        }
        if replacement == " ", range.length == 0 {
            return taskShortcut(in: text, at: range.location)
        }
        return nil
    }

    // Return on a list line continues the list; on an empty item it ends the list
    private static func returnKey(in text: NSString, at caret: Int) -> Edit? {
        let prefix = line(at: caret, in: text)
        guard let marker = prefix.marker, caret >= prefix.contentStart else { return nil }

        let content = text.substring(with: NSRange(location: prefix.contentStart, length: NSMaxRange(prefix.lineRange) - prefix.contentStart))
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            // Empty item: remove the marker and stay on this line
            let remove = NSRange(location: prefix.lineRange.location, length: NSMaxRange(prefix.lineRange) - prefix.lineRange.location)
            return Edit(range: remove, replacement: "", selection: NSRange(location: prefix.lineRange.location, length: 0))
        }
        let insert = "\n" + prefix.indent + marker.continuation.text
        return Edit(range: NSRange(location: caret, length: 0), replacement: insert,
                    selection: NSRange(location: caret + (insert as NSString).length, length: 0))
    }

    // Backspace right after a marker deletes the whole marker, like a list in a word processor
    private static func backspace(in text: NSString, deleting range: NSRange) -> Edit? {
        let caret = NSMaxRange(range)
        let prefix = line(at: range.location, in: text)
        guard let markerRange = prefix.markerRange, caret == NSMaxRange(markerRange) else { return nil }
        return Edit(range: markerRange, replacement: "", selection: NSRange(location: markerRange.location, length: 0))
    }

    // "[]" followed by a space at the start of a line becomes a task
    private static func taskShortcut(in text: NSString, at caret: Int) -> Edit? {
        let prefix = line(at: caret, in: text)
        guard prefix.marker == nil else { return nil }
        let start = prefix.lineRange.location + (prefix.indent as NSString).length
        guard caret - start == 2, text.substring(with: NSRange(location: start, length: 2)) == "[]" else { return nil }
        let task = Marker.task.text
        return Edit(range: NSRange(location: start, length: 2), replacement: task,
                    selection: NSRange(location: start + (task as NSString).length, length: 0))
    }

    // MARK: Tasks

    // Toggles the task whose "[ ]" / "[x]" contains `index`; nil if there's none
    static func toggleTask(in text: NSString, at index: Int) -> Edit? {
        let prefix = line(at: index, in: text)
        guard let markerRange = prefix.markerRange, prefix.marker != .bullet,
              index >= markerRange.location, index < NSMaxRange(markerRange) - 1 else { return nil }
        let box = NSRange(location: markerRange.location, length: 3)
        let replacement = prefix.marker == .task ? "[x]" : "[ ]"
        return Edit(range: box, replacement: replacement, selection: NSRange(location: NSMaxRange(prefix.lineRange), length: 0))
    }

    // MARK: Styling

    struct Styles {
        var markers: [NSRange] = []   // "- " / "[ ]" / "[x]": dimmed
        var done: [NSRange] = []      // text of completed tasks: dimmed and struck through
    }

    // Ranges to style within `range` (expanded to whole lines)
    static func styles(in text: NSString, range: NSRange) -> Styles {
        var styles = Styles()
        let lines = text.lineRange(for: range)
        var location = lines.location
        while location < NSMaxRange(lines) {
            let prefix = line(at: location, in: text)
            if let markerRange = prefix.markerRange {
                styles.markers.append(markerRange)
                if prefix.marker == .doneTask, NSMaxRange(prefix.lineRange) > prefix.contentStart {
                    styles.done.append(NSRange(location: prefix.contentStart, length: NSMaxRange(prefix.lineRange) - prefix.contentStart))
                }
            }
            let next = NSMaxRange(text.lineRange(for: NSRange(location: location, length: 0)))
            if next <= location { break }
            location = next
        }
        return styles
    }
}
