//
//  ProViews.swift
//  Notes
//
//  Paywall, theme picker and the "more" menu, shared by macOS and iOS.
//

import SwiftUI
import CoreData
import StoreKit
import AVFoundation

private let privacyURL = URL(string: "https://github.com/yaosamo/Writer/blob/main/PrivacyPolicy.md")!
private let termsURL = URL(string: "https://github.com/yaosamo/Writer/blob/main/Terms.md")!

// Every line in the paywall has a short clip showing it; the list plays through them in turn
private enum ProFeature: String, CaseIterable {
    case folders, themes, images, notes, lists, sync, next

    var title: String {
        switch self {
        case .folders: "Folders"
        case .themes: "Themes"
        case .images: "Images in notes"
        case .notes: "Unlimited notes"
        case .lists: "Lists and tasks"
        case .sync: "Mac, iPhone and iPad"
        case .next: "Everything that comes next"
        }
    }

    var clip: String { "Pro-\(rawValue)" }

    var next: ProFeature {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    // How long the item stays selected: its clip, played once
    func duration() async -> Double {
        guard let url = Bundle.main.url(forResource: clip, withExtension: "mp4"),
              let time = try? await AVURLAsset(url: url).load(.duration) else { return 6 }
        return max(3, time.seconds)
    }
}

private enum Plan { case lifetime, monthly }

struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var feature: ProFeature = .folders
    @State private var progress: CGFloat = 0
    @State private var plan: Plan = .lifetime

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    // Mac, iPad and unfolded: the clip on the left, everything else on the right
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
                    // Full height of the sheet, inset 8pt; corners follow the sheet's
                    clip(cornerRadius: 12)
                        .frame(width: 564 * clipAspect, height: 564)
                        .padding(8)
                    side
                        .padding(.leading, 28)
                        .padding(.trailing, 32)
                        .padding(.top, 36)
                        .padding(.bottom, 24)
                        .frame(width: 360)
                }
                .frame(height: 580)
                .overlay(alignment: .topTrailing) {
                    closeButton(onVideo: false).padding(8)
                }
            } else {
                // Sized so the list, the plans and the button fit on one phone screen
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        clip(cornerRadius: 16)
                            .frame(width: 300 * clipAspect, height: 300)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                        side
                            .padding(.horizontal, 12)
                    }
                    .padding(8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .topTrailing) {
                    closeButton(onVideo: false).padding(6)
                }
            }
        }
        #if os(macOS)
        .background(surface.ignoresSafeArea())
        #else
        .presentationDetents([.large])
        .presentationBackground { surface }
        #endif
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: store.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
        .task(id: feature) {
            // The bar under the playing item fills over its clip, then the next one starts
            progress = 0
            let seconds = await feature.duration()
            withAnimation(.linear(duration: seconds)) { progress = 1 }
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            feature = feature.next
        }
    }

    // Mac clips are square; iPhone clips are a 5:6 slice of the screen
    private var clipAspect: CGFloat {
        #if os(macOS)
        1
        #else
        1080.0 / 1296.0
        #endif
    }

    // A step lighter than the editor page
    private var surface: some View {
        ZStack {
            palette.background
            Color.white.opacity(palette.colorScheme == .dark ? 0.06 : 0)
        }
    }

    private func clip(cornerRadius: CGFloat) -> some View {
        LoopingVideo(resource: feature.clip)
            .id(feature)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private func closeButton(onVideo: Bool) -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(onVideo ? .white : palette.secondaryText)
                .frame(width: 28, height: 28)
                .background(Circle().fill(onVideo ? Color.black.opacity(0.45) : palette.text.opacity(0.08)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close")
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing Pro")
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .foregroundColor(palette.text)
            Spacer(minLength: 24)
            featureList
            Spacer(minLength: 24)
            purchase
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ProFeature.allCases, id: \.self) { item in
                Button {
                    feature = item
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .foregroundColor(palette.text)
                            .opacity(item == feature ? 1 : 0.4)
                        // Always takes its 2pt, so rows don't move when the selection does
                        GeometryReader { proxy in
                            Capsule()
                                .fill(palette.caret)
                                .frame(width: proxy.size.width * (item == feature ? progress : 0))
                        }
                        .frame(width: 120, height: 2)
                        .opacity(item == feature ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == feature ? .isSelected : [])
            }
        }
        .font(.system(size: 14, weight: .regular, design: .monospaced))
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
                planPicker
                getButton
                    .padding(.top, 4)
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
            .padding(.top, 4)
        }
    }

    // Two choices; on a phone they sit side by side to save height
    @ViewBuilder
    private var planPicker: some View {
        let lifetime = price(store.lifetime, demo: "demoPrice")
        let monthly = price(store.monthly, demo: "demoMonthlyPrice").map { "\($0) / month" }
        if isWide {
            planRow(.lifetime, title: "Lifetime", price: lifetime)
            planRow(.monthly, title: "Monthly", price: monthly)
        } else {
            HStack(spacing: 10) {
                planRow(.lifetime, title: "Lifetime", price: lifetime)
                planRow(.monthly, title: "Monthly", price: monthly)
            }
        }
    }

    private var selectedProduct: Product? {
        plan == .lifetime ? store.lifetime : store.monthly
    }

    // The outline and the filled dot mark the selected plan
    private func planRow(_ value: Plan, title: String, price: String?) -> some View {
        let selected = plan == value
        let priceText = Text(price ?? (store.didLoadProducts ? "Unavailable" : "…"))
            .foregroundColor(selected ? palette.text : palette.secondaryText)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { plan = value }
        } label: {
            HStack(alignment: isWide ? .center : .top, spacing: 10) {
                Circle()
                    .strokeBorder(selected ? palette.text : palette.secondaryText.opacity(0.6), lineWidth: 1)
                    .overlay(Circle().fill(palette.text).padding(4).opacity(selected ? 1 : 0))
                    .frame(width: 16, height: 16)
                if isWide {
                    Text(title)
                    Spacer()
                    priceText
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                        priceText.font(.system(size: 12, design: .monospaced))
                    }
                    Spacer(minLength: 0)
                }
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
        // Demo builds show prices without products; keep the button looking live there
        .disabled((selectedProduct == nil && !hasDemoPrice) || store.isPurchasing)
    }

    private var hasDemoPrice: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "demoPrice") != nil
        #else
        false
        #endif
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
    @AppStorage(AppTheme.storageKey) private var themeName = AppTheme.dark.rawValue
    var iconSize: CGFloat = 15

    var body: some View {
        #if os(macOS)
        AppMenuButton(systemName: "ellipsis", iconsize: iconSize, label: "More", help: "Theme and Nothing Pro") {
            var items: [AppMenuItem] = []
            if !store.isPro {
                items.append(AppMenuItem("Unlock Nothing Pro…", image: "sparkle") {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                })
                items.append(.separator)
            }
            let themes = AppTheme.allCases.map { theme in
                AppMenuItem(theme.name,
                            image: theme.requiresPro && !store.isPro ? "lock" : nil,
                            checked: theme.rawValue == themeName) {
                    if !theme.requiresPro || store.requirePro() {
                        themeName = theme.rawValue
                    }
                }
            }
            items.append(AppMenuItem("Theme", children: themes))
            if store.isPro {
                items.append(.separator)
                items.append(AppMenuItem("Nothing Pro: unlocked") {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                })
            }
            #if DEBUG
            // Hidden in demo recordings
            if !UserDefaults.standard.bool(forKey: "demoContent") {
                items.append(.separator)
                let debugPro = store.debugPro
                items.append(AppMenuItem("Debug: Pro", checked: debugPro) { store.setDebugPro(!debugPro) })
            }
            #endif
            return items
        }
        #else
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
            #if DEBUG
            if !UserDefaults.standard.bool(forKey: "demoContent") {
                Divider()
                Button {
                    store.setDebugPro(!store.debugPro)
                } label: {
                    if store.debugPro {
                        Label("Debug: Pro", systemImage: "checkmark")
                    } else {
                        Text("Debug: Pro")
                    }
                }
            }
            #endif
        } label: {
            CircleIcon(systemName: "ellipsis", iconsize: iconSize)
        }
        .circleMenuStyle()
        .accessibilityLabel("More")
        .help("Theme and Nothing Pro")
        #endif
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
