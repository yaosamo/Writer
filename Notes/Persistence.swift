//
//  Persistence.swift
//  NotesCoreBasic
//
//  Created by Yaroslav Samoylov on 12/12/21.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for index in 0..<20 {
            let newItem = Item(context: viewContext)
            newItem.date = Date()
            newItem.note = "Empty note"
            newItem.title = "Empty title"
            newItem.orderIndex = Int16(index)
            newItem.id = UUID()
        }
        viewContext.saveIfNeeded()
        return result
    }()

    let container: NSPersistentCloudKitContainer

    // Set when the store couldn't be opened (locked device, full disk, failed migration);
    // the app shows it instead of crashing
    let loadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Model")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error {
                Logger.persistence.error("Failed to load store: \(error.localizedDescription, privacy: .public)")
                loadError = error
            }
        }
        self.loadError = loadError

        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
