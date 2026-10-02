//
//  Item+Helpers.swift
//  Notes
//
//  Shared note operations for the macOS and iOS targets.
//

import CoreData
import os

let emptyNotePlaceholder = "Free your mind"

extension Logger {
    static let persistence = Logger(subsystem: "com.yaosamo.NothingWriter", category: "Persistence")
}

extension Notification.Name {
    // Posted with the new note's objectID so the list can select it
    static let noteCreated = Notification.Name("noteCreated")
}

extension NSManagedObjectContext {
    // Saves pending changes; logs failures instead of crashing or silently dropping them
    func saveIfNeeded() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            Logger.persistence.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Item {

    // Non-optional bindings for editors; every attribute is optional so synced records may lack them
    var titleText: String {
        get { title ?? "" }
        set { title = newValue }
    }

    var noteText: String {
        get { note ?? "" }
        set { note = newValue }
    }

    // Title shown in the list: explicit title, otherwise the note's first line
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return title
        }
        let firstLine = noteText
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }

    // Creates an empty note above all existing notes
    @discardableResult
    static func create(in context: NSManagedObjectContext) -> Item {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        let existing = (try? context.fetch(request)) ?? []

        var topIndex = existing.first?.orderIndex ?? 0
        if topIndex == Int16.min {
            renumber(existing)
            topIndex = 0
        }

        let item = Item(context: context)
        item.id = UUID()
        item.date = Date()
        item.title = ""
        item.note = ""
        item.orderIndex = topIndex - 1
        context.saveIfNeeded()

        NotificationCenter.default.post(name: .noteCreated, object: item.objectID)
        return item
    }

    // Persists a drag-and-drop reorder of the list
    static func reorder(_ items: [Item], from source: IndexSet, to destination: Int, in context: NSManagedObjectContext) {
        var revised = items
        revised.move(fromOffsets: source, toOffset: destination)
        renumber(revised)
        context.saveIfNeeded()
    }

    // Writes 0...n order indexes, touching only notes whose index changed to keep CloudKit uploads small
    private static func renumber(_ items: [Item]) {
        for (index, item) in items.enumerated() {
            let newIndex = Int16(clamping: index)
            if item.orderIndex != newIndex {
                item.orderIndex = newIndex
            }
        }
    }

    // Deletes the note and registers undo (and redo) with the given undo manager
    func delete(in context: NSManagedObjectContext, undoManager: UndoManager?) {
        let id = id, date = date, title = title, note = note, orderIndex = orderIndex
        context.delete(self)
        context.saveIfNeeded()

        undoManager?.registerUndo(withTarget: context) { [weak undoManager] context in
            let restored = Item(context: context)
            restored.id = id
            restored.date = date
            restored.title = title
            restored.note = note
            restored.orderIndex = orderIndex
            context.saveIfNeeded()
            undoManager?.registerUndo(withTarget: restored) { $0.delete(in: context, undoManager: undoManager) }
        }
        undoManager?.setActionName("Delete Note")
    }
}
