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

    @Environment(Store.self) private var store

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item
    // New notes start with the caret in the text
    var focusOnAppear = false
    // Sidebar search: its matches are highlighted in the text, the current one stronger
    var highlight = ""
    var currentMatch = 0
    var onMatchCount: (Int) -> Void = { _ in }

    @State private var images: ImageAttachmentController
    @State private var previewImage: UUID?

    init(item: Item, focusOnAppear: Bool = false, highlight: String = "", currentMatch: Int = 0,
         onMatchCount: @escaping (Int) -> Void = { _ in }) {
        self.item = item
        self.focusOnAppear = focusOnAppear
        self.highlight = highlight
        self.currentMatch = currentMatch
        self.onMatchCount = onMatchCount
        let context = item.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _images = State(initialValue: ImageAttachmentController(item: item, context: context,
                                                                placeholderColor: CGColor(gray: 0.5, alpha: 0.12)))
    }

    var body: some View {
        NoteTextView(text: $item.noteText, palette: palette, focusOnAppear: focusOnAppear,
                     highlight: highlight, currentMatch: currentMatch, onMatchCount: onMatchCount,
                     images: images,
                     canAddImages: { store.requirePro() },
                     openImage: { previewImage = $0 }) {
            EditorHeader(item: item, palette: palette)
        }
        // Full-size image, over the editor
        .overlay {
            if let id = previewImage {
                ImagePreview(id: id, controller: images) { previewImage = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: previewImage)
        // Debounced save: restarts on every change, saves after a pause in typing
        .task(id: [item.title, item.note]) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            viewContext.saveIfNeeded()
        }
        .onDisappear {
            item.removeUnusedAttachments(in: viewContext)
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
        // Title row sits 88pt from the window's top
        .padding(.top, 88)
        .frame(height: NoteTextViewMetrics.headerHeight, alignment: .top)
    }
}

enum NoteTextViewMetrics {
    static let horizontalInset: CGFloat = 72
    // macOS toolbar floating over the editor's top-right corner (+, …, sidebar)
    static let toolbarHeight: CGFloat = 60
    static let toolbarWidth: CGFloat = 156
    // Space above the text for the header; also used as bottom padding
    static let headerHeight: CGFloat = 176
    // Lines stay a comfortable length in wide windows: the text column is centred, at most this wide
    static let maxTextWidth: CGFloat = 720

    static func sideInset(forWidth width: CGFloat) -> CGFloat {
        max(horizontalInset, ((width - maxTextWidth) / 2).rounded())
    }
}


// One scroll view for the whole note: an NSTextView whose top inset holds the header.
// (A SwiftUI TextEditor inside a ScrollView gave two nested scrolls that fought each other.)
struct NoteTextView<Header: View>: NSViewRepresentable {
    @Binding var text: String
    let palette: Palette
    var focusOnAppear = false
    var highlight = ""
    var currentMatch = 0
    var onMatchCount: (Int) -> Void = { _ in }
    let images: ImageAttachmentController
    // Pro check before an image is added (opens the paywall when locked)
    let canAddImages: () -> Bool
    let openImage: (UUID) -> Void
    @ViewBuilder let header: () -> Header

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, images: images, canAddImages: canAddImages)
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
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .thin)
        textView.textStorage?.setAttributedString(
            ImageText.attributed(text, attributes: [.font: font, .foregroundColor: NSColor(palette.text)],
                                 attachment: images.attachment(for:)))
        context.coordinator.lastText = text
        textView.textStorage?.delegate = context.coordinator
        textView.onRestyle = { [weak textView, coordinator = context.coordinator] range in
            guard let storage = textView?.textStorage else { return }
            coordinator.styler.apply(to: storage, range: range)
        }
        textView.onClick = { [weak textView, coordinator = context.coordinator, openImage] index in
            guard let textView else { return false }
            if let id = coordinator.image(at: index, in: textView) {
                openImage(id)
                return true
            }
            return coordinator.toggleTask(at: index, in: textView)
        }
        textView.onPasteImage = { [weak textView, coordinator = context.coordinator] data in
            guard let textView else { return }
            coordinator.insertImage(data, in: textView)
        }
        textView.onWidthChange = { [weak textView, images] in
            guard let textView, let container = textView.textContainer else { return }
            images.refit(maxWidth: container.size.width - 2 * container.lineFragmentPadding)
        }
        images.onChange = { [weak textView, coordinator = context.coordinator] attachment in
            guard let textView else { return }
            coordinator.redraw(attachment, in: textView)
        }
        apply(palette, to: textView, coordinator: context.coordinator)
        context.coordinator.appliedColors = [palette.text, palette.caret, palette.secondaryText]
        context.coordinator.highlight = highlight
        context.coordinator.currentMatch = currentMatch
        context.coordinator.onMatchCount = onMatchCount
        context.coordinator.showMatches(in: textView, reveal: true)

        let headerView = NSHostingView(rootView: header())
        textView.headerView = headerView
        context.coordinator.headerView = headerView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }
        context.coordinator.text = $text
        var textReplaced = false
        // Only replace the text when it changed elsewhere (iCloud), keeping the caret in place
        if context.coordinator.lastText != text {
            textReplaced = true
            let selection = textView.selectedRange()
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .thin)
            textView.textStorage?.setAttributedString(
                ImageText.attributed(text, attributes: [.font: font, .foregroundColor: NSColor(palette.text)],
                                     attachment: images.attachment(for:)))
            context.coordinator.lastText = text
            let length = textView.textStorage?.length ?? 0
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
        // Re-color only when the theme changes, not on every keystroke
        let colors = [palette.text, palette.caret, palette.secondaryText]
        if colors != context.coordinator.appliedColors {
            apply(palette, to: textView, coordinator: context.coordinator)
            context.coordinator.appliedColors = colors
        }
        context.coordinator.onMatchCount = onMatchCount
        let searchChanged = context.coordinator.highlight != highlight
            || context.coordinator.currentMatch != currentMatch
        if searchChanged || textReplaced {
            context.coordinator.highlight = highlight
            context.coordinator.currentMatch = currentMatch
            // A new search or step scrolls to the current match; a synced edit only refreshes the marks
            context.coordinator.showMatches(in: textView, reveal: searchChanged)
        }
        (context.coordinator.headerView as? NSHostingView<Header>)?.rootView = header()
    }

    private func apply(_ palette: Palette, to textView: PlaceholderTextView, coordinator: Coordinator) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let textColor = NSColor(palette.text)
        textView.textColor = textColor
        textView.insertionPointColor = NSColor(palette.caret)
        // Selection in the caret's color
        textView.selectedTextAttributes = [.backgroundColor: NSColor(palette.caret).withAlphaComponent(0.4)]
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .thin),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        coordinator.styler = ListStyler(text: textColor, dim: NSColor(palette.secondaryText), paragraph: paragraph)
        if let storage = textView.textStorage, storage.length > 0 {
            let all = NSRange(location: 0, length: storage.length)
            storage.addAttribute(.paragraphStyle, value: paragraph, range: all)
            coordinator.styler.apply(to: storage, range: all)
        }
        textView.placeholderColor = NSColor(palette.secondaryText)
        textView.matchColor = NSColor(palette.caret).withAlphaComponent(0.3)
        textView.currentMatchColor = NSColor(palette.caret).withAlphaComponent(0.65)
        coordinator.showMatches(in: textView, reveal: false)
        textView.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var text: Binding<String>
        var headerView: NSView?
        var appliedColors: [Color] = []
        var styler = ListStyler(text: .textColor, dim: .secondaryLabelColor)
        // The stored text (with image tokens) the editor currently shows
        var lastText = ""
        var highlight = ""
        var currentMatch = 0
        var onMatchCount: (Int) -> Void = { _ in }
        private var reportedMatchCount: Int?
        let images: ImageAttachmentController
        let canAddImages: () -> Bool
        private var isApplyingEdit = false

        init(text: Binding<String>, images: ImageAttachmentController, canAddImages: @escaping () -> Bool) {
            self.text = text
            self.images = images
            self.canAddImages = canAddImages
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let storage = textView.textStorage else { return }
            lastText = ImageText.plain(from: storage)
            text.wrappedValue = lastText
            if let textView = textView as? PlaceholderTextView {
                showMatches(in: textView, reveal: false)
            }
        }

        // Marks the search's matches and tells the sidebar how many there are
        func showMatches(in textView: PlaceholderTextView, reveal: Bool) {
            let count = textView.showMatches(of: highlight, current: currentMatch, reveal: reveal)
            guard count != reportedMatchCount else { return }
            reportedMatchCount = count
            // Reported after the view update: SwiftUI state can't change during one
            DispatchQueue.main.async { [onMatchCount] in onMatchCount(count) }
        }

        func image(at index: Int, in textView: NSTextView) -> UUID? {
            guard let storage = textView.textStorage, index < storage.length else { return nil }
            return (storage.attribute(.attachment, at: index, effectiveRange: nil) as? ImageAttachment)?.imageID
        }

        // Pasted or dropped image: processed and stored, then placed on its own line at the caret
        func insertImage(_ data: Data, in textView: NSTextView) {
            guard canAddImages() else { return }
            Task { @MainActor in
                guard let id = await images.add(data), let storage = textView.textStorage else {
                    NSSound.beep()
                    return
                }
                let attachment = images.attachment(for: id)
                if let container = textView.textContainer {
                    images.refit(maxWidth: container.size.width - 2 * container.lineFragmentPadding)
                    attachment.fit(maxWidth: images.maxWidth)
                }
                let range = textView.selectedRange()
                let ns = storage.string as NSString
                let attributes = textView.typingAttributes
                let piece = NSMutableAttributedString()
                if range.location > 0, ns.character(at: range.location - 1) != 10 {
                    piece.append(NSAttributedString(string: "\n", attributes: attributes))
                }
                let image = NSMutableAttributedString(attachment: attachment)
                image.addAttributes(attributes, range: NSRange(location: 0, length: image.length))
                piece.append(image)
                let end = NSMaxRange(range)
                if end >= ns.length || ns.character(at: end) != 10 {
                    piece.append(NSAttributedString(string: "\n", attributes: attributes))
                }
                guard textView.shouldChangeText(in: range, replacementString: piece.string) else { return }
                storage.replaceCharacters(in: range, with: piece)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: range.location + piece.length, length: 0))
            }
        }

        // An attachment's image or size changed: re-lay out its character
        func redraw(_ attachment: ImageAttachment, in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
                if value as AnyObject === attachment {
                    storage.edited(.editedAttributes, range: range, changeInLength: 0)
                    stop.pointee = true
                }
            }
        }

        // Smart lists: Return continues a list, Backspace removes a marker, "[] " makes a task
        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString string: String?) -> Bool {
            guard !isApplyingEdit, let string,
                  let edit = ListEditing.edit(in: textView.string as NSString, range: range, replacement: string) else { return true }
            apply(edit, to: textView, select: true)
            return false
        }

        // Clicking a task's box toggles it
        func toggleTask(at index: Int, in textView: NSTextView) -> Bool {
            guard let edit = ListEditing.toggleTask(in: textView.string as NSString, at: index) else { return false }
            apply(edit, to: textView, select: false)
            return true
        }

        // Goes through shouldChangeText / didChangeText so undo and the binding keep working
        private func apply(_ edit: ListEditing.Edit, to textView: NSTextView, select: Bool) {
            isApplyingEdit = true
            defer { isApplyingEdit = false }
            let selection = textView.selectedRange()
            guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
            textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
            textView.setSelectedRange(select ? edit.selection : selection)
        }

        // Restyle the edited lines (attributes only)
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            styler.apply(to: textStorage, range: editedRange)
        }
    }
}

