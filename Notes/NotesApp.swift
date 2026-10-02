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
    @Environment(\.scenePhase) private var scenePhase
    @State private var syncMonitor = SyncMonitor(container: PersistenceController.shared.container)

    var body: some Scene {
        WindowGroup {
            ContentView(loadError: persistenceController.loadError)
                .ignoresSafeArea()
                .background(Theme.background)
                .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
                .environment(\.managedObjectContext,persistenceController.container.viewContext)
                .environment(syncMonitor)
                .preferredColorScheme(.dark)
            #if os(macOS)
                // Flush the editor's pending debounced save on quit
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    persistenceController.container.viewContext.saveIfNeeded()
                }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                persistenceController.container.viewContext.saveIfNeeded()
            }
        }
        // Hiding title bar
        #if os(macOS)
        .windowStyle(HiddenTitleBarWindowStyle())
        #endif
    }
}
