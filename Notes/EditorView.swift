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

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    HStack {
                        Group {
                            TextField("Title", text: $item.titleText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.leading, 72)

                            Text("\(item.date ?? Date(), formatter: itemFormatter)")
                                .padding(.leading, 24.0)
                        }
                        .font(.system(size: 14, weight: Font.Weight.thin, design: .monospaced))
                        .foregroundColor(Theme.secondaryText)
                    } // hstack
                    // Paddings top and bottom for Date and Title
                    .padding(.trailing, 72.0)
                    .padding([.bottom, .top], 88.0)

                    TextEditor(text: $item.noteText)
                        .foregroundColor(Theme.text)
                        .background(CaretColor(color: NSColor(Theme.caret)))
                        .lineSpacing(5.0)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .overlay(alignment: .topLeading) {
                            if item.noteText.isEmpty {
                                Text(emptyNotePlaceholder)
                                    .foregroundColor(Theme.secondaryText)
                                    .padding(.leading, 5) // NSTextView line fragment padding
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding([.trailing, .leading], 72)
                        .padding(.bottom, 56)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: proxy.size.height - 176, alignment: .top)
                } // vstack
            } // scrollview
            .scrollIndicators(.hidden)
            // Open long notes at their end, where writing continues
            .defaultScrollAnchor(.bottom)
        } // geometry
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


// TextEditor has no caret color API (.tint doesn't reach it); set it on the
// window's text views once this view is attached
private struct CaretColor: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.color = color
        return view
    }

    func updateNSView(_ view: ProbeView, context: Context) {}

    final class ProbeView: NSView {
        var color: NSColor = .orange

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self, let root = self.window?.contentView else { return }
                Self.textViews(in: root).forEach { $0.insertionPointColor = self.color }
            }
        }

        private static func textViews(in view: NSView) -> [NSTextView] {
            view.subviews.flatMap { subview in
                (subview as? NSTextView).map { [$0] } ?? textViews(in: subview)
            }
        }
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
