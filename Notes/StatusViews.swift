//
//  StatusViews.swift
//  Notes
//
//  Empty state and sync status, shared by macOS and iOS.
//

import SwiftUI

// Shown when there are no notes: first launch, or while notes download from iCloud
struct EmptyStateView: View {
    @Environment(SyncMonitor.self) private var sync

    var body: some View {
        VStack(spacing: 12) {
            if sync.isDownloading {
                ProgressView()
                    .controlSize(.small)
                Text("Bringing your notes from iCloud")
                    .foregroundColor(Theme.text)
            } else {
                Text("Nothing here yet")
                    .foregroundColor(Theme.text)
                Text(hint)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(Theme.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: sync.isDownloading)
    }

    private var hint: String {
        #if os(macOS)
        "Press + or ⌘N to start writing"
        #else
        "Tap + to start writing"
        #endif
    }
}

// Quiet one-line sync indicator: visible only while downloading or when sync fails
struct SyncStatusView: View {
    @Environment(SyncMonitor.self) private var sync

    var body: some View {
        Group {
            if let message = sync.errorMessage {
                Text(message)
            } else if sync.isDownloading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Syncing")
                }
            }
        }
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundColor(Theme.secondaryText)
        .lineLimit(2)
        .animation(.default, value: sync.isDownloading)
    }
}
