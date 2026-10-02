//
//  ContentView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/12/21.
//

import SwiftUI


struct ContentView: View {
    let loadError: Error?

    @State private var showPaywall = false

    var body: some View {
        Group {
            if let loadError {
                StoreErrorView(error: loadError)
            } else {
                NotesList()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
            showPaywall = true
        }
    }
}

// Shown when the notes database can't be opened
struct StoreErrorView: View {
    let error: Error
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 16) {
            Text("Couldn't open your notes")
                .foregroundColor(palette.text)
            Text("Nothing was deleted. Try restarting the app or freeing up storage.\n\n\(error.localizedDescription)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView(loadError: nil)
    }
}
