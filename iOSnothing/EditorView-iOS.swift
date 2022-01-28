//
//  EditorView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/13/21.
//

import SwiftUI

extension UINavigationController: UIGestureRecognizerDelegate {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

struct EditorView: View {
    
    // Coredata for saving / updating viewContext
    @Environment(\.managedObjectContext) var viewContext
    
    //Text string
    var emptyText = "Free your mind"
    var emptyTitle = "Note"
    
    private enum Field: Int {
         case yourTextEdit
     }
    @FocusState private var focusedField: Field?

    //Item var for which we perform an upd  ate
    @State var item: Item
    @State var note: String
    @State var date: Date
    @State var title: String
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var body: some View {
        
        
        // Wrap editor and add button into zstack so add button is sticky
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top))  {
                ScrollView(showsIndicators: false) {
                    VStack {
                        HStack {
                            TextField("Title", text: $title)
                                .textFieldStyle(PlainTextFieldStyle())
                                .onChange(of: title) { newValue in
                                    updateItem(item: item)
                                }
                            Spacer()
                            Text("\(item.date ?? Date(), formatter: itemFormatter)")
                            
                        }
                        .padding(.top, 88)
                        .padding(.bottom, 56)
                        .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                        .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.52))
                        
                        // Paddings top and bottom for Date and Title
                            .padding([.bottom, .top], 20.0)
                        TextEditor(text: $note)
                            .focused($focusedField, equals: .yourTextEdit)
                            .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                            .disableAutocorrection(true)
                            .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.73))
                            .lineSpacing(5.0)
                            .onChange(of: note) { newValue in
                                updateItem(item: item)
                            }
                            .onTapGesture {
                                        if (focusedField != nil) {
                                            focusedField = nil
                                        }
                            }
                            .frame(idealHeight: 800*2, alignment: .top)
                    } // vstack
                }  // scrollview
                .padding([.trailing, .leading], 24)
                .frame(alignment: .bottom)
            // back button
            Button(action: goback) {
                Image(systemName: "chevron.backward")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: Font.Weight.regular, design: .rounded))
                    .frame(width: 48, height: 48, alignment: .center)
                    .background(.black)
                    .clipShape(Circle())
            }
        } // z-stack
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
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
    
    private func goback() {
        self.presentationMode.wrappedValue.dismiss()
    }
}


// Date formatter
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()
