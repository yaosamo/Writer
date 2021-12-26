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
        insertionPointColor = .orange
        textContainer?.lineFragmentPadding = 72
//        usesFontPanel = true
//        isRichText = true
//        usesInspectorBar = true
    }
  }
}


struct EditorView: View {
    // Coredata for saving / updating viewContext
    @Environment(\.managedObjectContext) var viewContext
   
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    
    //Item var for which we perform an update
    @State var item: Item
    @State var note: String
    @State var date: Date
    @State var title: String
    
    
       var body: some View {
           
           ScrollView {
               VStack {
                   
                   HStack {
                       Group {
                           Text("\(item.date!, formatter: itemFormatter)")
                               .padding(.trailing, 24.0)
                           TextField("Title", text: $title).textFieldStyle(PlainTextFieldStyle())

                       }
                       .font(.system(size: 14, weight: Font.Weight.thin, design: .monospaced))
                       .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                       Spacer()
                   }
                        // Paddings top and bottom for Date and Title
                       .padding(.leading, 72.0)
                       .padding([.bottom, .top], 88.0)
                   
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
           }).padding()
               
           }
        
       }
    
    // Updating item funcion
    private func updateItem(item: Item) {
        let note = note
            viewContext.performAndWait {
            item.note = note
            try? viewContext.save()
            }
        let title = title
        viewContext.performAndWait {
        item.title = title
        try? viewContext.save()
        }
        }
}



// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()

