//
//  ContentView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/12/21.
//

import SwiftUI
import CoreData



struct ContentView: View {
    // Managed Object from Coredata
     @Environment(\.managedObjectContext) var viewContext
    
    // Fetch and sorting
    @FetchRequest(sortDescriptors:  [SortDescriptor(\.date)])
    private var items: FetchedResults<Item>
    
    //Text string
    
    var emptyText = "Free your mind"
    
    var body: some View {
        
        NavigationView {
            
            List(items) { item in
                NavigationLink {
                    //Editor view need 2 variables: note and item
                        EditorView(note: item.note ?? emptyText, item: item)
                } label: { Text("\(item.date!)") }
                
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
            .toolbar {
                ToolbarItem {
                    Button(action: addNote) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
        
    }
    

    private func addNote() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.date = Date()
            newItem.note = emptyText
            try? viewContext.save()
        }
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
                .environment(
                    \.managedObjectContext,PersistenceController.preview.container.viewContext)
            
            }
        }
    }
