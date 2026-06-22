//
//  PaywallViewModel.swift
//  InspireCreativityApp
//
//  Drives the Pro paywall. All pricing comes from live StoreKit products
//  (never hardcoded), and a purchase only completes through StoreManager's
//  verified StoreKit 2 flow.
//

import Foundation
import StoreKit

@MainActor
final class PaywallViewModel: ObservableObject {

    enum Plan: String, CaseIterable, Identifiable {
        case lifetime
        var id: String { rawValue }

        var productID: String { StoreManager.ProductID.lifetime }

        var title: String { "Lifetime" }

        var badge: String? { nil }
    }

    /// Honest, verifiable benefits only. Anything we don't actually deliver was
    /// removed (no weekly drops, no .swift export, no MIT/source-files claim,
    /// no live parameter editing, no fabricated dollar "value").
    struct Feature: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    let features: [Feature] = [
        .init(title: "Unlock the entire library",
              subtitle: "Every Pro animation, instantly — not just the free ones"),
        .init(title: "Copy production-ready SwiftUI",
              subtitle: "Tap to copy the full source for any animation, ready to paste into Xcode"),
        .init(title: "Browse fully offline",
              subtitle: "The whole catalog is bundled — no account or connection needed"),
        .init(title: "One purchase, all your devices",
              subtitle: "Restore anytime on any device signed in to your Apple ID")
    ]

    @Published var plan: Plan = .lifetime
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    @Published private(set) var didComplete = false

    let store: StoreManager
    private let analytics: AnalyticsTracking

    /// Where the user opened the paywall from (e.g. "detail", "settings",
    /// "promo", "library"). Single source of truth for both `paywall_viewed`
    /// (logged by the view) and `purchase_completed` (logged here on success),
    /// so GA4 attributes the IAP to the same feature that surfaced the paywall.
    let source: String

    init(store: StoreManager, analytics: AnalyticsTracking, source: String) {
        self.store = store
        self.analytics = analytics
        self.source = source
    }

    var isLoadingProducts: Bool { store.isLoadingProducts }
    var productsUnavailable: Bool { store.productsFailedToLoad }

    func product(for plan: Plan) -> Product? { store.product(for: plan.productID) }

    /// Localized price from the live product, e.g. "$59.99". Empty until loaded.
    func displayPrice(for plan: Plan) -> String {
        product(for: plan)?.displayPrice ?? "—"
    }

    /// Per-plan descriptive line, derived from the real product.
    func subtitle(for plan: Plan) -> String {
        guard product(for: plan) != nil else { return " " }
        return "one-time payment · yours forever"
    }

    /// CTA label for the one-time lifetime unlock.
    var ctaTitle: String { "Unlock Lifetime Access" }

    /// Billing disclosure, sourced from the live product so the figure always
    /// matches what the user is charged. Lifetime is a one-time, non-renewing
    /// purchase — no auto-renew terms apply.
    var disclosure: String {
        guard let product = product(for: plan) else {
            return "Prices shown include applicable taxes. Payment is charged to your Apple ID."
        }
        return "\(product.displayPrice) one-time purchase, charged to your Apple ID. Not a subscription."
    }

    func purchaseSelected() async {
        errorMessage = nil
        guard let product = product(for: plan) else {
            errorMessage = StoreManager.StoreError.productsUnavailable.errorDescription
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(product) {
            case .success:
                analytics.log(.purchaseCompleted(productID: product.id, source: source))
                didComplete = true
            case .pending:
                errorMessage = "Your purchase is pending approval. You'll get access once it's approved."
            case .cancelled:
                break
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Purchase failed. Please try again."
        }
    }

    func restore() async {
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await store.restore()
            if store.isPro {
                didComplete = true
            } else {
                errorMessage = "No previous purchases were found for your Apple ID."
            }
        } catch {
            errorMessage = "Couldn't restore purchases. Please try again."
        }
    }
}
