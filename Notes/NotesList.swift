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
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)

    var items: FetchedResults<Item>

    // objectID is stable once saved, so selection never requires mutating the note
    @State private var currentSelection: NSManagedObjectID?

    var body: some View {

        NavigationView {
            List {
                //Empty text works as padding above list
                Text("")
                    .padding(.bottom, 32.0)
                ForEach(items) { item in
                    NavigationLink(
                        destination: EditorView(item: item),
                        tag: item.objectID,
                        selection: $currentSelection)
                    {
                        Text(item.displayTitle)
                            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing) // sidebar elements

                    // Deleting with right click
                    .contextMenu {
                        Button("Delete") {
                            delete(item)
                        }
                    }
                }
                // On move perform function called move
                .onMove( perform: move )
            }
            .onDeleteCommand {
                if let item = items.first(where: { $0.objectID == currentSelection }) {
                    delete(item)
                }
            }
            // Select newly created notes
            .onReceive(NotificationCenter.default.publisher(for: .noteCreated)) { notification in
                currentSelection = notification.object as? NSManagedObjectID
            }
            // Keep a valid selection when notes are deleted here or on another device
            .onChange(of: items.count) {
                if !items.contains(where: { $0.objectID == currentSelection }) {
                    currentSelection = items.first?.objectID
                }
            }
            .ignoresSafeArea()
            .padding(.horizontal, 16.0)
            AddNote(iconsize: 16)
        }
        .ignoresSafeArea()
        .background(Color(red: 0.06, green: 0.07, blue: 0.06))
        .environment(\.layoutDirection, .rightToLeft) //navigation view ends
        .onAppear {
            currentSelection = items.first?.objectID
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


struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
    }
}
