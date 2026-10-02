//
//  FolderRow.swift
//  Notes
//
//  A folder in the note list: styled like a note row, with a chevron on the left.
//  Double-click (double-tap) the name to rename it in place.
//

import SwiftUI
import CoreData

struct FolderRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.palette) private var palette

    @ObservedObject var folder: Folder
    let isExpanded: Bool
    let font: Font
    let toggle: () -> Void
    // The folder currently being renamed, shared with the list
    @Binding var renamingID: NSManagedObjectID?

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var isRenaming: Bool { renamingID == folder.objectID }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")

            if isRenaming {
                TextField("Folder name", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onAppear {
                        draft = folder.name ?? ""
                        isFocused = true
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                #if os(macOS)
                    .onExitCommand { renamingID = nil }
                #endif
            } else {
                Text(folder.displayName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { renamingID = folder.objectID }
                    .onTapGesture(perform: toggle)
            }
        }
        .font(font)
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }

    private func commit() {
        guard isRenaming else { return }
        let name = draft.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            folder.name = name
            viewContext.saveIfNeeded()
        }
        renamingID = nil
    }
}
