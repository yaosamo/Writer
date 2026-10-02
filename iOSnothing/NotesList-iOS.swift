//
//  List.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData



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

    @State private var collapsedFolders: Set<NSManagedObjectID> = []
    @State private var renamingFolderID: NSManagedObjectID?

    private var unfiledItems: [Item] {
        items.filter { $0.folder == nil }
    }

    private func items(in folder: Folder) -> [Item] {
        items.filter { $0.folder == folder }
    }

    var body: some View {

        NavigationView {
            ZStack(alignment: .bottom) {
                List {
                    //Empty text works as padding above list
                    Text("")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    let unfiled = unfiledItems
                    ForEach(unfiled) { item in
                        noteRow(item)
                    }
                    .onMove { Item.reorder(unfiled, from: $0, to: $1, in: viewContext) }
                    .onDelete { delete(unfiled, at: $0) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)

                    ForEach(folders) { folder in
                        let isExpanded = !collapsedFolders.contains(folder.objectID)
                        FolderRow(folder: folder,
                                  isExpanded: isExpanded,
                                  font: .system(size: 18, weight: Font.Weight.thin, design: .monospaced),
                                  toggle: { toggle(folder) },
                                  renamingID: $renamingFolderID)
                            .foregroundColor(palette.text)
                            .padding([.top, .bottom], 8)
                            .contextMenu {
                                Button("Rename") {
                                    renamingFolderID = folder.objectID
                                }
                                Button("Delete Folder", role: .destructive) {
                                    withAnimation {
                                        folder.deleteKeepingNotes(in: viewContext)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                            .listRowSeparator(.hidden)
                        
                        if isExpanded {
                            let folderItems = items(in: folder)
                            ForEach(folderItems) { item in
                                noteRow(item)
                                    .padding(.leading, 18) // line up with the folder name
                            }
                            .onMove { Item.reorder(folderItems, from: $0, to: $1, in: viewContext) }
                            .onDelete { delete(folderItems, at: $0) }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .padding(.leading, 24)
                .overlay {
                    if items.isEmpty && folders.isEmpty {
                        EmptyStateView()
                    }
                }
                HStack(spacing: 8) {
                    SyncStatusView()
                        .padding(.leading, 32)
                    Spacer()
                    MoreMenu()
                    AddNote(iconsize: 16)
                        .padding([.trailing], 8)
                }
            } //ztack new
            .background(palette.background)
        }
        // New folders appear in the list ready to be named
        .onReceive(NotificationCenter.default.publisher(for: .folderCreated)) { notification in
            renamingFolderID = notification.object as? NSManagedObjectID
        }
    }

    private func noteRow(_ item: Item) -> some View {
        ZStack {
            NavigationLink(destination: EditorView(item: item)) {
                Text(item.displayTitle)
                    .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                    .foregroundColor(palette.text)
                    .padding([.top, .bottom], 8)
            }
            .navigationBarHidden(true)

            // Covers the row's disclosure chevron
            HStack {
                Spacer()
                Text(" ")
                    .frame(width: 48, height: 48)
                    .background(palette.background)
                    .offset(x: 8, y: 0)
            }
        } //z
        .contextMenu {
            if !folders.isEmpty {
                Menu("Move to") {
                    Button("No folder") {
                        withAnimation { item.move(to: nil, in: viewContext) }
                    }
                    .disabled(item.folder == nil)
                    ForEach(folders) { folder in
                        Button(folder.displayName) {
                            withAnimation { item.move(to: folder, in: viewContext) }
                        }
                        .disabled(item.folder == folder)
                    }
                }
            }
            Button("Delete", role: .destructive) {
                withAnimation { item.delete(in: viewContext, undoManager: undoManager) }
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


    private func delete(_ group: [Item], at offsets: IndexSet) {
        withAnimation {
            offsets.map { group[$0] }.forEach { $0.delete(in: viewContext, undoManager: undoManager) }
        }
    }
}


struct NotesList_Previews : PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone SE (2nd generation)", "iPhone XS Max"], id: \.self) { deviceName in
            NotesList().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .environment(SyncMonitor(container: PersistenceController.preview.container))
                .environment(Store())
                .previewDevice(PreviewDevice(rawValue: deviceName))
        }
    }
}
