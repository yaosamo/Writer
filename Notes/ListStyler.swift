//
//  ListStyler.swift
//  Notes
//
//  Applies list / task styling to an editor's text storage. Attributes only:
//  the text, font and line height never change.
//

#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

struct ListStyler {
    var text: PlatformColor
    var dim: PlatformColor

    // Restyles the whole lines touched by `range`
    func apply(to storage: NSTextStorage, range: NSRange) {
        let ns = storage.string as NSString
        guard ns.length > 0 else { return }
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: ns.length))
        let lines = ns.lineRange(for: clamped)
        storage.addAttribute(.foregroundColor, value: text, range: lines)
        storage.removeAttribute(.strikethroughStyle, range: lines)

        let styles = ListEditing.styles(in: ns, range: lines)
        for marker in styles.markers {
            storage.addAttribute(.foregroundColor, value: dim, range: marker)
        }
        for done in styles.done {
            storage.addAttributes([
                .foregroundColor: dim,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: dim,
            ], range: done)
        }
    }
}
