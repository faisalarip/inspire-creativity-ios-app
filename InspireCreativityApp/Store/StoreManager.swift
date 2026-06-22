//
//  StoreManager.swift
//  InspireCreativityApp
//
//  StoreKit 2 entitlement authority. This is the single source of truth for
//  "is the user Pro." Pro is granted ONLY by a verified StoreKit transaction
//  (the lifetime non-consumable) — never by a local flag. A long-lived
//  `Transaction.updates` listener keeps entitlements in sync with refunds and
//  Ask-to-Buy approvals.
//
//  The product ID below must be created verbatim in App Store Connect (and is
//  mirrored in Resources/Products.storekit for local/simulator testing).
//

import Foundation
import StoreKit
import Combine

@MainActor
final class StoreManager: ObservableObject, PurchaseRepositoryProtocol {

    /// App Store Connect product identifier. Create this exactly in ASC:
    ///   • lifetime → Non-Consumable
    enum ProductID {
        static let lifetime = "com.faisalarip.InspireCreativityApp.pro.lifetime"
        static let all: [String] = [lifetime]
    }

    enum PurchaseOutcome { case success, pending, cancelled }

    enum StoreError: LocalizedError {
        case failedVerification
        case productsUnavailable
        var errorDescription: String? {
            switch self {
            case .failedVerification: return "We couldn't verify that purchase with the App Store."
            case .productsUnavailable: return "Pricing is unavailable right now. Check your connection and try again."
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var productsFailedToLoad: Bool = false
    /// Set true right after a fresh purchase completes (not on restore), so the
    /// UI can show a one-time "you're Pro" celebration. The view resets it.
    @Published var justPurchased: Bool = false

    /// Analytics sink. Settable (rather than init-injected) so the many
    /// existing `StoreManager()` call sites stay unchanged; `AppContainer`
    /// assigns the real tracker right after construction.
    var analytics: AnalyticsTracking = NoOpAnalyticsTracker()

    // MARK: - PurchaseRepositoryProtocol

    var isProPublisher: AnyPublisher<Bool, Never> { $isPro.eraseToAnyPublisher() }

    /// An animation is accessible if it's free, or the user holds Pro.
    func isOwned(_ id: String, freeOverride: Bool) -> Bool {
        freeOverride || isPro
    }

    // MARK: - Lifecycle

    private var updatesListener: Task<Void, Never>?

    init() {
        // Start listening BEFORE anything else so we never miss a transaction.
        updatesListener = listenForTransactions()
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    deinit { updatesListener?.cancel() }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        productsFailedToLoad = false
        do {
            let fetched = try await Product.products(for: ProductID.all)
            self.products = fetched
            productsFailedToLoad = fetched.isEmpty
        } catch {
            productsFailedToLoad = true
        }
        isLoadingProducts = false
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Purchase / Restore

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            justPurchased = true
            analytics.log(.purchaseCompleted(productID: product.id))
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Restores prior purchases. `AppStore.sync()` forces a refresh against the
    /// signed-in Apple ID; entitlements are then re-derived locally.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Recomputes `isPro` from the set of currently-valid entitlements. This is
    /// the ONLY place `isPro` is set, so it can never drift from StoreKit.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
