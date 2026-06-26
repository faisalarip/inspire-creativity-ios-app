//
//  DetailViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

/// Three-way access decision for the code sheet. Pure logic so the gate is
/// unit-testable. Purchasing never requires an account: a Pro entitlement
/// unlocks code in ANY auth state (a signed-out buyer or Restore must never
/// stay locked out), Pro items route to the paywall, and free items ask
/// signed-out users for the (free) sign-in.
enum CodeAccess: Equatable {
    case granted
    case needsSignIn
    case needsPro

    static func evaluate(itemIsPro: Bool,
                         hasProEntitlement: Bool,
                         isAuthenticated: Bool) -> CodeAccess {
        if hasProEntitlement { return .granted }
        if itemIsPro { return .needsPro }
        return isAuthenticated ? .granted : .needsSignIn
    }
}

@MainActor
final class DetailViewModel: ObservableObject {

    let item: AnimationItem
    @Published private(set) var isFavorited: Bool

    /// SwiftUI source for the code sheet, resolved on demand. Aurora catalog
    /// items ship with an empty `swiftCode` (generation is deferred off the
    /// launch path), so regenerate it the first time it's needed from the
    /// item's descriptor. Computed once, then cached.
    lazy var code: String = {
        if !item.swiftCode.isEmpty { return item.swiftCode }
        if let descriptor = AuroraDescriptors.byId[item.id]
            ?? AnimationPreviewRegistry.runtimeDescriptors[item.id] {
            return AuroraCodeGen.swiftCode(for: descriptor)
        }
        return item.swiftCode
    }()
    @Published private(set) var isOwned: Bool
    /// True when the Pro entitlement is active (StoreKit-derived), regardless
    /// of the signed-in state. Feeds `CodeAccess.evaluate`.
    @Published private(set) var hasPro: Bool

    private let favorites: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private let analytics: AnalyticsTracking
    private var cancellables: Set<AnyCancellable> = []

    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker()
    ) {
        // Resolve the item once (fall back to featured for unknown ids), assign
        // stored props, then wire bindings unconditionally so the detail screen
        // always reflects later favorite / entitlement changes.
        let resolved = repository.find(id: animationId) ?? repository.featured()
        self.item = resolved
        self.favorites = favorites
        self.purchases = purchases
        self.analytics = analytics
        self.isFavorited = favorites.isFavorite(resolved.id)
        self.isOwned = purchases.isOwned(resolved.id, freeOverride: resolved.isFree)
        self.hasPro = purchases.isPro
        bind()
        analytics.log(.animationView(id: resolved.id,
                                     category: resolved.category.rawValue,
                                     isPro: resolved.isPro))
    }

    private func bind() {
        let id = item.id
        let isFree = item.isFree

        favorites.idsPublisher
            .map { $0.contains(id) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFavorited)

        purchases.isProPublisher
            .map { isPro in isFree || isPro }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOwned)

        purchases.isProPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasPro)
    }

    func toggleFavorite() {
        favorites.toggle(item.id)
        // Log the RESULTING state from the repository's synchronous source of
        // truth. `isFavorited` is updated asynchronously via `idsPublisher`, so
        // it still holds the stale pre-toggle value at this point.
        analytics.log(.favoriteToggled(id: item.id, on: favorites.isFavorite(item.id)))
    }

    /// Logs a code-copy from the leaf `CodeSheet` via an injected closure, so
    /// the view itself never holds the analytics dependency or the item id.
    func logCodeCopied() {
        analytics.log(.codeCopied(id: item.id))
    }
}
