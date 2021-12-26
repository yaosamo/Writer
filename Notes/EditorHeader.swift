//
//  EditorHeader.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/22/21.
//
import SwiftUI
import CoreData

struct EditorHeader: View {
    @Environment(\.managedObjectContext) var viewContext

    @State var item: Item
    @State var date: Date
    @State var title: String
    
    var body: some View {
        HStack {
            Group {
                Text("\(item.date!, formatter: itemFormatter)")
                    .padding(.trailing, 24.0)
                TextField("Title", text: $title).textFieldStyle(PlainTextFieldStyle())

            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
            Spacer()
        }
    }
}

// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
