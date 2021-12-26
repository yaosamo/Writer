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
    @FetchRequest(sortDescriptors:  [SortDescriptor(\.date)])
    private var items: FetchedResults<Item>
    
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    @State private var showDetails = false
    
    var body: some View {
       
        
        
            NavigationView {
                
                List {
                    // Empty text works as padding above list
                    Text("")
                        .padding(.bottom, 32.0)
                    
                    ForEach(items) { item in
                    NavigationLink {
                       
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                            EditorView(item: item, note: item.note ?? emptyText, date: item.date!, title: item.title ?? emptyTitle)
                            AddNote()
                                .padding()
                            
                        }
                        .ignoresSafeArea(edges: .top)
                    } label: {
                        Text("\(item.title!)")
                        .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
                    }
                    
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
                }.ignoresSafeArea()
                    .padding(.horizontal, 16.0)
                    .background(Color(red: 0.08, green: 0.14, blue: 0.13))
//                .toolbar {
//                    ToolbarItem {
//                        Button("hi") {
//                            Label("Add Item", systemImage: "plus")
//                        }
//                    }
//                }
                
                Text("Make it count")
            }
            
            
        }
        
}

struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
    }
}
