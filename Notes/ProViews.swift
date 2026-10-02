//
//  ProViews.swift
//  Notes
//
//  Paywall, theme picker and the "more" menu, shared by macOS and iOS.
//

import SwiftUI
import CoreData

private let privacyURL = URL(string: "https://github.com/yaosamo/Writer/blob/main/PrivacyPolicy.md")!
private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Text("Nothing Pro")
                    .font(.system(size: 20, weight: .regular, design: .monospaced))
                    .foregroundColor(palette.text)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(palette.secondaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }

            // Folders and themes in motion
            LoopingVideo(resource: "ProVideo")
                .aspectRatio(proVideoAspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.secondaryText.opacity(0.2), lineWidth: 1))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                feature("Folders", "Group notes, keep the page quiet")
                feature("Themes", "Dark Sepia, Midnight and Light")
                feature("What comes next", "Future Pro features included")
            }

            if store.isPro {
                Text("Unlocked. Thank you.")
                    .foregroundColor(palette.caret)
            } else {
                Button {
                    Task { await store.purchase() }
                } label: {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.caret)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canPurchase)
            }

            if let message = store.message {
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
            }

            HStack(spacing: 16) {
                if !store.isPro {
                    Button("Restore purchase") {
                        Task { await store.restore() }
                    }
                }
                Spacer()
                Link("Privacy", destination: privacyURL)
                Link("Terms", destination: termsURL)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(palette.secondaryText)
        }
        .padding(32)
        #if os(macOS)
        .frame(width: 400)
        .background(palette.background)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(palette.background)
        #endif
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: store.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // Mac clip is a window (16:10), iPhone clip a crop of the note list (4:3)
    private var proVideoAspect: CGFloat {
        #if os(macOS)
        16.0 / 10.0
        #else
        4.0 / 3.0
        #endif
    }

    private var canPurchase: Bool {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "demoPrice") != nil { return true }
        #endif
        return store.product != nil && !store.isPurchasing
    }

    private var buttonTitle: String {
        if store.isPurchasing { return "Purchasing" }
        guard let product = store.product else {
            #if DEBUG
            // Demo recordings: -demoPrice '$9.99' when no StoreKit configuration is loaded
            if let price = UserDefaults.standard.string(forKey: "demoPrice") {
                return "Unlock for \(price), once"
            }
            #endif
            return store.didLoadProduct ? "App Store unavailable" : "Loading"
        }
        return "Unlock for \(product.displayPrice), once"
    }

    private func feature(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(palette.text)
            Text(detail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(palette.secondaryText)
        }
    }
}

// Theme choices for a Menu; locked themes open the paywall
struct ThemeMenuItems: View {
    @Environment(Store.self) private var store
    @AppStorage(AppTheme.storageKey) private var themeName = AppTheme.dark.rawValue

    var body: some View {
        ForEach(AppTheme.allCases) { theme in
            Button {
                if !theme.requiresPro || store.requirePro() {
                    themeName = theme.rawValue
                }
            } label: {
                if theme.rawValue == themeName {
                    Label(theme.name, systemImage: "checkmark")
                } else if theme.requiresPro && !store.isPro {
                    Label(theme.name, systemImage: "lock")
                } else {
                    Text(theme.name)
                }
            }
        }
    }
}

// "…" menu: Nothing Pro and theme
struct MoreMenu: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            if !store.isPro {
                Button {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                } label: {
                    Label("Unlock Nothing Pro…", systemImage: "sparkle")
                }
                Divider()
            }
            Menu("Theme") {
                ThemeMenuItems()
            }
            if store.isPro {
                Divider()
                Button("Nothing Pro: unlocked") {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(palette.buttonForeground)
                .frame(width: 48, height: 48)
            #if os(iOS)
                .background(palette.buttonBackground)
                .clipShape(Circle())
            #endif
        }
        .circleButtonChrome()
        .accessibilityLabel("More")
        .help("Theme and Nothing Pro")
    }
}

// File menu: New Note / New Folder
struct NoteCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                NotificationCenter.default.post(name: .newNoteRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            Button("New Folder") {
                NotificationCenter.default.post(name: .newFolderRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
