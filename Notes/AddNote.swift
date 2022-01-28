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
    @State var iconsize : CGFloat

    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    
    var body: some View {
        Button(action: addNote) {
            Image(systemName: "plus")
                .frame(width: 48, height: 48, alignment: .center)
                .font(.system(size: iconsize, weight: Font.Weight.regular, design: .rounded))
                .foregroundColor(.white)
            #if os(iOS)
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            #endif
              
        } .buttonStyle(.borderless)
            .background(overText ? Color(red: 0.1, green: 0.1, blue: 0.12) :  Color(.clear))
            .clipShape(Circle())
            .onHover { over in
                            overText = over
                        }
        #if os(macOS)
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                           } else {
                               NSCursor.pop()
                           }
            }
        #endif
    }

    private func addNote() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.date = Date()
            newItem.note = emptyText
            newItem.title = emptyTitle
            newItem.id = UUID()
            try? viewContext.save()
            let _ = print("new created")
        }
    }
}


struct AddNote_Previews: PreviewProvider {
    static var previews: some View {
        AddNote(iconsize: 24)
        }
    }
