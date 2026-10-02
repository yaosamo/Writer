//
//  Store.swift
//  Notes
//
//  Nothing Pro: a one-time, lifetime non-consumable purchase (StoreKit 2).
//  Mac and iOS share the bundle ID, so one purchase unlocks both.
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
    static let proProductID = "com.yaosamo.NothingWriter.pro"

    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var isPurchasing = false
    private(set) var didLoadProduct = false
    private(set) var message: String?

    init() {
        // Purchases made on another device, Ask to Buy approvals and refunds arrive here
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProduct()
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

    func purchase() async {
        guard let product else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                isPro = true
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

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.proProductID]).first
        } catch {
            message = error.localizedDescription
        }
        didLoadProduct = true
    }

    // currentEntitlements is cached by StoreKit, so this works offline
    private func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        #if DEBUG
        // Launch with -debugProUnlocked YES to test Pro features without a purchase
        unlocked = unlocked || UserDefaults.standard.bool(forKey: "debugProUnlocked")
        #endif
        isPro = unlocked
    }
}
