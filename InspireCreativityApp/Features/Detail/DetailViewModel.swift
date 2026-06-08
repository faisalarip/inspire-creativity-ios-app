//
//  DetailViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

@MainActor
final class DetailViewModel: ObservableObject {

    let item: AnimationItem
    @Published private(set) var isFavorited: Bool
    @Published private(set) var isOwned: Bool

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
    }

    func toggleFavorite() {
        favorites.toggle(item.id)
    }
}
