//
//  AddNote.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData


struct AddNote: View {

    // Managed Object from Coredata
    @Environment(\.managedObjectContext) var viewContext

    @State private var isHovering = false
    let iconsize: CGFloat

    var body: some View {
        Button(action: addNote) {
            Image(systemName: "plus")
                .frame(width: 48, height: 48, alignment: .center)
                .font(.system(size: iconsize, weight: Font.Weight.regular, design: .rounded))
                .foregroundColor(.white)
            #if os(iOS)
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            #endif
        }
        .buttonStyle(.borderless)
        .background(isHovering ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color(.clear))
        .clipShape(Circle())
        .accessibilityLabel("New note")
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
    }

    private func addNote() {
        withAnimation {
            Item.create(in: viewContext)
        }
    }
}


struct AddNote_Previews: PreviewProvider {
    static var previews: some View {
        AddNote(iconsize: 24)
    }
}
