//
//  Store.swift
//  Notes
//
//  Nothing Pro (StoreKit 2): a one-time lifetime purchase, or a monthly subscription.
//  Either one unlocks Pro. Mac and iOS share the bundle ID, so one purchase unlocks both.
//

import Foundation
import Observation
import StoreKit

extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}

@MainActor
@Observable
final class Store {
    static let lifetimeID = "com.yaosamo.NothingWriter.pro"
    static let monthlyID = "com.yaosamo.NothingWriter.pro.monthly"

    // One store for every window: the App struct can be created more than once (window restoration)
    static let shared = Store()

    private(set) var lifetime: Product?
    private(set) var monthly: Product?
    private(set) var isPro = false
    // Pro through the subscription (shows "Manage subscription")
    private(set) var isSubscribed = false
    private(set) var isPurchasing = false
    private(set) var didLoadProducts = false
    private(set) var message: String?

    private init() {
        #if DEBUG
        // Unlocked from the first frame; product loading can take a while
        isPro = UserDefaults.standard.bool(forKey: "debugProUnlocked")
        #endif
        // Purchases made on another device, Ask to Buy approvals, renewals and refunds arrive here
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    // Gate for Pro features: returns true if unlocked, otherwise opens the paywall
    func requirePro() -> Bool {
        if !isPro {
            NotificationCenter.default.post(name: .showPaywall, object: nil)
        }
        return isPro
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                message = "The App Store couldn't verify this purchase"
            case .pending:
                message = "Purchase is waiting for approval"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
        } catch {
            message = error.localizedDescription
        }
        await refreshEntitlement()
        if !isPro && message == nil {
            message = "No previous purchase found"
        }
    }

    #if DEBUG
    // "…" menu switch for testing Pro without a purchase (same as launching with -debugProUnlocked YES)
    var debugPro: Bool { UserDefaults.standard.bool(forKey: "debugProUnlocked") }

    func setDebugPro(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "debugProUnlocked")
        Task { await refreshEntitlement() }
    }
    #endif

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeID, Self.monthlyID])
            lifetime = products.first { $0.id == Self.lifetimeID }
            monthly = products.first { $0.id == Self.monthlyID }
        } catch {
            message = error.localizedDescription
        }
        didLoadProducts = true
    }

    // currentEntitlements is cached by StoreKit (works offline) and only lists active subscriptions
    private func refreshEntitlement() async {
        var lifetimeOwned = false
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            switch transaction.productID {
            case Self.lifetimeID: lifetimeOwned = true
            case Self.monthlyID: subscribed = true
            default: break
            }
        }
        var unlocked = lifetimeOwned || subscribed
        #if DEBUG
        // Launch with -debugProUnlocked YES to test Pro features without a purchase
        unlocked = unlocked || UserDefaults.standard.bool(forKey: "debugProUnlocked")
        #endif
        isPro = unlocked
        isSubscribed = subscribed && !lifetimeOwned
    }
}
