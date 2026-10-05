//
//  List.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData


// Editor on the left, note list on the right. Built as a plain HStack instead of a
// NavigationView flipped right-to-left, which broke text alignment on recent macOS.
struct NotesList: View {

    // Managed Object from Coredata
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.palette) private var palette
    @Environment(Store.self) private var store
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)

    var items: FetchedResults<Item>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)
    private var folders: FetchedResults<Folder>

    // objectID is stable once saved, so selection never requires mutating the note
    @State private var selection: NSManagedObjectID?
    // A note just created with + / ⌘N: its editor takes keyboard focus
    @State private var focusNoteID: NSManagedObjectID?
    @AppStorage("sidebarVisible") private var storedSidebarVisible = true
    // Drives the layout; changed inside withAnimation (an @AppStorage change alone doesn't
    // carry the animation, and a clicked button would jump instead of sliding)
    @State private var sidebarVisible = true
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 240
    @State private var dragStartWidth: Double?
    @State private var collapsedFolders: Set<NSManagedObjectID> = []
    @State private var renamingFolderID: NSManagedObjectID?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool
    // Match in the open note that Return / the arrows step through, and how many it has
    @State private var matchIndex = 0
    @State private var matchCount = 0

    private var selectedItem: Item? {
        items.first { $0.objectID == selection }
    }

    private var unfiledItems: [Item] {
        items.filter { $0.folder == nil }
    }

    private func items(in folder: Folder) -> [Item] {
        items.filter { $0.folder == folder }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    // First row of the list as shown, where ↓ from the search field lands
    private var firstRowID: NSManagedObjectID? {
        query.isEmpty ? unfiledItems.first?.objectID : searchResults.first?.objectID
    }

    // Notes whose name or text contains the query, in list order regardless of folder
    private var searchResults: [Item] {
        items.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
                || $0.noteText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Text runs to the window's top edge, under the floating toolbar
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The editor's edge follows the sliding sidebar
                .padding(.trailing, sidebarVisible ? sidebarWidth : 0)
            
            // Always in the view tree so it can slide in and out instead of popping
            sidebar
                .frame(width: sidebarWidth)
                .overlay(alignment: .leading) { resizeHandle }
                .offset(x: sidebarVisible ? 0 : sidebarWidth)
                .allowsHitTesting(sidebarVisible)
                .accessibilityHidden(!sidebarVisible)
        }
        // Toolbar moves with an offset rather than a re-layout, so a hovered/clicked button
        // slides with the others instead of waiting for the pointer to leave it
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                NewItemMenu(iconsize: 13)
                MoreMenu(iconSize: 12)
                CircleIconButton(systemName: "sidebar.right",
                                 label: "Show or hide notes",
                                 iconsize: 12,
                                 action: toggleSidebar)
                    .keyboardShortcut("s", modifiers: [.control, .command])
            }
            // Blurs the text scrolling underneath
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .frame(height: NoteTextViewMetrics.toolbarHeight)
            .offset(x: sidebarVisible ? -sidebarWidth : 0)
        }
        .clipped()
        .ignoresSafeArea()
        .background(palette.background)
        // New notes go into the folder of the note being edited
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequested)) { _ in
            withAnimation {
                Item.create(in: viewContext, folder: selectedItem?.folder, undoManager: undoManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFolderRequested)) { _ in
            if store.requirePro() {
                withAnimation {
                    Folder.create(in: viewContext)
                }
            }
        }
        // Select newly created notes
        .onReceive(NotificationCenter.default.publisher(for: .noteCreated)) { notification in
            selection = notification.object as? NSManagedObjectID
            focusNoteID = selection
        }
        // New folders appear in the list ready to be named
        .onReceive(NotificationCenter.default.publisher(for: .folderCreated)) { notification in
            if let id = notification.object as? NSManagedObjectID {
                withAnimation(.smooth(duration: 0.3)) {
                    sidebarVisible = true
                }
                storedSidebarVisible = true
                renamingFolderID = id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchRequested)) { _ in
            if !sidebarVisible { toggleSidebar() }
            searchFocused = true
        }
        // Each note and each search starts at its first match
        .onChange(of: selection) { matchIndex = 0 }
        .onChange(of: query) { matchIndex = 0 }
        // Keep a valid selection when notes are deleted here or on another device
        .onChange(of: items.count) {
            if selectedItem == nil {
                selection = items.first?.objectID
            }
        }
        .onAppear {
            selection = items.first?.objectID
            sidebarVisible = storedSidebarVisible
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let item = selectedItem {
            EditorView(item: item, focusOnAppear: item.objectID == focusNoteID,
                       highlight: query, currentMatch: matchIndex,
                       onMatchCount: { matchCount = $0 })
                .id(item.objectID)
        } else {
            EmptyStateView()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            List(selection: $selection) {
                if !query.isEmpty {
                    ForEach(searchResults) { item in
                        noteRow(item)
                    }
                } else {
                    browseRows
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .focused($listFocused)
            // ↑ on the first row goes back to the search field
            .onKeyPress(.upArrow) {
                guard selection == firstRowID else { return .ignored }
                searchFocused = true
                return .handled
            }
            .overlay {
                if !query.isEmpty && searchResults.isEmpty {
                    Text("No matches")
                        .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                        .foregroundColor(palette.secondaryText)
                }
            }
            .onDeleteCommand {
                if let item = selectedItem {
                    delete(item)
                }
            }

            SyncStatusView()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(SidebarMaterial())
    }

    // Sits in the toolbar strip, level with the toolbar buttons
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(palette.secondaryText)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                .focused($searchFocused)
                .onExitCommand {
                    searchText = ""
                    searchFocused = false
                }
                // Return: next match in the note, ⇧Return: previous
                .onKeyPress(.return, phases: .down) { press in
                    stepMatch(press.modifiers.contains(.shift) ? -1 : 1)
                    return .handled
                }
                // ↓ moves into the list, onto its first row
                .onKeyPress(.downArrow) {
                    if let first = firstRowID { selection = first }
                    listFocused = true
                    return .handled
                }
            if !query.isEmpty && matchCount > 0 {
                Text("\(matchIndex % matchCount + 1)/\(matchCount)")
                    .font(.system(size: 10, weight: Font.Weight.thin, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
                    .fixedSize()
                matchButton("chevron.up", label: "Previous match") { stepMatch(-1) }
                matchButton("chevron.down", label: "Next match") { stepMatch(1) }
            }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(palette.buttonHover.opacity(searchFocused ? 1 : 0.6),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        // Light border while typing, so the active field stands out
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.secondaryText.opacity(searchFocused ? 0.5 : 0), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: searchFocused)
        .padding(.horizontal, 12)
        .frame(height: NoteTextViewMetrics.toolbarHeight)
    }

    private func matchButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(palette.secondaryText)
                .frame(width: 14, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    // Wraps around at either end
    private func stepMatch(_ delta: Int) {
        guard matchCount > 0 else { return }
        matchIndex = ((matchIndex + delta) % matchCount + matchCount) % matchCount
    }

    // Notes and folders as arranged by the user, shown while not searching
    @ViewBuilder
    private var browseRows: some View {
        ForEach(unfiledItems) { item in
            noteRow(item)
        }
        .onMove { move(unfiledItems, from: $0, to: $1) }

        ForEach(folders) { folder in
            let isExpanded = !collapsedFolders.contains(folder.objectID)
            FolderRow(folder: folder,
                      isExpanded: isExpanded,
                      font: .system(size: 12, weight: Font.Weight.thin, design: .monospaced),
                      toggle: { toggle(folder) },
                      renamingID: $renamingFolderID)
                .contextMenu {
                    Button("Rename") {
                        renamingFolderID = folder.objectID
                    }
                    Button("Delete Folder") {
                        withAnimation {
                            folder.deleteKeepingNotes(in: viewContext)
                        }
                    }
                }
            
            if isExpanded {
                let folderItems = items(in: folder)
                ForEach(folderItems) { item in
                    noteRow(item)
                        .padding(.leading, 18) // line up with the folder name
                }
                .onMove { move(folderItems, from: $0, to: $1) }
            }
        }
    }

    private func noteRow(_ item: Item) -> some View {
        Text(item.displayTitle)
            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
            .lineLimit(1)
            .tag(item.objectID)
            // Deleting with right click
            .contextMenu {
                Menu("Move to") {
                    // Creates a folder, moves the note into it, then the folder name is edited inline
                    Button(store.isPro ? "New Folder" : "New Folder · Pro") {
                        if store.requirePro() {
                            withAnimation {
                                let folder = Folder.create(in: viewContext)
                                item.move(to: folder, in: viewContext)
                            }
                        }
                    }
                    if item.folder != nil || !folders.isEmpty {
                        Divider()
                    }
                    if item.folder != nil {
                        Button("No folder") {
                            withAnimation { item.move(to: nil, in: viewContext) }
                        }
                    }
                    ForEach(folders) { folder in
                        Button(folder.displayName) {
                            withAnimation { item.move(to: folder, in: viewContext) }
                        }
                        .disabled(item.folder == folder)
                    }
                }
                Button("Delete") {
                    delete(item)
                }
            }
    }

    private func toggle(_ folder: Folder) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if collapsedFolders.contains(folder.objectID) {
                collapsedFolders.remove(folder.objectID)
            } else {
                collapsedFolders.insert(folder.objectID)
            }
        }
    }

    // Drag the sidebar's left edge to resize it
    private var resizeHandle: some View {
        Color.clear
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStartWidth ?? sidebarWidth
                        dragStartWidth = start
                        sidebarWidth = min(max(start - value.translation.width, 180), 420)
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
    }


    private func toggleSidebar() {
        withAnimation(.smooth(duration: 0.3)) {
            sidebarVisible.toggle()
        }
        storedSidebarVisible = sidebarVisible
    }

    private func delete(_ item: Item) {
        withAnimation {
            item.delete(in: viewContext, undoManager: undoManager)
        }
    }

    private func move(_ group: [Item], from source: IndexSet, to destination: Int) {
        Item.reorder(group, from: source, to: destination, in: viewContext)
    }
}

// Translucent sidebar background that blurs the desktop, like the former NavigationView sidebar
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}


struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environment(SyncMonitor(container: PersistenceController.preview.container))
            .environment(Store.shared)
    }
}
