//
//  AddNote.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData


struct AddNote: View {

    // Managed Object from Coredata
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.undoManager) private var undoManager

    let iconsize: CGFloat
    // Folder for the new note; nil = unfiled
    var folder: Folder? = nil

    var body: some View {
        CircleIconButton(systemName: "plus", label: "New note", iconsize: iconsize, action: addNote)
            .keyboardShortcut("n", modifiers: .command)
    }

    private func addNote() {
        withAnimation {
            Item.create(in: viewContext, folder: folder, undoManager: undoManager)
        }
    }
}

// Round 48pt icon button used for + and the sidebar toggle
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let iconsize: CGFloat
    let action: () -> Void

    @Environment(\.palette) private var palette
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 48, height: 48, alignment: .center)
                .font(.system(size: iconsize, weight: Font.Weight.regular, design: .rounded))
                .foregroundColor(palette.buttonForeground)
            #if os(iOS)
                .background(palette.buttonBackground)
            #endif
        }
        .buttonStyle(.borderless)
        .background(isHovering ? palette.buttonHover : Color(.clear))
        .clipShape(Circle())
        .accessibilityLabel(label)
        .help(label)
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
    }
}


struct AddNote_Previews: PreviewProvider {
    static var previews: some View {
        AddNote(iconsize: 24)
    }
}
