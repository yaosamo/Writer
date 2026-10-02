//
//  ContentView.swift
//  Notes
//
//  Created by Yaroslav Samoylov on 12/12/21.
//

import SwiftUI


struct ContentView: View {
    let loadError: Error?

    var body: some View {
        if let loadError {
            StoreErrorView(error: loadError)
        } else {
            NotesList()
        }
    }
}

// Shown when the notes database can't be opened
struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Text("Couldn't open your notes")
                .foregroundColor(Theme.text)
            Text("Nothing was deleted. Try restarting the app or freeing up storage.\n\n\(error.localizedDescription)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.secondaryText)
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
