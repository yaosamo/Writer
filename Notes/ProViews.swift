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
private let termsURL = URL(string: "https://github.com/yaosamo/Writer/blob/main/Terms.md")!

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

// Everything else Nothing does, listed under the Pro features
private let includedFeatures = ["Unlimited notes", "Lists and tasks", "Sync across Mac, iPhone and iPad", "and what comes next"]

private enum Plan { case lifetime, monthly }

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var feature: ProFeature = .folders
    @State private var plan: Plan = .lifetime

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
                        .padding(.horizontal, 40)
                        .padding(.top, 44)
                        .padding(.bottom, 24)
                        .frame(width: 400)
                }
                // Fills the window up under the hidden title bar (28pt of safe area on top)
                .frame(maxHeight: .infinity)
                .ignoresSafeArea()
                .frame(height: 572)
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
        .background(surface.ignoresSafeArea())
        .onExitCommand { dismiss() }
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { surface }
        #endif
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: store.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // A step lighter than the editor page
    private var surface: some View {
        ZStack {
            palette.background
            Color.white.opacity(palette.colorScheme == .dark ? 0.06 : 0.5)
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
            Spacer(minLength: 28)
            featureList
            Spacer(minLength: 28)
            purchase
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            ForEach(includedFeatures, id: \.self) { line in
                Text(line)
                    .foregroundColor(palette.text)
                    .opacity(0.4)
            }
        }
        .task(id: feature) {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { feature = feature.next }
        }
    }

    private var purchase: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                planRow(.lifetime, title: "Lifetime", price: price(store.lifetime, demo: "demoPrice"))
                planRow(.monthly, title: "Monthly", price: price(store.monthly, demo: "demoMonthlyPrice").map { "\($0) / month" })
                getButton
                    .padding(.top, 6)
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
            .padding(.top, 6)
        }
    }

    private var selectedProduct: Product? {
        plan == .lifetime ? store.lifetime : store.monthly
    }

    // One choice of the two; the outline marks the selected plan
    private func planRow(_ value: Plan, title: String, price: String?) -> some View {
        let selected = plan == value
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { plan = value }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? palette.text : palette.secondaryText.opacity(0.6), lineWidth: 1)
                    .overlay(Circle().fill(palette.text).padding(4).opacity(selected ? 1 : 0))
                    .frame(width: 16, height: 16)
                Text(title)
                Spacer()
                Text(price ?? (store.didLoadProducts ? "Unavailable" : "…"))
                    .foregroundColor(selected ? palette.text : palette.secondaryText)
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? palette.text.opacity(0.9) : palette.secondaryText.opacity(0.35), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // White on the dark themes, the text colour on Light
    private var getButton: some View {
        Button {
            if let product = selectedProduct { Task { await store.purchase(product) } }
        } label: {
            Text(store.isPurchasing ? "…" : "Get Nothing Pro")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(palette.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(palette.colorScheme == .dark ? Color.white : palette.text)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selectedProduct == nil || store.isPurchasing)
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
