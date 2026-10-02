//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI
import CoreData


struct EditorView: View {

    // Coredata for saving / updating viewContext
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.palette) private var palette

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item
    // New notes start with the caret in the text
    var focusOnAppear = false

    var body: some View {
        NoteTextView(text: $item.noteText, palette: palette, focusOnAppear: focusOnAppear) {
            EditorHeader(item: item, palette: palette)
        }
        // Debounced save: restarts on every change, saves after a pause in typing
        .task(id: [item.title, item.note]) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            viewContext.saveIfNeeded()
        }
        .onDisappear {
            viewContext.saveIfNeeded()
        }
    }
}

// Title and date above the text. Lives inside the text view so it scrolls with the note
private struct EditorHeader: View {
    @ObservedObject var item: Item
    let palette: Palette

    var body: some View {
        HStack {
            TextField("Title", text: $item.titleText)
                .textFieldStyle(PlainTextFieldStyle())
            Text("\(item.date ?? Date(), formatter: itemFormatter)")
                .padding(.leading, 24.0)
        }
        .font(.system(size: 14, weight: Font.Weight.thin, design: .monospaced))
        .foregroundColor(palette.secondaryText)
        .padding(.horizontal, NoteTextViewMetrics.horizontalInset)
        .frame(height: NoteTextViewMetrics.headerHeight)
    }
}

enum NoteTextViewMetrics {
    static let horizontalInset: CGFloat = 72
    // Space above the text for the header; also used as bottom padding
    static let headerHeight: CGFloat = 176
}


// One scroll view for the whole note: an NSTextView whose top inset holds the header.
// (A SwiftUI TextEditor inside a ScrollView gave two nested scrolls that fought each other.)
struct NoteTextView<Header: View>: NSViewRepresentable {
    @Binding var text: String
    let palette: Palette
    var focusOnAppear = false
    @ViewBuilder let header: () -> Header

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsetsZero

        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .thin)
        // Line fragment padding (5) keeps text where the old TextEditor put it
        textView.textContainerInset = NSSize(width: NoteTextViewMetrics.horizontalInset - 5,
                                             height: NoteTextViewMetrics.headerHeight)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.placeholder = emptyNotePlaceholder
        textView.focusOnAppear = focusOnAppear
        textView.string = text
        apply(palette, to: textView)
        context.coordinator.appliedColors = [palette.text, palette.caret, palette.secondaryText]

        let headerView = NSHostingView(rootView: header())
        textView.headerView = headerView
        context.coordinator.headerView = headerView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }
        context.coordinator.text = $text
        // Only replace the text when it changed elsewhere (iCloud), keeping the caret in place
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
        // Re-color only when the theme changes, not on every keystroke
        let colors = [palette.text, palette.caret, palette.secondaryText]
        if colors != context.coordinator.appliedColors {
            apply(palette, to: textView)
            context.coordinator.appliedColors = colors
        }
        (context.coordinator.headerView as? NSHostingView<Header>)?.rootView = header()
    }

    private func apply(_ palette: Palette, to textView: PlaceholderTextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let textColor = NSColor(palette.text)
        textView.textColor = textColor
        textView.insertionPointColor = NSColor(palette.caret)
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .thin),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttributes([.foregroundColor: textColor, .paragraphStyle: paragraph],
                                  range: NSRange(location: 0, length: storage.length))
        }
        textView.placeholderColor = NSColor(palette.secondaryText)
        textView.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var headerView: NSView?
        var appliedColors: [Color] = []

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

// NSTextView that draws a placeholder while empty and hosts the header in its top inset
final class PlaceholderTextView: NSTextView {
    var placeholder = ""
    var placeholderColor = NSColor.secondaryLabelColor

    var headerView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let headerView {
                addSubview(headerView)
                layoutHeader()
            }
        }
    }

    // Keep the header as wide as the text view (autoresizing from a zero frame overshoots)
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutHeader()
    }

    var focusOnAppear = false

    // Open long notes at their end, where writing continues. Waits until the view is in a
    // window with a real width, then lays the whole text out so the end position is right
    private var needsScrollToEnd = true

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, needsScrollToEnd else { return }
        DispatchQueue.main.async { [weak self] in
            self?.scrollToEndOnce()
        }
    }

    private func scrollToEndOnce() {
        guard needsScrollToEnd, window != nil, bounds.width > 0 else { return }
        needsScrollToEnd = false
        if let textLayoutManager {
            textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
        } else if let textContainer {
            layoutManager?.ensureLayout(for: textContainer)
        }
        let end = (string as NSString).length
        setSelectedRange(NSRange(location: end, length: 0))
        scrollToEndOfDocument(nil)
        if focusOnAppear {
            window?.makeFirstResponder(self)
        }
    }

    private func layoutHeader() {
        headerView?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: NoteTextViewMetrics.headerHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerOrigin.x + padding, y: textContainerOrigin.y)
        placeholder.draw(at: origin, withAttributes: [
            .font: font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .thin),
            .foregroundColor: placeholderColor,
        ])
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
