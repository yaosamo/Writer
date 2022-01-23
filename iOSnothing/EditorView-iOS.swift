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
        GeometryReader { height in
            // Wrap editor and add button into zstack so add button is sticky
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top))  {
                ScrollView(showsIndicators: false) {
                    VStack {
                        VStack(alignment: .leading) {
                            Text("\(item.date ?? Date(), formatter: itemFormatter)")
                                
                            TextField("Title", text: $title)
                                .textFieldStyle(PlainTextFieldStyle())
                                
                                .onChange(of: title) { newValue in
                                    updateItem(item: item)
                                }
                            
                        }
                        .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                        .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                        Spacer()
                        
                        // Paddings top and bottom for Date and Title
                        
                            .padding([.bottom, .top], 20.0)
                        
                        TextEditor(text: $note)
                            .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                            .lineSpacing(5.0)
                            .padding([.trailing, .leading], 0)
                        //                    .multilineTextAlignment(.trailing)
                            .onChange(of: note) { newValue in
                                updateItem(item: item)
                            }
//                            .padding(.bottom, 56)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: height.size.height, maxHeight: .infinity, alignment: .bottomLeading)
                    } // vstack
                }  // scrollview
                
            } // z-stack
        } // geometry
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
