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
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)
    
    var items: FetchedResults<Item>
    @State var isEditing = false
    @State var selection = Set<String>()
    
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    @State var currentSelection: UUID?
    @State private var selectedNote: Item? = nil

    var body: some View {
       
        NavigationView {
            List {
                //Empty text works as padding above list
                ForEach(items) { item in
                    ZStack {
                        NavigationLink(
                            destination: EditorView(item: item, note: item.note ?? emptyText, date: item.date!, title: item.title ?? emptyTitle),
                        tag: item.id ?? UUID(),
                        selection: $currentSelection)
                    {
                        Text("\(item.title!)")
                            .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                            .padding([.top, .bottom], 8)
                    }
                        HStack {
                        Spacer()
                    Text(" ")
                            .frame(width: 48, height: 48)
                            .background(.black)
                            .offset(x: 16, y: 0)
                           
                        }
                            
                    } //z
                }
                .onMove( perform: move)
                .onDelete(perform: deleteItems)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .listRowSeparator(.hidden)
            }
            // on change of items count set current selection in the list to firts item
            .onChange(of: items.count) { newValue in
                if (items.count >= 1) {
                    let newSpot = UUID()
                    items.first?.id = newSpot
                    currentSelection = newSpot
                }
            }
            .toolbar {
                ToolbarItem {
                    AddNote(iconsize: 16)
                }
            }
        }
        .onAppear(perform: first)
    }
    
    private func first() {
        currentSelection = items.first?.id
    }
    
    private func move( from source: IndexSet, to destination: Int)
    {
        // Make an array of items from fetched results
        var revisedItems: [ Item ] = items.map{ $0 }
        
        // change the order of the items in the array
        revisedItems.move(fromOffsets: source, toOffset: destination )
        // update the orderIndex attribute in revisedItems to
        // persist the new order. This is done in reverse order
        // to minimize changes to the indices.
        for reverseIndex in stride( from: revisedItems.count - 1,
                                    through: 0,
                                    by: -1 )
        {
            revisedItems[ reverseIndex ].orderIndex =
            Int16( reverseIndex )
            
            // checking if current item is selected and maintain it
            if (currentSelection == revisedItems[ reverseIndex ].id) {
                let newSpot = UUID()
                revisedItems[ reverseIndex ].id = newSpot
                currentSelection = newSpot
            }
        }
        try? viewContext.save()
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}


struct NotesList_Previews : PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone SE (2nd generation)", "iPhone XS Max"], id: \.self) { deviceName in
            NotesList().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .previewDevice(PreviewDevice(rawValue: deviceName))
        }
    }
}
