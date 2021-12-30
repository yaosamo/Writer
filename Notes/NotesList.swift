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
//    @FetchRequest(sortDescriptors:  [SortDescriptor(\.date)])
//    @FetchRequest(sortDescriptors:
//            [NSSortDescriptor(key: "orderIndex", ascending: true)],
//            animation: .default)
    @FetchRequest( entity: Item.entity(),
                       sortDescriptors:
                       [
                           NSSortDescriptor(
                               keyPath: \Item.orderIndex,
                               ascending: true)
                       ]
        )
    var items: FetchedResults<Item>


    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    @State var empty:String = ""
    var body: some View {
        
//        let _ = print(items)
        
        
            NavigationView {
                List {
//                     Empty text works as padding above list
                    Text("")
                        .padding(.bottom, 32.0)
                   
                    ForEach(items, id: \.self) { item in
                    NavigationLink {
                       
                        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
                            EditorView(item: item, note: item.note ?? emptyText, date: item.date!, title: item.title ?? emptyTitle)
                            AddNote()
                            .padding()
                        }
                        .ignoresSafeArea(edges: .top)
                    } label: {
                        Text("\(item.title!)")
                            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                        
                    }.frame(maxWidth: .infinity, alignment: .trailing) // sidebar elements
                    
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
        }
        try? viewContext.save()
    }
   
}


struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
    }
}



