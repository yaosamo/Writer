//
//  ProViews.swift
//  Notes
//
//  Paywall, theme picker and the "more" menu, shared by macOS and iOS.
//

import SwiftUI
import CoreData
import StoreKit

private let privacyURL = URL(string: "https://github.com/yaosamo/Writer/blob/main/PrivacyPolicy.md")!
private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

// Pro features shown in the paywall, each with a short close-up clip
private enum ProFeature: CaseIterable {
    case folders, themes, images

    var title: String {
        switch self {
        case .folders: "Folders"
        case .themes: "Themes"
        case .images: "Images"
        }
    }

    var clip: String { "Pro-\(self)" }

    var next: ProFeature {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var feature: ProFeature = .folders

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    // Mac, iPad and unfolded: video on the left, everything else on the right
    private var isWide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 0) {
                    // Inset 8pt from the window edges; corners follow the window's (minus the inset)
                    clip(cornerRadius: 10)
                        .frame(width: 640)
                        .frame(maxHeight: .infinity)
                        .padding([.leading, .top, .bottom], 8)
                    side
                        .padding(.horizontal, 44)
                        .padding(.vertical, 48)
                        .frame(width: 400)
                }
                .frame(height: 580)
                .ignoresSafeArea()
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    clip(cornerRadius: 14)
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    side
                }
                .padding(20)
            }
        }
        #if os(macOS)
        .background(palette.background)
        .onExitCommand { dismiss() }
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
        #endif
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: store.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // The selected feature in motion; cycles on its own, tap a feature to pick it
    private func clip(cornerRadius: CGFloat) -> some View {
        LoopingVideo(resource: feature.clip)
            .id(feature)
            .transition(.opacity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing Pro")
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .foregroundColor(palette.text)
            Spacer(minLength: 32)
            featureList
            Spacer(minLength: 32)
            purchase
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ProFeature.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { feature = item }
                } label: {
                    Text(item.title)
                        .foregroundColor(palette.text)
                        .opacity(item == feature ? 1 : 0.4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("and what comes next")
                .foregroundColor(palette.secondaryText)
        }
        .task(id: feature) {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { feature = feature.next }
        }
    }

    private var purchase: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isPro {
                Text("Unlocked. Thank you.")
                    .foregroundColor(palette.text)
                if store.isSubscribed {
                    Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(palette.secondaryText)
                }
            } else {
                option("Lifetime", price: price(store.lifetime, demo: "demoPrice"), primary: true) {
                    if let product = store.lifetime { Task { await store.purchase(product) } }
                }
                option("Monthly", price: price(store.monthly, demo: "demoMonthlyPrice").map { "\($0) / month" }, primary: false) {
                    if let product = store.monthly { Task { await store.purchase(product) } }
                }
                Text("Monthly renews until you cancel it in Settings.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
            }

            if let message = store.message {
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
            }

            HStack(spacing: 16) {
                if !store.isPro {
                    Button("Restore") {
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
            .padding(.top, 8)
        }
    }

    // Lifetime: white (the text colour on Light); monthly: outlined
    private func option(_ title: String, price: String?, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(price ?? (store.didLoadProducts ? "Unavailable" : "…"))
            }
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(primary ? palette.background : palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(primary ? (palette.colorScheme == .dark ? Color.white : palette.text) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(primary ? Color.clear : palette.secondaryText.opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(price == nil || store.isPurchasing)
    }

    private func price(_ product: Product?, demo key: String) -> String? {
        if let product { return product.displayPrice }
        #if DEBUG
        // Demo recordings: -demoPrice '$29.99' -demoMonthlyPrice '$0.99'
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        #endif
        return nil
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
    var iconSize: CGFloat = 15

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
            CircleIcon(systemName: "ellipsis", iconsize: iconSize)
        }
        .circleMenuStyle()
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
