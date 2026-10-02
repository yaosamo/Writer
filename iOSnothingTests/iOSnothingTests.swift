//
//  iOSnothingTests.swift
//  iOSnothingTests
//
//  Created by Yaroslav Samoylov on 1/21/22.
//

import XCTest
import CoreData
@testable import Nothing

final class iOSnothingTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        context = PersistenceController(inMemory: true).container.viewContext
    }

    private func notes(in folder: Folder?) throws -> [Item] {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = folder.map { NSPredicate(format: "folder == %@", $0) } ?? NSPredicate(format: "folder == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        return try context.fetch(request)
    }

    func testNewNotesGoOnTopAndStartEmpty() throws {
        let first = Item.create(in: context)
        let second = Item.create(in: context)

        XCTAssertEqual(try notes(in: nil), [second, first])
        XCTAssertEqual(second.noteText, "")
        XCTAssertEqual(second.displayTitle, "Untitled")
    }

    func testDisplayTitleFallsBackToFirstLine() {
        let note = Item.create(in: context)
        note.note = "\n  Groceries \n- milk"
        XCTAssertEqual(note.displayTitle, "Groceries")
        note.title = "Shopping"
        XCTAssertEqual(note.displayTitle, "Shopping")
    }

    func testReorderPersistsOrder() throws {
        let a = Item.create(in: context)
        let b = Item.create(in: context)
        let c = Item.create(in: context)
        // List order is c, b, a; drag c to the end
        Item.reorder([c, b, a], from: IndexSet(integer: 0), to: 3, in: context)
        XCTAssertEqual(try notes(in: nil), [b, a, c])
    }

    func testNotesAreOrderedPerFolder() throws {
        let folder = Folder.create(in: context, name: "Projects")
        let loose = Item.create(in: context)
        let filed = Item.create(in: context, folder: folder)

        XCTAssertEqual(try notes(in: nil), [loose])
        XCTAssertEqual(try notes(in: folder), [filed])

        loose.move(to: folder, in: context)
        XCTAssertEqual(try notes(in: folder), [loose, filed])
        XCTAssertEqual(try notes(in: nil), [])
    }

    func testDeletingFolderKeepsItsNotes() throws {
        let folder = Folder.create(in: context, name: "Projects")
        let note = Item.create(in: context, folder: folder)

        folder.deleteKeepingNotes(in: context)

        XCTAssertFalse(note.isDeleted)
        XCTAssertNil(note.folder)
        XCTAssertEqual(try notes(in: nil), [note])
    }

    func testDeleteIsUndoable() throws {
        let undoManager = UndoManager()
        let folder = Folder.create(in: context, name: "Projects")
        let note = Item.create(in: context, folder: folder)
        note.note = "keep me"
        let id = note.id

        note.delete(in: context, undoManager: undoManager)
        XCTAssertEqual(try notes(in: folder), [])

        undoManager.undo()
        let restored = try XCTUnwrap(try notes(in: folder).first)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.note, "keep me")
    }

    func testFoldersAppendInOrder() throws {
        let a = Folder.create(in: context, name: "A")
        let b = Folder.create(in: context, name: "B")
        XCTAssertLessThan(a.orderIndex, b.orderIndex)
        XCTAssertEqual(Folder.create(in: context, name: " ").displayName, "Untitled folder")
    }
}
