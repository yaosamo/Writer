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
    }
  }
}

struct EditorView: View {
    @Environment(\.managedObjectContext) var viewContext
    @State var note: String
    //Item var for which we perform an update
    @State var item: Item
    @State var date: Date
    @State var title: String


       var body: some View {
           ScrollView {
               HStack {
                   Group {
                       Text("\(item.date!, formatter: itemFormatter)")
                           .padding(/*@START_MENU_TOKEN@*/.trailing, 24.0/*@END_MENU_TOKEN@*/)
                   
                       Text("\(item.title!)")
                   }
                   .font(.system(size: 14, design: .monospaced))
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
    // Date formatter
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    // Updating item funcion
    private func updateItem(item: Item) {
        let newStatus = note
            viewContext.performAndWait {
            item.note = newStatus
            try? viewContext.save()
            }
        }
}


