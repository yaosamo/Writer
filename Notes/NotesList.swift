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
    
    // Fetch and sorting
    // @FetchRequest(sortDescriptors:  [SortDescriptor(\.date)])
    @FetchRequest(sortDescriptors:
            [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)
//    @FetchRequest( entity: Item.entity(),
//                       sortDescriptors:
//                       [
//                           NSSortDescriptor(
//                               keyPath: \Item.orderIndex,
//                               ascending: true)
//                       ]
//        )
    var items: FetchedResults<Item>
    
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    @State var currentSelection: UUID?
    
    var body: some View {
       
            NavigationView {
                List {
//                     Empty text works as padding above list
                    Text("")
                        .padding(.bottom, 32.0)
                   
                    ForEach(items, id: \.self) { item in
                        
                    NavigationLink(
                        destination: EditorView(item: item, note: item.note ?? emptyText, date: item.date!, title: item.title ?? emptyTitle),
                        tag: item.id ?? UUID(),
                        selection: $currentSelection)
                    {
                        Text("\(item.title!)")
                            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing) // sidebar elements
                    
                    // Deleting with right click
                    .contextMenu(ContextMenu(menuItems: {
                     Button(action: {viewContext.delete(item)
                                            do {
                                                try viewContext.save()
                                            } catch {
                                                let nsError = error as NSError
                                                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                                            }
                                        }, label: {
                                            Text("Delete")
                                        })
                    }))
                    }
                    .onMove( perform: move )
                }
                .onChange(of: items.count) { newValue in
                    currentSelection = items.first?.id
                }
                    .ignoresSafeArea()
                    .padding(.horizontal, 16.0)
                Text("Make it count")
                .foregroundColor(.white)
//                    .toolbar {
//                        ToolbarItem {
//                            Button(action: {}) {
//                                Label("Add Item", systemImage: "plus")
//                            }
//                        }
//                    }
            }
            .environment(\.layoutDirection, .rightToLeft) //navigation view ends
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
                revisedItems[ reverseIndex ].selection = true
                currentSelection = newSpot
            } else { revisedItems[ reverseIndex ].selection = false }
        }
        try? viewContext.save()
    }
    
}


struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
    }
}



