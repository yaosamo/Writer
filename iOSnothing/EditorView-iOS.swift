//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI
import CoreData

// Keeps swipe-back working while the system back button is hidden
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

struct EditorView: View {

    // Coredata for saving / updating viewContext
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private enum Field: Hashable {
        case title
        case note
    }
    @FocusState private var focusedField: Field?

    @Environment(Store.self) private var store

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item

    @State private var images: ImageAttachmentController
    @State private var previewImage: UUID?
    // Shown from here: the app-level paywall sheet can't present over a pushed note
    @State private var showPaywall = false

    init(item: Item) {
        self.item = item
        let context = item.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _images = State(initialValue: ImageAttachmentController(item: item, context: context,
                                                                placeholderColor: CGColor(gray: 0.5, alpha: 0.12)))
    }

    var body: some View {


        // Wrap editor and add button into zstack so add button is sticky
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top))  {
                // TextEditor scrolls itself and avoids the keyboard; wrapping it in another
                // ScrollView hid the text behind the keyboard while typing
                VStack(spacing: 0) {
                    HStack {
                        TextField("Title", text: $item.titleText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($focusedField, equals: .title)
                        Spacer()
                        Text("\(item.date ?? Date(), formatter: itemFormatter)")

                    }
                    .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
                    // Paddings top and bottom for Date and Title
                    .padding(.top, 108)
                    .padding(.bottom, 76)

                    // UITextView rather than TextEditor: smart lists need to see each keystroke
                    NoteTextView(text: $item.noteText, palette: palette, images: images,
                                 canAddImages: {
                                     if store.isPro { return true }
                                     showPaywall = true
                                     return false
                                 },
                                 openImage: { previewImage = $0 })
                        .overlay(alignment: .topLeading) {
                            if item.noteText.isEmpty {
                                Text(emptyNotePlaceholder)
                                    .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                                    .foregroundColor(palette.secondaryText)
                                    .padding(.top, 8) // UITextView text container inset
                                    .padding(.leading, 5) // line fragment padding
                                    .allowsHitTesting(false)
                            }
                        }
                } // vstack
                .padding([.trailing, .leading], 24)
            // back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .foregroundColor(palette.buttonForeground)
                    .font(.system(size: 16, weight: Font.Weight.regular, design: .rounded))
                    .frame(width: 48, height: 48, alignment: .center)
                    .background(palette.buttonBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Back")
        } // z-stack
        .background(palette.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    focusedField = nil
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("Hide keyboard")
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(item: Binding(get: { previewImage.map(PreviewID.init) }, set: { previewImage = $0?.id })) { preview in
            ImagePreview(id: preview.id, controller: images) { previewImage = nil }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        // Debounced save: restarts on every change, saves after a pause in typing
        .task(id: [item.title, item.note]) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            viewContext.saveIfNeeded()
        }
        .onDisappear {
            guard previewImage == nil else { return }
            item.removeUnusedAttachments(in: viewContext)
            viewContext.saveIfNeeded()
        }
    }
}

private struct PreviewID: Identifiable {
    let id: UUID
}


// UITextView with smart lists and tasks (shared ListEditing engine)
private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    let palette: Palette
    let images: ImageAttachmentController
    // Pro check before an image is added (opens the paywall when locked)
    let canAddImages: () -> Bool
    let openImage: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, images: images, canAddImages: canAddImages, openImage: openImage) }

    func makeUIView(context: Context) -> PastingTextView {
        let textView = PastingTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .monospacedSystemFont(ofSize: 18, weight: .thin)
        textView.autocorrectionType = .no
        textView.keyboardDismissMode = .interactive
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.textStorage.delegate = context.coordinator
        context.coordinator.setText(text, in: textView)
        context.coordinator.apply(palette, to: textView)
        textView.onPasteImage = { [weak textView, coordinator = context.coordinator] data in
            guard let textView else { return }
            coordinator.insertImage(data, in: textView)
        }
        textView.onWidthChange = { [weak textView, images] in
            guard let textView else { return }
            images.refit(maxWidth: textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right
                         - 2 * textView.textContainer.lineFragmentPadding)
        }
        images.onChange = { [weak textView, coordinator = context.coordinator] attachment in
            guard let textView else { return }
            coordinator.redraw(attachment, in: textView)
        }

        // Hide-keyboard button above the keyboard
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let hide = UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), primaryAction: UIAction { [weak textView] _ in
            textView?.resignFirstResponder()
        })
        hide.accessibilityLabel = "Hide keyboard"
        bar.items = [UIBarButtonItem(systemItem: .flexibleSpace), hide]
        bar.tintColor = UIColor(palette.caret)
        textView.inputAccessoryView = bar

        // Tapping a task's box toggles it
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)
        return textView
    }

    func updateUIView(_ textView: PastingTextView, context: Context) {
        context.coordinator.text = $text
        // Only replace the text when it changed elsewhere (iCloud), keeping the caret in place
        if context.coordinator.lastText != text {
            let selection = textView.selectedRange
            context.coordinator.setText(text, in: textView)
            textView.selectedRange = NSRange(location: min(selection.location, textView.textStorage.length), length: 0)
        }
        context.coordinator.apply(palette, to: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate, UIGestureRecognizerDelegate {
        var text: Binding<String>
        // The stored text (with image tokens) the editor currently shows
        var lastText = ""
        let images: ImageAttachmentController
        let canAddImages: () -> Bool
        let openImage: (UUID) -> Void
        private var styler = ListStyler(text: .label, dim: .secondaryLabel)
        private var appliedColors: [Color] = []
        private var isApplyingEdit = false

        init(text: Binding<String>, images: ImageAttachmentController, canAddImages: @escaping () -> Bool, openImage: @escaping (UUID) -> Void) {
            self.text = text
            self.images = images
            self.canAddImages = canAddImages
            self.openImage = openImage
        }

        func setText(_ text: String, in textView: UITextView) {
            let font = textView.font ?? UIFont.monospacedSystemFont(ofSize: 18, weight: .thin)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: styler.text]
            textView.textStorage.setAttributedString(ImageText.attributed(text, attributes: attributes, attachment: images.attachment(for:)))
            styler.apply(to: textView.textStorage, range: NSRange(location: 0, length: textView.textStorage.length))
            lastText = text
        }

        // Pasted image: processed and stored, then placed on its own line at the caret
        func insertImage(_ data: Data, in textView: UITextView) {
            guard canAddImages() else { return }
            Task { @MainActor in
                guard let id = await images.add(data) else { return }
                let attachment = images.attachment(for: id)
                attachment.fit(maxWidth: images.maxWidth)
                let storage = textView.textStorage
                let range = textView.selectedRange
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
                isApplyingEdit = true
                storage.replaceCharacters(in: range, with: piece)
                isApplyingEdit = false
                textView.selectedRange = NSRange(location: range.location + piece.length, length: 0)
                textViewDidChange(textView)
            }
        }

        func redraw(_ attachment: ImageAttachment, in textView: UITextView) {
            let storage = textView.textStorage
            storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
                if value as AnyObject === attachment {
                    storage.edited(.editedAttributes, range: range, changeInLength: 0)
                    stop.pointee = true
                }
            }
        }

        // Theme colors, line spacing; restyles everything only when the theme changes
        func apply(_ palette: Palette, to textView: UITextView) {
            let colors = [palette.text, palette.secondaryText, palette.caret]
            guard colors != appliedColors else { return }
            appliedColors = colors
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            styler = ListStyler(text: UIColor(palette.text), dim: UIColor(palette.secondaryText), paragraph: paragraph)
            textView.tintColor = UIColor(palette.caret)
            textView.typingAttributes = [
                .font: textView.font ?? UIFont.monospacedSystemFont(ofSize: 18, weight: .thin),
                .foregroundColor: UIColor(palette.text),
                .paragraphStyle: paragraph,
            ]
            let storage = textView.textStorage
            if storage.length > 0 {
                let all = NSRange(location: 0, length: storage.length)
                storage.addAttribute(.paragraphStyle, value: paragraph, range: all)
                styler.apply(to: storage, range: all)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            lastText = ImageText.plain(from: textView.textStorage)
            text.wrappedValue = lastText
        }

        // Smart lists: Return continues a list, Backspace removes a marker, "[] " makes a task
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard !isApplyingEdit,
                  let edit = ListEditing.edit(in: textView.text as NSString, range: range, replacement: replacement) else { return true }
            apply(edit, to: textView, select: true)
            return false
        }

        // UITextInput replace keeps undo working
        private func apply(_ edit: ListEditing.Edit, to textView: UITextView, select: Bool) {
            guard let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
                  let end = textView.position(from: start, offset: edit.range.length),
                  let range = textView.textRange(from: start, to: end) else { return }
            let selection = textView.selectedRange
            isApplyingEdit = true
            textView.replace(range, withText: edit.replacement)
            isApplyingEdit = false
            textView.selectedRange = select ? edit.selection : selection
            textViewDidChange(textView)
        }

        // Restyle the edited lines (attributes only)
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            styler.apply(to: textStorage, range: editedRange)
        }

        private enum TapTarget {
            case task(Int)
            case image(UUID)
        }

        private func target(for gesture: UIGestureRecognizer) -> TapTarget? {
            guard let textView = gesture.view as? UITextView else { return nil }
            let point = gesture.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return nil }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            let storage = textView.textStorage
            let text = storage.string as NSString
            // The tap lands between characters; try the one after and the one before
            for index in [offset, offset - 1] where index >= 0 && index < text.length {
                if let image = storage.attribute(.attachment, at: index, effectiveRange: nil) as? ImageAttachment,
                   let rect = rectOfImage(image, at: index, in: textView), rect.insetBy(dx: -4, dy: -4).contains(point) {
                    return .image(image.imageID)
                }
                if ListEditing.toggleTask(in: text, at: index) != nil { return .task(index) }
            }
            return nil
        }

        // The image's on-screen frame. UIKit reports an attachment character as roughly line-tall,
        // so build the frame from the caret positions around it plus the image's own size
        private func rectOfImage(_ image: ImageAttachment, at index: Int, in textView: UITextView) -> CGRect? {
            guard let start = textView.position(from: textView.beginningOfDocument, offset: index),
                  let end = textView.position(from: start, offset: 1),
                  let range = textView.textRange(from: start, to: end) else { return nil }
            let rects = [textView.caretRect(for: start), textView.caretRect(for: end), textView.firstRect(for: range)]
            let top = rects.map(\.minY).min() ?? 0
            let bottom = max(rects.map(\.maxY).max() ?? 0, top + image.bounds.height)
            let left = textView.caretRect(for: start).minX
            return CGRect(x: left, y: bottom - image.bounds.height, width: image.bounds.width, height: image.bounds.height)
        }

        // Only taps on a task box or an image are ours; every other tap goes to the text view
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            target(for: gesture) != nil
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView, let target = target(for: gesture) else { return }
            switch target {
            case .image(let id):
                textView.resignFirstResponder()
                openImage(id)
            case .task(let index):
                guard let edit = ListEditing.toggleTask(in: textView.text as NSString, at: index) else { return }
                apply(edit, to: textView, select: false)
            }
        }
    }
}


// UITextView that hands pasted images to the editor and reports width changes
final class PastingTextView: UITextView {
    var onPasteImage: ((Data) -> Void)?
    var onWidthChange: (() -> Void)?
    private var lastWidth: CGFloat = 0

    private static let imageTypes = ["public.heic", "public.png", "public.jpeg", "public.tiff"]

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), onPasteImage != nil, UIPasteboard.general.hasImages { return true }
        return super.canPerformAction(action, withSender: sender)
    }

    // Text wins when the pasteboard has both (e.g. copied from a web page)
    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        if let onPasteImage, pasteboard.hasImages, !pasteboard.hasStrings {
            let data = Self.imageTypes.lazy.compactMap { pasteboard.data(forPasteboardType: $0) }.first
                ?? pasteboard.image?.pngData()
            if let data {
                onPasteImage(data)
                return
            }
        }
        super.paste(sender)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - lastWidth) > 0.5 {
            lastWidth = bounds.width
            onWidthChange?()
        }
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
