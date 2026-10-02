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
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)

    var items: FetchedResults<Item>

    // objectID is stable once saved, so selection never requires mutating the note
    @State private var selection: NSManagedObjectID?
    @AppStorage("sidebarVisible") private var sidebarVisible = true
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 240
    @State private var dragStartWidth: Double?

    private var selectedItem: Item? {
        items.first { $0.objectID == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 0) {
                        AddNote(iconsize: 16)
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
        .background(Theme.background)
        // Select newly created notes
        .onReceive(NotificationCenter.default.publisher(for: .noteCreated)) { notification in
            selection = notification.object as? NSManagedObjectID
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
                ForEach(items) { item in
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                        .lineLimit(1)
                        .tag(item.objectID)
                        // Deleting with right click
                        .contextMenu {
                            Button("Delete") {
                                delete(item)
                            }
                        }
                }
                // On move perform function called move
                .onMove(perform: move)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let item = selectedItem {
                    delete(item)
                }
            }

            SyncStatusView()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .padding(.top, 40)
        .background(SidebarMaterial())
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

    private func move(from source: IndexSet, to destination: Int) {
        Item.reorder(Array(items), from: source, to: destination, in: viewContext)
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
    }
}
