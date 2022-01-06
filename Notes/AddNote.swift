//
//  EditorBody.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI

struct AddNote: View {
    
    // Managed Object from Coredata
     @Environment(\.managedObjectContext) var viewContext
    
    
    @State private var overText = false

    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    
    var body: some View {
        Button(action: addNote) {
            Image(systemName: "plus")
                .frame(width: 24, height: 24, alignment: .center)
                .font(.system(size: 12, weight: Font.Weight.regular, design: .rounded))
                .foregroundColor(.white)
              
        } .buttonStyle(.borderless)
            .background(overText ? Color(red: 0.82, green: 0.40, blue: 0.22) :  Color(red: 0.11, green: 0.13, blue: 0.12))
            .clipShape(Circle())
            .onHover { over in
                            overText = over
                        }
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                           } else {
                               NSCursor.pop()
                           }
            } 
    }

    private func addNote() {
//        Attempt creating new item after selected item and moving others below it.
//        let first = NotesList().items.first?.orderIndex
//        let currentlySelected = NotesList().currentSelection
//        var currentlySelectedIndex = Int16()
//        for reverseIndex in stride( from: items.count - 1,
//                                    through: 0,
//                                    by: -1 )
//        {
//            if (
//                items[ reverseIndex ].id == currentlySelected) {
//                currentlySelectedIndex = items[ reverseIndex ].orderIndex
//            let _ = print(items[reverseIndex])
//                }
//
//        }
//        NotesList().currentSelection =
//        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.date = Date()
            newItem.note = emptyText
            newItem.title = emptyTitle
            newItem.id = UUID()
        newItem.orderIndex = -1
            try? viewContext.save()
//        }
    }
   
}


struct AddNote_Previews: PreviewProvider {
    static var previews: some View {
        AddNote()
        }
    }
