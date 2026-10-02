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

    var detail: String {
        switch self {
        case .folders: "Group notes, keep the page quiet"
        case .themes: "Dark Sepia, Midnight and Light"
        case .images: "Paste photos and screenshots into notes"
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
                HStack(alignment: .center, spacing: 48) {
                    video
                        .frame(width: 680)
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        details
                    }
                    .frame(width: 330)
                }
                .padding(.vertical, 28)
                .frame(minHeight: 560)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    video
                    details
                }
            }
        }
        .padding(isWide ? 40 : 32)
        #if os(macOS)
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

    private var header: some View {
        HStack {
            Text("Nothing Pro")
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .foregroundColor(palette.text)
            Spacer()
            Button {
                dismiss()
            } label: {
                // Small glyph, large target: the whole 44pt square closes the sheet
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -14)
            .padding(.vertical, -12)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")
        }
    }

    // The selected feature in motion; cycles on its own, tap a feature to pick it
    private var video: some View {
        LoopingVideo(resource: feature.clip)
            .id(feature)
            .transition(.opacity)
            .aspectRatio(proVideoAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.secondaryText.opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ProFeature.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { feature = item }
                    } label: {
                        featureRow(item.title, item.detail)
                            .opacity(item == feature ? 1 : 0.45)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                featureRow("What comes next", "Future Pro features included")
                    .opacity(0.45)
            }
            .task(id: feature) {
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.3)) { feature = feature.next }
            }

            if store.isPro {
                Text("Unlocked. Thank you.")
                    .foregroundColor(palette.caret)
            } else {
                Button {
                    Task { await store.purchase() }
                } label: {
                    // White on dark themes (the text colour, so it stays visible on Light)
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.colorScheme == .dark ? Color.white : palette.text)
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
    }

    // Close-ups: 16:10 on Mac, 4:3 on iPhone
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

    private func featureRow(_ title: String, _ detail: String) -> some View {
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
