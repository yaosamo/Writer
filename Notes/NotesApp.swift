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
    @State private var store = Store.shared
    @AppStorage(AppTheme.storageKey) private var themeName = AppTheme.dark.rawValue

    // Pro themes fall back to Dark if Pro isn't (or is no longer) unlocked
    private var theme: AppTheme {
        let chosen = AppTheme(rawValue: themeName) ?? .dark
        return chosen.requiresPro && !store.isPro ? .dark : chosen
    }

    var body: some Scene {
        mainWindow
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    persistenceController.container.viewContext.saveIfNeeded()
                }
            }
            .commands {
                NoteCommands()
                CommandGroup(after: .appInfo) {
                    Button("Nothing Pro…") {
                        NotificationCenter.default.post(name: .showPaywall, object: nil)
                    }
                }
            }
    }

    // One window on macOS: menu commands and the paywall always target it
    #if os(macOS)
    private var mainWindow: some Scene {
        // Hiding title bar
        Window("Nothing", id: "main") { root }
            .windowStyle(HiddenTitleBarWindowStyle())
    }
    #else
    private var mainWindow: some Scene {
        WindowGroup { root }
    }
    #endif

    private var root: some View {
        ContentView(loadError: persistenceController.loadError)
            .ignoresSafeArea()
            .background(theme.palette.background)
            .font(.system(size: 16, weight: Font.Weight.thin, design: .monospaced))
            .environment(\.managedObjectContext,persistenceController.container.viewContext)
            .environment(syncMonitor)
            .environment(store)
            .environment(\.palette, theme.palette)
            .preferredColorScheme(theme.palette.colorScheme)
        #if os(macOS)
            // Flush the editor's pending debounced save on quit
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                persistenceController.container.viewContext.saveIfNeeded()
            }
        #endif
    }
}
