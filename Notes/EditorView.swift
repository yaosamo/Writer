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
		enclosingScrollView?.hasVerticalScroller = false
//		enclosingScrollView?.verticalScrollElasticity = NSScrollView.Elasticity.none
		
			
//        textContainerInset = NSSize(width: 0, height: 40)
        
//        textContainer?.lineFragmentPadding = 0
//        textContainerInset = (CGSize:72)
//        usesFontPanel = true
//        isRichText = true
//        usesInspectorBar = true
//        textContainerInset = NSSize(width: 0, height: 44)
    }
  }
}

//@IBDesignable class UITextViewFixed: UITextView {
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        setup()
//    }
//    func setup() {
//
//        textContainer.lineFragmentPadding = 0
//    }
//}




struct MultilineTextField: NSViewRepresentable {

    typealias NSViewType = NSTextView
    private let textView = NSTextView()
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextView {
        textView.delegate = context.coordinator
        textView.textContainer?.lineFragmentPadding = 0
        textView.allowsUndo = true
        textView.isRichText = false
		textView.enclosingScrollView?.hasVerticalScroller = false
        textView.pasteAsPlainText(Any?.self)
        return textView
    }
    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = text
        textView.textStorage?.foregroundColor = NSColor(red: 0.47, green: 0.47, blue: 0.52, alpha: 1)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: NSFont.Weight.thin)

    }
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)

    }
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MultilineTextField
        init(_ textView: MultilineTextField) {
            parent = textView
        }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string

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
           // Wrap editor and add button into zstack so add button is sticky
		   GeometryReader { height in
           ZStack(alignment: Alignment(horizontal: .leading, vertical: .top))  {
			   ScrollView(showsIndicators: false) {
               VStack {
                   HStack {
                       Group {
                           Text("\(item.date!, formatter: itemFormatter)")
                               .padding(.trailing, 24.0)

                           TextField("Title", text: $title)
                               .textFieldStyle(PlainTextFieldStyle())
                               .multilineTextAlignment(.trailing)
                               .padding(.trailing, 72)
                               .onChange(of: title) { newValue in
                                               updateItem(item: item)
                                          }
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
					.padding([.trailing, .leading], 72)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: note) { newValue in
                                    updateItem(item: item)
					}
					.frame(minHeight: height.size.height-176)
              	}
			   .rotationEffect(Angle(degrees: 180))
			   }  // scrollviwe
			   .rotationEffect(Angle(degrees: 180))
               AddNote()
            .padding()
           }
           .ignoresSafeArea(edges: .top)
		   } // geome
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

