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
            CircleIcon(systemName: "plus", iconsize: iconsize)
        }
        .circleMenuStyle()
        .accessibilityLabel("New")
        .help("New note or folder")
    }
}

// Round icon button used for the sidebar toggle (and styled like the + and … menus)
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let iconsize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemName: systemName, iconsize: iconsize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

// The round icon itself. macOS: 38pt circle with hover highlight inside a 44pt hit area.
// iOS: 48pt filled circle (touch target)
struct CircleIcon: View {
    let systemName: String
    let iconsize: CGFloat

    @Environment(\.palette) private var palette
    @State private var isHovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconsize, weight: Font.Weight.regular, design: .rounded))
            .foregroundColor(palette.buttonForeground)
        #if os(macOS)
            .frame(width: 38, height: 38)
            .background(Circle().fill(isHovering ? palette.buttonHover : Color.clear))
            .padding(3)
            // The whole 44pt square is clickable, not just the glyph
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .linkPointer()
        #else
            .frame(width: 48, height: 48)
            .background(palette.buttonBackground)
            .clipShape(Circle())
            .contentShape(Circle())
        #endif
    }
}

#if os(macOS)
private struct LinkPointer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(.link)
        } else {
            // NSCursor.push alone gets reset by the hosting view's cursor updates
            content.onContinuousHover { phase in
                if case .active = phase { NSCursor.pointingHand.set() }
            }
        }
    }
}

extension View {
    // Pointing-hand cursor over clickable icons
    func linkPointer() -> some View { modifier(LinkPointer()) }
}
#endif

extension View {
    // Menus that look like CircleIconButton: the label renders as SwiftUI, no indicator
    func circleMenuStyle() -> some View {
        #if os(macOS)
        self.menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        #else
        self
        #endif
    }
}


struct NewItemMenu_Previews: PreviewProvider {
    static var previews: some View {
        NewItemMenu(iconsize: 24)
            .environment(Store())
    }
}
