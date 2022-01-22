//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI


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
           
           // Wrap editor and add button into zstack so add button is sticky
           ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top))  {
               ScrollView(showsIndicators: false) {
               VStack {
                   VStack(alignment: .leading) {
                           Text("\(item.date ?? Date(), formatter: itemFormatter)")
                               .padding(.leading, 24.0)
                           TextField("Title", text: $title)
                               .textFieldStyle(PlainTextFieldStyle())
                               .padding(.leading, 24)
                               .onChange(of: title) { newValue in
                                               updateItem(item: item)
                                          }
                               
                       }
                       .font(.system(size: 14, weight: Font.Weight.thin, design: .monospaced))
                       .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                       Spacer()
                   
                        // Paddings top and bottom for Date and Title

                       .padding([.bottom, .top], 20.0)
                
                   TextEditor(text: $note)
                    .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                    .lineSpacing(5.0)
                    .padding([.trailing, .leading], 24)
//                    .multilineTextAlignment(.trailing)
                    .onChange(of: note) { newValue in
                                    updateItem(item: item)
                    }
                    .padding(.bottom, 56)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: Alignment.bottomLeading)
                  } // vstack
//               .rotationEffect(Angle(degrees: 180))
               }  // scrollview
//               .rotationEffect(Angle(degrees: 180))
//               AddNote()
            .padding()
           } // z-stack
}
    
    // Updating item funcion
    private func updateItem(item: Item) {
        let note = note
        let title = title
            viewContext.performAndWait {
            item.note = note
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
