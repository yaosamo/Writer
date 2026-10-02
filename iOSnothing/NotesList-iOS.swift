//
//  List.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/23/21.
//

import SwiftUI
import CoreData



struct NotesList: View {

    // Managed Object from Coredata
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.undoManager) private var undoManager
    @FetchRequest(sortDescriptors:
                    [NSSortDescriptor(key: "orderIndex", ascending: true)],
                  animation: .default)

    var items: FetchedResults<Item>

    var body: some View {

        NavigationView {
            ZStack(alignment: .bottom) {
                List {
                    //Empty text works as padding above list
                    Text("")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    ForEach(items) { item in
                        ZStack {
                            NavigationLink(destination: EditorView(item: item)) {
                                Text(item.displayTitle)
                                    .font(.system(size: 18, weight: Font.Weight.thin, design: .monospaced))
                                    .padding([.top, .bottom], 8)
                            }
                            .navigationBarHidden(true)

                            HStack {
                                Spacer()
                                Text(" ")
                                    .frame(width: 48, height: 48)
                                    .background(.black)
                                    .offset(x: 8, y: 0)
                            }
                        } //z
                    }
                    .onMove( perform: move)
                    .onDelete(perform: deleteItems)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
                .padding(.leading, 24)
                .overlay {
                    if items.isEmpty {
                        EmptyStateView()
                    }
                }
                HStack {
                    SyncStatusView()
                        .padding(.leading, 32)
                    Spacer()
                    AddNote(iconsize: 16)
                        .padding([.trailing], 8)
                }
            } //ztack new
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        Item.reorder(Array(items), from: source, to: destination, in: viewContext)
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach { $0.delete(in: viewContext, undoManager: undoManager) }
        }
    }
}


struct NotesList_Previews : PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone SE (2nd generation)", "iPhone XS Max"], id: \.self) { deviceName in
            NotesList().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .environment(SyncMonitor(container: PersistenceController.preview.container))
                .previewDevice(PreviewDevice(rawValue: deviceName))
        }
    }
}
