//
//  AddNote.swift (new note / folder menu, shared buttons)
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData


extension Notification.Name {
    // Handled by the note list, which knows the current folder and undo manager
    static let newNoteRequested = Notification.Name("newNoteRequested")
    static let newFolderRequested = Notification.Name("newFolderRequested")
}

// "+" menu: new note, or new folder (Pro). ⌘N / ⇧⌘N do the same from the File menu
struct NewItemMenu: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette

    let iconsize: CGFloat

    var body: some View {
        Menu {
            Button {
                NotificationCenter.default.post(name: .newNoteRequested, object: nil)
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            Button {
                NotificationCenter.default.post(name: .newFolderRequested, object: nil)
            } label: {
                Label(store.isPro ? "New Folder" : "New Folder · Pro",
                      systemImage: store.isPro ? "folder.badge.plus" : "lock")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: iconsize, weight: Font.Weight.regular, design: .rounded))
                .foregroundColor(palette.buttonForeground)
                .frame(width: 48, height: 48)
            #if os(iOS)
                .background(palette.buttonBackground)
                .clipShape(Circle())
            #endif
        }
        .circleButtonChrome()
        .accessibilityLabel("New")
        .help("New note or folder")
    }
}

// Round 48pt icon button used for + and the sidebar toggle
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let iconsize: CGFloat
    let action: () -> Void

    @Environment(\.palette) private var palette

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
        .circleHover()
        .accessibilityLabel(label)
        .help(label)
    }
}

extension View {
    // Menus styled like CircleIconButton: borderless, no indicator, 48pt circle with hover
    func circleButtonChrome() -> some View {
        #if os(macOS)
        // Button-style menus render the label as SwiftUI, so hover highlights work
        self.menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .circleHover()
        #else
        self
        #endif
    }

    // Round hover highlight and pointing-hand cursor (macOS)
    func circleHover() -> some View {
        modifier(CircleHover())
    }
}

private struct CircleHover: ViewModifier {
    @Environment(\.palette) private var palette
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .frame(width: 48, height: 48)
            .background(isHovering ? palette.buttonHover : Color.clear)
            .clipShape(Circle())
            .contentShape(Circle())
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


struct NewItemMenu_Previews: PreviewProvider {
    static var previews: some View {
        NewItemMenu(iconsize: 24)
            .environment(Store())
    }
}
