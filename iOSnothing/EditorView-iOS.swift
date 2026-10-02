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

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item

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
                    NoteTextView(text: $item.noteText, palette: palette)
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
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
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


// UITextView with smart lists and tasks (shared ListEditing engine)
private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    let palette: Palette

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .monospacedSystemFont(ofSize: 18, weight: .thin)
        textView.autocorrectionType = .no
        textView.keyboardDismissMode = .interactive
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.textStorage.delegate = context.coordinator
        textView.text = text
        context.coordinator.apply(palette, to: textView)

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

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.text = $text
        // Only replace the text when it changed elsewhere (iCloud), keeping the caret in place
        if textView.text != text {
            let selection = textView.selectedRange
            textView.text = text
            let length = (text as NSString).length
            textView.selectedRange = NSRange(location: min(selection.location, length), length: 0)
        }
        context.coordinator.apply(palette, to: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate, UIGestureRecognizerDelegate {
        var text: Binding<String>
        private var styler = ListStyler(text: .label, dim: .secondaryLabel)
        private var appliedColors: [Color] = []
        private var isApplyingEdit = false

        init(text: Binding<String>) { self.text = text }

        // Theme colors, line spacing; restyles everything only when the theme changes
        func apply(_ palette: Palette, to textView: UITextView) {
            let colors = [palette.text, palette.secondaryText, palette.caret]
            guard colors != appliedColors else { return }
            appliedColors = colors
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            styler = ListStyler(text: UIColor(palette.text), dim: UIColor(palette.secondaryText))
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
            text.wrappedValue = textView.text
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

        private func taskIndex(for gesture: UIGestureRecognizer) -> Int? {
            guard let textView = gesture.view as? UITextView else { return nil }
            let point = gesture.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return nil }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            let text = textView.text as NSString
            // The tap lands between characters; try the one after and the one before
            for index in [offset, offset - 1] where index >= 0 && index < text.length {
                if ListEditing.toggleTask(in: text, at: index) != nil { return index }
            }
            return nil
        }

        // Only taps on a task box are ours; every other tap goes to the text view
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            taskIndex(for: gesture) != nil
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView, let index = taskIndex(for: gesture),
                  let edit = ListEditing.toggleTask(in: textView.text as NSString, at: index) else { return }
            apply(edit, to: textView, select: false)
        }
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
