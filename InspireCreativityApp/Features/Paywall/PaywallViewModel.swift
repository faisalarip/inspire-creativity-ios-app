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

    var features: [Feature] {
        [
        .init(title: proCount > 0 ? "Unlock all \(proCount) Pro animations" : "Unlock the entire library",
              subtitle: "Every Pro animation, instantly — not just the free ones"),
        .init(title: "Copy production-ready SwiftUI",
              subtitle: "Tap to copy the full source for any animation, ready to paste into Xcode"),
        .init(title: "Browse fully offline",
              subtitle: "The whole catalog is bundled — no account or connection needed"),
        .init(title: "One purchase, all your devices",
              subtitle: "Restore anytime on any device signed in to your Apple ID"),
        ]
    }

    @Published var plan: Plan = .lifetime
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    /// Soft, non-error nudge after a cancelled purchase sheet — the moment is
    /// recoverable, silence isn't (audit: cancels were completely unhandled).
    @Published private(set) var recoveryHint: String?
    @Published private(set) var didComplete = false

    let store: StoreManager
    private let analytics: AnalyticsTracking

    /// Where the user opened the paywall from (e.g. "detail", "settings",
    /// "promo", "library"). Single source of truth for both `paywall_viewed`
    /// (logged by the view) and `purchase_completed` (logged here on success),
    /// so GA4 attributes the IAP to the same feature that surfaced the paywall.
    let source: String

    /// The animation that triggered this paywall (when opened from Detail).
    /// Shown as a contextual hero so the paywall sells the exact thing the
    /// user already wanted instead of a generic pitch.
    let contextItem: AnimationItem?
    /// Live Pro-catalog count for honest "all N animations" copy.
    let proCount: Int

    private let journeyMetrics: JourneyMetrics
    private let signedIn: () -> Bool
    private let now: () -> Date
    private var appearedAt: Date?

    init(store: StoreManager, analytics: AnalyticsTracking, source: String,
         journeyMetrics: JourneyMetrics = JourneyMetrics(),
         signedIn: @escaping () -> Bool = { false },
         contextItem: AnimationItem? = nil,
         proCount: Int = 0,
         now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.analytics = analytics
        self.source = source
        self.journeyMetrics = journeyMetrics
        self.signedIn = signedIn
        self.contextItem = contextItem
        self.proCount = proCount
        self.now = now
    }

    /// Honest price anchor derived from the LIVE StoreKit price and the real
    /// catalog count — never a fabricated compare-at price (see the Feature
    /// honesty note above).
    var perAnimationAnchor: String? {
        guard proCount > 0,
              let product = store.product(for: Plan.lifetime.productID) else { return nil }
        let per = product.price / Decimal(proCount)
        let formatted = per.formatted(product.priceFormatStyle)
        return "One payment ≈ \(formatted) per animation — not a subscription."
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
        recoveryHint = nil
        guard let product = product(for: plan) else {
            errorMessage = StoreManager.StoreError.productsUnavailable.errorDescription
            return
        }
        analytics.log(.purchaseInitiated(productID: product.id, source: source))
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(product) {
            case .success:
                analytics.log(.purchaseCompleted(productID: product.id, source: source,
                                                 context: journeyMetrics.snapshotForPurchase(signedIn: signedIn())))
                didComplete = true
            case .pending:
                analytics.log(.purchaseCancelled(productID: product.id, source: source, reason: "pending"))
                errorMessage = "Your purchase is pending approval. You'll get access once it's approved."
            case .cancelled:
                analytics.log(.purchaseCancelled(productID: product.id, source: source, reason: "user_cancelled"))
                recoveryHint = "No charge was made. It's a one-time purchase — here whenever you're ready."
            }
        } catch {
            let verificationFailed = (error as? StoreManager.StoreError) == .failedVerification
            analytics.log(.purchaseFailed(productID: product.id, source: source,
                                          reason: verificationFailed ? "verification_failed" : "error"))
            // A verification failure happens AFTER Apple took payment — send
            // the user to Restore instead of a dead-end generic error.
            errorMessage = verificationFailed
                ? "Your payment went through but couldn't be verified yet. Tap Restore in a moment to unlock."
                : ((error as? LocalizedError)?.errorDescription ?? "Purchase failed. Please try again.")
        }
    }

    func restore() async {
        errorMessage = nil
        recoveryHint = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await store.restore()
            if store.isPro {
                analytics.log(.restoreCompleted(source: source))
                didComplete = true
            } else {
                analytics.log(.restoreFailed(source: source, reason: "no_purchases"))
                errorMessage = "No previous purchases were found for your Apple ID."
            }
        } catch {
            analytics.log(.restoreFailed(source: source, reason: "error"))
            errorMessage = "Couldn't restore purchases. Please try again."
        }
    }

    func markAppeared() {
        appearedAt = now()
        // A silent product-load failure renders a paywall without a price —
        // retry on every open and log when pricing still can't render, so
        // revenue-killing StoreKit config issues show up in analytics.
        if store.products.isEmpty {
            Task { [store, analytics, source] in
                await store.loadProducts()
                if store.products.isEmpty {
                    analytics.log(.pricingUnavailable(source: source))
                }
            }
        }
    }

    func logDismissedIfNeeded() {
        guard !didComplete, let appearedAt else { return }
        let bucket = JourneyMetrics.secondsBucket(now().timeIntervalSince(appearedAt))
        analytics.log(.paywallDismissed(source: source, secondsBucket: bucket))
    }

    #if DEBUG
    /// Test hook: simulate a completed purchase without StoreKit.
    func markCompletedForTesting() { didComplete = true }
    #endif
}
