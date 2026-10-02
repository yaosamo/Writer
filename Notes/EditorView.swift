//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI
import CoreData

// Making textfields transparent thanks to https://stackoverflow.com/questions/65865182/transparent-background-for-texteditor-in-swiftui

extension NSTextView {
    open override var frame: CGRect {
    didSet {
        backgroundColor = .clear
        insertionPointColor = .orange
		enclosingScrollView?.hasVerticalScroller = false
		enclosingScrollView?.horizontalScrollElasticity = NSScrollView.Elasticity.none
		isAutomaticLinkDetectionEnabled = false
		enclosingScrollView?.contentView.automaticallyAdjustsContentInsets = false
    }
  }
}


struct EditorView: View {

    // Coredata for saving / updating viewContext
    @Environment(\.managedObjectContext) var viewContext

    // Observed directly so edits synced from other devices show up and aren't overwritten
    @ObservedObject var item: Item

       var body: some View {

           // Wrap editor and add button into zstack so add button is sticky
		   GeometryReader { height in
           ZStack(alignment: .topTrailing)  {
			   ScrollView(showsIndicators: false) {
               VStack {
                   HStack {
                       Group {
						   TextField("Title", text: $item.titleText)
                               .textFieldStyle(PlainTextFieldStyle())
                               .padding(.leading, 72)

                           Text("\(item.date ?? Date(), formatter: itemFormatter)")
                               .padding(.leading, 24.0)
					   }
                       .font(.system(size: 14, weight: Font.Weight.thin, design: .monospaced))
                       .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                   } // hstack
                        // Paddings top and bottom for Date and Title
                       .padding(.trailing, 72.0)
                       .padding([.bottom, .top], 88.0)

                   TextEditor(text: $item.noteText)
                    .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                    .lineSpacing(5.0)
                    .overlay(alignment: .topLeading) {
                        if item.noteText.isEmpty {
                            Text(emptyNotePlaceholder)
                                .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                                .padding(.leading, 5) // NSTextView line fragment padding
                                .allowsHitTesting(false)
                        }
                    }
					.padding([.trailing, .leading], 72)
					.padding(.bottom, 56)
					.frame(minWidth: 0, maxWidth: .infinity, minHeight: height.size.height-176, alignment: .top)
              	} // vstack
			   .rotationEffect(Angle(degrees: 180))
			   }  // scrollview
			   .rotationEffect(Angle(degrees: 180))
               AddNote(iconsize: 16)
            .padding()
           } // z-stack
		   .ignoresSafeArea(edges: .top)
		   } // geometry
           // The list uses right-to-left layout to sit on the right; the editor must stay left-to-right
           // or the text ends up right-aligned
           .environment(\.layoutDirection, .leftToRight)
           // Debounced save: restarts on every change, saves after a pause in typing
           .task(id: [item.title, item.note]) {
               try? await Task.sleep(for: .seconds(1))
               guard !Task.isCancelled else { return }
               viewContext.saveIfNeeded()
           }
           .onDisappear {
               viewContext.saveIfNeeded()
           }
}
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
