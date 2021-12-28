//
//  NotesApp.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/12/21.
//

import SwiftUI

@main
struct NotesCoreBasicApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Background for the whole view
                .background(Color(red: 0.06, green: 0.07, blue: 0.06))
                .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                .environment(\.managedObjectContext,persistenceController.container.viewContext)
        }
        // Hiding title bar
        .windowStyle(HiddenTitleBarWindowStyle())
        
        // Hide and show sidebar from NavigationView
        .commands() {SidebarCommands()}
        
        
    }
}

