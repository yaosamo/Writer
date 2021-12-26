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
    
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    
    var body: some View {
        Button(action: addNote) {
            Image(systemName: "plus")
                .frame(width: 24, height: 24, alignment: .center)
                .background(Color(red: 0.82, green: 0.40, blue: 0.22))
                .font(.system(size: 12, weight: Font.Weight.regular))
                .foregroundColor(.white)
                .clipShape(Circle())
                
        } .buttonStyle(.borderless)
        
            
    }


    private func addNote() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.date = Date()
            newItem.note = emptyText
            newItem.title = emptyTitle
            try? viewContext.save()
        }
    }
}

struct AddNote_Previews: PreviewProvider {
    static var previews: some View {
        AddNote()

        }
    }
