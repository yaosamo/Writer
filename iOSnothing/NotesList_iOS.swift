//
//  List.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData

struct NotesListiOS: View {
    
    // Managed Object from Coredata
     @Environment(\.managedObjectContext) var viewContext

    // Fetch and sorting
//    @FetchRequest(sortDescriptors:  [SortDescriptor(\.date)])
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

    let bgcolor = Color(red: 0.08, green: 0.14, blue: 0.13)
    let selectedColor = Color(red: 0.06, green: 0.10, blue: 0.09)
 

    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    @State var currentSelection: UUID?
    @State private var selectedNote: Item? = nil

    var body: some View {
        NavigationView {
            List {
                let _ = print("YOOOOOOO", items)
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.note!)")
                    } label: {
                        Text(item.title ?? "nil")
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    AddNote()
                }
            }
            Text("Select an item")
        }
        
//            NavigationView {
//                List {
//                    ForEach(items) { item in
//                    NavigationLink(
//                        destination: Text("Kuku"),
//                        tag: item.id ?? UUID(),
//                        selection: $currentSelection)
//                    {
//                        Text("\(item.title!)")
//                            .font(.system(size: 12, weight: Font.Weight.thin, design: .monospaced))
//                    }
//
//                    }
//
//                }
//
//                // on change of items count set current selection in the list to firts item
//                .onChange(of: items.count) { newValue in
//                    if (items.count >= 1) {
//                        let newSpot = UUID()
//                        items.first?.id = newSpot
//                        currentSelection = newSpot
//                        }
//                }
//                    .ignoresSafeArea()
//                    .padding(.horizontal, 16.0)
//                    AddNote()
//                .foregroundColor(.white)
//            }
            .ignoresSafeArea()
            .background(Color(red: 0.06, green: 0.07, blue: 0.06))
            .onAppear(perform: first)
       
        }
    
    private func first() {
                currentSelection = items.first?.id
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


struct List_Previews: PreviewProvider {
    static var previews: some View {
        NotesListiOS()
    }
}
