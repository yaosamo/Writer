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
    // Focuses the sidebar's search field (⌘F)
    static let searchRequested = Notification.Name("searchRequested")
}

// "+" menu: new note, or new folder (Pro). ⌘N / ⇧⌘N do the same from the File menu
struct NewItemMenu: View {
    @Environment(Store.self) private var store

    let iconsize: CGFloat

    var body: some View {
        #if os(macOS)
        AppMenuButton(systemName: "plus", iconsize: iconsize, label: "New", help: "New note or folder") {
            [
                AppMenuItem("New Note", image: "square.and.pencil") {
                    NotificationCenter.default.post(name: .newNoteRequested, object: nil)
                },
                AppMenuItem(store.isPro ? "New Folder" : "New Folder · Pro",
                            image: store.isPro ? "folder.badge.plus" : "lock") {
                    NotificationCenter.default.post(name: .newFolderRequested, object: nil)
                },
            ]
        }
        #else
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
        #endif
    }
}

#if os(macOS)
// The Mac toolbar menus are AppKit menus built at the moment they open. SwiftUI's Menu kept
// the items it built first, so "New Folder · Pro" stayed after Pro was unlocked
struct AppMenuItem {
    var title: String
    var image: String?
    var checked = false
    var children: [AppMenuItem] = []
    var isSeparator = false
    var action: (() -> Void)?

    init(_ title: String, image: String? = nil, checked: Bool = false,
         children: [AppMenuItem] = [], action: (() -> Void)? = nil) {
        self.title = title
        self.image = image
        self.checked = checked
        self.children = children
        self.action = action
    }

    static var separator: AppMenuItem {
        var item = AppMenuItem("")
        item.isSeparator = true
        return item
    }
}

struct AppMenuButton: View {
    let systemName: String
    let iconsize: CGFloat
    let label: String
    let help: String
    let items: () -> [AppMenuItem]

    // Where the button is in the window, so the menu opens just below it
    @State private var frame: CGRect = .zero

    var body: some View {
        Button {
            AppMenuPresenter.show(items(), below: frame)
        } label: {
            CircleIcon(systemName: systemName, iconsize: iconsize)
        }
        .buttonStyle(.plain)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { frame = proxy.frame(in: .global) }
                .onChange(of: proxy.frame(in: .global)) { _, new in frame = new }
        })
        .accessibilityLabel(label)
        .help(help)
    }
}

@MainActor
enum AppMenuPresenter {
    static func show(_ items: [AppMenuItem], below frame: CGRect) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let view = window.contentView else { return }
        // The hosting view is flipped: y grows downwards, like SwiftUI's global space
        let point = view.isFlipped ? NSPoint(x: frame.minX, y: frame.maxY + 4)
                                   : NSPoint(x: frame.minX, y: view.bounds.height - frame.maxY - 4)
        make(items).popUp(positioning: nil, at: point, in: view)
    }

    private static func make(_ items: [AppMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let menuItem = ClosureMenuItem(title: item.title, handler: item.action)
            if let image = item.image {
                menuItem.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
            }
            menuItem.state = item.checked ? .on : .off
            if !item.children.isEmpty {
                menuItem.submenu = make(item.children)
            }
            menu.addItem(menuItem)
        }
        return menu
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: (() -> Void)?

    init(title: String, handler: (() -> Void)?) {
        self.handler = handler
        super.init(title: title, action: handler == nil ? nil : #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler?() }
}
#endif

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
            .environment(Store.shared)
    }
}
