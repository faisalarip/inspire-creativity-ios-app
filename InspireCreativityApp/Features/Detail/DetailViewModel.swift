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
    @Published private(set) var isOwned: Bool
    /// True when the Pro entitlement is active (StoreKit-derived), regardless
    /// of the signed-in state. Feeds `CodeAccess.evaluate`.
    @Published private(set) var hasPro: Bool

    private let favorites: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol
    ) {
        // Resolve the item once (fall back to featured for unknown ids), assign
        // stored props, then wire bindings unconditionally so the detail screen
        // always reflects later favorite / entitlement changes.
        let resolved = repository.find(id: animationId) ?? repository.featured()
        self.item = resolved
        self.favorites = favorites
        self.purchases = purchases
        self.isFavorited = favorites.isFavorite(resolved.id)
        self.isOwned = purchases.isOwned(resolved.id, freeOverride: resolved.isFree)
        self.hasPro = purchases.isPro
        bind()
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
    }
}
