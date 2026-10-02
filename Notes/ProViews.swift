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
                .disabled(store.product == nil || store.isPurchasing)
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
        .presentationDetents([.medium])
        .presentationBackground(palette.background)
        #endif
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: store.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var buttonTitle: String {
        if store.isPurchasing { return "Purchasing" }
        guard let product = store.product else {
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

// "…" menu: new folder, theme, Pro
struct MoreMenu: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            Button {
                if store.requirePro() {
                    Folder.create(in: viewContext)
                }
            } label: {
                Label("New Folder", systemImage: store.isPro ? "folder.badge.plus" : "lock")
            }
            Menu("Theme") {
                ThemeMenuItems()
            }
            Divider()
            Button(store.isPro ? "Nothing Pro: unlocked" : "Nothing Pro…") {
                NotificationCenter.default.post(name: .showPaywall, object: nil)
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
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        #endif
        .accessibilityLabel("More")
    }
}
