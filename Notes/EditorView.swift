//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI

// Making textfields transparent thanks to https://stackoverflow.com/questions/65865182/transparent-background-for-texteditor-in-swiftui
extension NSTextView {
  open override var frame: CGRect {
    didSet {
        backgroundColor = .clear
        drawsBackground = true
        insertionPointColor = .orange
//      textContainerInset = NSSize(width: 72, height: 0)
        textContainer?.lineFragmentPadding = 72
        NSTextView.scrollableTextView()
    }
  }
}

struct EditorView: View {
    @Environment(\.managedObjectContext) var viewContext
    @State var note: String
    //Item var for which we perform an update
    @State var item: Item


       var body: some View {
           ScrollView {
               HStack {
                   Group {
                   Text("November 25")
                   Text("Notes #1")
                   }   .font(.system(size: 14, design: .monospaced))
                       .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                   Spacer()
    
               }
               // Paddings top and bottom for Date and Title
               .padding(.leading, 72.0)
               .padding([.bottom, .top], 88.0)
           
               // Text Editor
           TextEditor(text: $note)
                .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                .lineSpacing(5.0)
           }
           
        
           //Updating button
           Button(action: {
               updateItem(item: item)
               do {
                   try viewContext.save()
               } catch {
                   let nsError = error as NSError
                   fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
               }
           }, label: {
               Text("Save")
               
                  
                   
           })
               // Padding for save button
               .padding()

       }

  
    private func updateItem(item: Item) {
        let newStatus = note
            viewContext.performAndWait {
            item.note = newStatus
            try? viewContext.save()
            }
        }
}


