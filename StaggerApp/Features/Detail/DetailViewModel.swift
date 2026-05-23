//
//  DetailViewModel.swift
//  StaggerApp
//

import Foundation
import Combine

@MainActor
final class DetailViewModel: ObservableObject {

    let item: AnimationItem
    @Published private(set) var isFavorited: Bool
    @Published private(set) var isOwned: Bool

    // Live parameter sliders — visual-only, the preview is not parameterized
    // in this scope. Real Lab mode would wire these into the preview.
    @Published var paramResponse: Double = 0.45
    @Published var paramDamping: Double = 0.65
    @Published var paramScale: Double = 1.0

    private let favorites: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol
    ) {
        guard let found = repository.find(id: animationId) else {
            // Fallback: a dummy item — should never happen for valid IDs.
            self.item = repository.featured()
            self.favorites = favorites
            self.purchases = purchases
            self.isFavorited = favorites.isFavorite(repository.featured().id)
            self.isOwned = purchases.isOwned(repository.featured().id, freeOverride: repository.featured().isFree)
            return
        }
        self.item = found
        self.favorites = favorites
        self.purchases = purchases
        self.isFavorited = favorites.isFavorite(found.id)
        self.isOwned = purchases.isOwned(found.id, freeOverride: found.isFree)
        bind()
    }

    private func bind() {
        let id = item.id
        let isFree = item.isFree
        favorites.idsPublisher
            .map { $0.contains(id) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFavorited)

        Publishers.CombineLatest(purchases.ownedIdsPublisher, purchases.isProPublisher)
            .map { owned, isPro in isFree || isPro || owned.contains(id) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOwned)
    }

    func toggleFavorite() {
        favorites.toggle(item.id)
    }

    func purchase() {
        // For this scope, treat "purchase" as instantly owned.
        purchases.purchase(id: item.id)
    }

    func resetParams() {
        paramResponse = 0.45
        paramDamping = 0.65
        paramScale = 1.0
    }
}
