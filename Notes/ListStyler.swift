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

extension NSAttributedString.Key {
    // A detected URL in note text (opened with ⌘-click on macOS); the text stays plain
    static let noteLink = NSAttributedString.Key("NothingNoteLink")
}

struct ListStyler {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    var text: PlatformColor
    var dim: PlatformColor
    // Base paragraph style (line spacing); image lines get extra room around them
    var paragraph: NSParagraphStyle = .default

    private var imageParagraph: NSParagraphStyle {
        let style = (paragraph.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 10
        style.paragraphSpacing = 14
        return style
    }

    // Restyles the whole lines touched by `range`
    func apply(to storage: NSTextStorage, range: NSRange) {
        let ns = storage.string as NSString
        guard ns.length > 0 else { return }
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: ns.length))
        let lines = ns.lineRange(for: clamped)
        storage.addAttribute(.foregroundColor, value: text, range: lines)
        storage.removeAttribute(.strikethroughStyle, range: lines)
        storage.addAttribute(.paragraphStyle, value: paragraph, range: lines)
        storage.removeAttribute(.noteLink, range: lines)

        // URLs look like the text around them; hover dims them, ⌘-click opens them
        Self.linkDetector?.enumerateMatches(in: storage.string, range: lines) { match, _, _ in
            guard let match, let url = match.url else { return }
            storage.addAttribute(.noteLink, value: url, range: match.range)
        }

        // Lines holding an image get a little space above and below
        var search = lines
        while true {
            let found = ns.range(of: ImageToken.attachmentCharacter, options: [], range: search)
            guard found.location != NSNotFound else { break }
            storage.addAttribute(.paragraphStyle, value: imageParagraph, range: ns.paragraphRange(for: found))
            let next = NSMaxRange(found)
            search = NSRange(location: next, length: NSMaxRange(lines) - next)
        }

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
