//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI
import CoreData

extension UINavigationController: UIGestureRecognizerDelegate {
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
                ScrollView(showsIndicators: false) {
                    VStack {
                        HStack {
                            TextField("Title", text: $item.titleText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($focusedField, equals: .title)
                            Spacer()
                            Text("\(item.date ?? Date(), formatter: itemFormatter)")

                        }
                        .padding(.top, 88)
                        .padding(.bottom, 56)
                        .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                        .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))

                        // Paddings top and bottom for Date and Title
                            .padding([.bottom, .top], 20.0)
                        TextEditor(text: $item.noteText)
                            .focused($focusedField, equals: .note)
                            .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                            .disableAutocorrection(true)
                            .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                            .lineSpacing(5.0)
                            .overlay(alignment: .topLeading) {
                                if item.noteText.isEmpty {
                                    Text(emptyNotePlaceholder)
                                        .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                                        .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                                        .padding(.top, 8) // UITextView text container inset
                                        .padding(.leading, 5) // line fragment padding
                                        .allowsHitTesting(false)
                                }
                            }
                            .frame(idealHeight: 800*2, alignment: .top)
                    } // vstack
                }  // scrollview
                .scrollDismissesKeyboard(.interactively)
                .padding([.trailing, .leading], 24)
                .frame(alignment: .bottom)
            // back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: Font.Weight.regular, design: .rounded))
                    .frame(width: 48, height: 48, alignment: .center)
                    .background(.black)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Back")
        } // z-stack
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


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