// NSTextView that draws a placeholder while empty and hosts the header in its top inset
final class PlaceholderTextView: NSTextView {
    var placeholder = ""
    var placeholderColor = NSColor.secondaryLabelColor
    // Called with the character under a click; return true to swallow the click (task toggles)
    var onClick: ((Int) -> Bool)?
    var onPasteImage: ((Data) -> Void)?
    var onWidthChange: (() -> Void)?

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff, NSPasteboard.PasteboardType("public.jpeg"), NSPasteboard.PasteboardType("public.heic"),
    ]

    // An image file, or image data when there's no text (text wins for mixed web clippings)
    private func imageData(from pasteboard: NSPasteboard) -> Data? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.image"],
        ]) as? [URL], let url = urls.first {
            return try? Data(contentsOf: url)
        }
        guard pasteboard.string(forType: .string) == nil else { return nil }
        for type in Self.imageTypes {
            if let data = pasteboard.data(forType: type) { return data }
        }
        return nil
    }

    // A plain-text view disables Paste when the clipboard holds only an image
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)), onPasteImage != nil, hasImage(on: .general) { return true }
        return super.validateUserInterfaceItem(item)
    }

    private func hasImage(on pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: Self.imageTypes) != nil
            || pasteboard.canReadObject(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true, .urlReadingContentsConformToTypes: ["public.image"],
            ])
    }

    override func paste(_ sender: Any?) {
        if let onPasteImage, let data = imageData(from: .general) {
            onPasteImage(data)
            return
        }
        super.paste(sender)
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        super.acceptableDragTypes + Self.imageTypes + [.fileURL]
    }

    override func dragOperation(for dragInfo: NSDraggingInfo, type: NSPasteboard.PasteboardType) -> NSDragOperation {
        if onPasteImage != nil, Self.imageTypes.contains(type) || type == .fileURL { return .copy }
        return super.dragOperation(for: dragInfo, type: type)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let onPasteImage, let data = imageData(from: sender.draggingPasteboard) {
            let point = convert(sender.draggingLocation, from: nil)
            setSelectedRange(NSRange(location: characterIndexForInsertion(at: point), length: 0))
            onPasteImage(data)
            return true
        }
        return super.performDragOperation(sender)
    }

    // Restyles a range (used to undo the link hover look)
    var onRestyle: ((NSRange) -> Void)?
    private var hoveredLink: NSRange?

    // The text reaches the window's top edge: its title bar strip still drags the window
    private func isInTitleBar(_ event: NSEvent) -> Bool {
        guard let window, let content = window.contentView else { return false }
        let titleBarHeight = window.frame.height - window.contentLayoutRect.height
        return event.locationInWindow.y > content.bounds.height - titleBarHeight
    }

    // Top-right corner where the toolbar buttons float over the text: they set their own pointer
    private func isUnderToolbar(_ event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        return point.y < visibleRect.minY + NoteTextViewMetrics.toolbarHeight
            && point.x > visibleRect.maxX - NoteTextViewMetrics.toolbarWidth
    }

    override func cursorUpdate(with event: NSEvent) {
        if isUnderToolbar(event) { return }
        super.cursorUpdate(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if isInTitleBar(event), let window {
            if event.clickCount == 2 {
                window.zoom(nil)
            } else {
                window.performDrag(with: event)
            }
            return
        }
        let index = characterIndex(for: NSEvent.mouseLocation)
        let inText = index != NSNotFound && index < (string as NSString).length
        // ⌘-click opens a link; a plain click edits it like any text
        if inText, event.modifierFlags.contains(.command),
           let url = textStorage?.attribute(.noteLink, at: index, effectiveRange: nil) as? URL {
            NSWorkspace.shared.open(url)
            return
        }
        if event.clickCount == 1, inText, let onClick, onClick(index) { return }
        super.mouseDown(with: event)
    }

    // MARK: Link hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self && area.userInfo?["links"] != nil {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: ["links": true]))
    }

    override func mouseMoved(with event: NSEvent) {
        if isUnderToolbar(event) { return }
        super.mouseMoved(with: event)
        updateLinkHover(modifiers: event.modifierFlags)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoveredLink(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        updateLinkHover(modifiers: event.modifierFlags)
    }

    private func updateLinkHover(modifiers: NSEvent.ModifierFlags) {
        guard let storage = textStorage else { return }
        let index = characterIndex(for: NSEvent.mouseLocation)
        var range = NSRange(location: NSNotFound, length: 0)
        let isLink = index != NSNotFound && index < storage.length
            && storage.attribute(.noteLink, at: index, longestEffectiveRange: &range, in: NSRange(location: 0, length: storage.length)) != nil
        setHoveredLink(isLink ? range : nil)
        // The hand only while ⌘ is held: a plain click still places the caret
        if isLink, modifiers.contains(.command) {
            NSCursor.pointingHand.set()
        }
    }

    private func setHoveredLink(_ range: NSRange?) {
        guard range != hoveredLink, let storage = textStorage else { return }
        if let old = hoveredLink, NSMaxRange(old) <= storage.length {
            onRestyle?(old)
        }
        hoveredLink = range
        if let range, let color = textColor {
            storage.addAttribute(.foregroundColor, value: color.withAlphaComponent(0.55), range: range)
        }
    }

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
        let widthChanged = abs(newSize.width - frame.width) > 0.5
        // Line fragment padding (5) keeps text where the old TextEditor put it
        let inset = NoteTextViewMetrics.sideInset(forWidth: newSize.width) - 5
        if abs(textContainerInset.width - inset) > 0.5 {
            textContainerInset = NSSize(width: inset, height: NoteTextViewMetrics.headerHeight)
        }
        super.setFrameSize(newSize)
        layoutHeader()
        if widthChanged { onWidthChange?() }
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
        if let match = revealOnOpen {
            revealOnOpen = nil
            center(match)
        } else {
            let end = (string as NSString).length
            setSelectedRange(NSRange(location: end, length: 0))
            scrollToEndOfDocument(nil)
        }
        if focusOnAppear {
            window?.makeFirstResponder(self)
        }
    }

    private func layoutHeader() {
        // The header pads itself by horizontalInset; shift it so title and date line up with the text column
        let shift = NoteTextViewMetrics.sideInset(forWidth: bounds.width) - NoteTextViewMetrics.horizontalInset
        headerView?.frame = NSRect(x: shift, y: 0, width: bounds.width - 2 * shift, height: NoteTextViewMetrics.headerHeight)
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

    // MARK: Search matches

    // ⌘F searches all notes from the sidebar instead of opening the find bar
    override func performTextFinderAction(_ sender: Any?) {
        if (sender as? NSMenuItem)?.tag == NSTextFinder.Action.showFindInterface.rawValue {
            NotificationCenter.default.post(name: .searchRequested, object: nil)
            return
        }
        super.performTextFinderAction(sender)
    }

    override func performFindPanelAction(_ sender: Any?) {
        if (sender as? NSMenuItem)?.tag == Int(NSFindPanelAction.showFindPanel.rawValue) {
            NotificationCenter.default.post(name: .searchRequested, object: nil)
            return
        }
        super.performFindPanelAction(sender)
    }

    var matchColor = NSColor.findHighlightColor
    var currentMatchColor = NSColor.findHighlightColor
    // Match of the search the note was opened with, scrolled to instead of the end
    private var revealOnOpen: NSRange?

    // Marks every occurrence of the search term, the current one stronger, and returns how many.
    // Display only: the stored text is untouched
    @discardableResult
    func showMatches(of term: String, current: Int, reveal: Bool) -> Int {
        let ns = string as NSString
        let all = NSRange(location: 0, length: ns.length)
        var matches: [NSRange] = []
        var search = all
        while !term.isEmpty {
            let found = ns.range(of: term, options: [.caseInsensitive, .diacriticInsensitive],
                                 range: search, locale: .current)
            guard found.location != NSNotFound, found.length > 0 else { break }
            matches.append(found)
            search = NSRange(location: NSMaxRange(found), length: ns.length - NSMaxRange(found))
        }

        let currentIndex = matches.isEmpty ? nil : current % matches.count
        if let textLayoutManager, let content = textLayoutManager.textContentManager {
            textLayoutManager.removeRenderingAttribute(.backgroundColor, for: textLayoutManager.documentRange)
            let start = content.documentRange.location
            for (index, match) in matches.enumerated() {
                if let from = content.location(start, offsetBy: match.location),
                   let to = content.location(from, offsetBy: match.length),
                   let range = NSTextRange(location: from, end: to) {
                    textLayoutManager.addRenderingAttribute(.backgroundColor,
                                                            value: index == currentIndex ? currentMatchColor : matchColor,
                                                            for: range)
                }
            }
        } else if let layoutManager {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: all)
            for (index, match) in matches.enumerated() {
                layoutManager.addTemporaryAttribute(.backgroundColor,
                                                    value: index == currentIndex ? currentMatchColor : matchColor,
                                                    forCharacterRange: match)
            }
        }

        if reveal, let currentIndex {
            if needsScrollToEnd {
                revealOnOpen = matches[currentIndex]
            } else {
                center(matches[currentIndex])
            }
        }
        return matches.count
    }

    // Puts the caret on a match and scrolls it to the middle of the view
    private func center(_ range: NSRange) {
        setSelectedRange(NSRange(location: range.location, length: 0))
        scrollRangeToVisible(range)
        guard let window, let clip = enclosingScrollView?.contentView else { return }
        let onScreen = firstRect(forCharacterRange: range, actualRange: nil)
        guard !onScreen.isEmpty || onScreen.origin != .zero else { return }
        let rect = convert(window.convertFromScreen(onScreen), from: nil)
        let maxY = max(0, frame.height - clip.bounds.height)
        let y = min(max(0, rect.midY - clip.bounds.height / 2), maxY)
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
        enclosingScrollView?.reflectScrolledClipView(clip)
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
