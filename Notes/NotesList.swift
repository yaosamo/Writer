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
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)

    var items: FetchedResults<Item>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)
    private var folders: FetchedResults<Folder>

    // objectID is stable once saved, so selection never requires mutating the note
    @State private var selection: NSManagedObjectID?
    @AppStorage("sidebarVisible") private var sidebarVisible = true
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 240
    @State private var dragStartWidth: Double?
    @State private var collapsedFolders: Set<NSManagedObjectID> = []
    @State private var renamingFolderID: NSManagedObjectID?

    private var selectedItem: Item? {
        items.first { $0.objectID == selection }
    }

    private var unfiledItems: [Item] {
        items.filter { $0.folder == nil }
    }

    private func items(in folder: Folder) -> [Item] {
        items.filter { $0.folder == folder }
    }

    var body: some View {
        HStack(spacing: 0) {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 0) {
                        // New notes go into the folder of the note being edited
                        AddNote(iconsize: 16, folder: selectedItem?.folder)
                        CircleIconButton(systemName: "sidebar.right",
                                         label: sidebarVisible ? "Hide notes" : "Show notes",
                                         iconsize: 15,
                                         action: toggleSidebar)
                            .keyboardShortcut("s", modifiers: [.control, .command])
                    }
                    .padding()
                }

            if sidebarVisible {
                sidebar
                    .frame(width: sidebarWidth)
                    .overlay(alignment: .leading) { resizeHandle }
                    .transition(.move(edge: .trailing))
            }
        }
        .ignoresSafeArea()
        .background(palette.background)
        // Select newly created notes
        .onReceive(NotificationCenter.default.publisher(for: .noteCreated)) { notification in
            selection = notification.object as? NSManagedObjectID
        }
        // New folders appear in the list ready to be named
        .onReceive(NotificationCenter.default.publisher(for: .folderCreated)) { notification in
            if let id = notification.object as? NSManagedObjectID {
                sidebarVisible = true
                renamingFolderID = id
            }
        }
        // Keep a valid selection when notes are deleted here or on another device
        .onChange(of: items.count) {
            if selectedItem == nil {
                selection = items.first?.objectID
            }
        }
        .onAppear {
            selection = items.first?.objectID
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let item = selectedItem {
            EditorView(item: item)
                .id(item.objectID)
        } else {
            EmptyStateView()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selection) {
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
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let item = selectedItem {
                    delete(item)
                }
            }

            HStack(spacing: 0) {
                SyncStatusView()
                Spacer(minLength: 8)
                MoreMenu()
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
        .padding(.top, 40)
        .background(SidebarMaterial())
    }

    private func noteRow(_ item: Item) -> some View {
        Text(item.displayTitle)
            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
            .lineLimit(1)
            .tag(item.objectID)
            // Deleting with right click
            .contextMenu {
                if !folders.isEmpty {
                    Menu("Move to") {
                        Button("No folder") {
                            withAnimation { item.move(to: nil, in: viewContext) }
                        }
                        .disabled(item.folder == nil)
                        Divider()
                        ForEach(folders) { folder in
                            Button(folder.displayName) {
                                withAnimation { item.move(to: folder, in: viewContext) }
                            }
                            .disabled(item.folder == folder)
                        }
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
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarVisible.toggle()
        }
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
            .environment(Store())
    }
}
