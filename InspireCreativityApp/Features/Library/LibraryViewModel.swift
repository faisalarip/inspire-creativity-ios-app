//
//  LibraryViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {

    enum Tab: String, CaseIterable {
        case owned, favorites, recent
        var title: String {
            switch self {
            case .owned: "Owned"
            case .favorites: "Favorites"
            case .recent: "Recent"
            }
        }
    }

    @Published var tab: Tab = .owned
    @Published private(set) var owned: [AnimationItem] = []
    @Published private(set) var favorites: [AnimationItem] = []
    @Published private(set) var recent: [AnimationItem] = []
    @Published private(set) var isPro: Bool = false

    private let repository: AnimationRepositoryProtocol
    private let favoritesRepo: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: AnimationRepositoryProtocol,
        favoritesRepo: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol
    ) {
        self.repository = repository
        self.favoritesRepo = favoritesRepo
        self.purchases = purchases
        bind()
    }

    private func bind() {
        Publishers.CombineLatest(
            favoritesRepo.idsPublisher,
            purchases.isProPublisher
        )
        .sink { [weak self] favs, isPro in
            guard let self else { return }
            self.isPro = isPro
            self.favorites = self.repository.all().filter { favs.contains($0.id) }
            // "Owned" = everything the user can actually open: free content,
            // plus the whole library once Pro.
            self.owned = self.repository.all().filter { item in
                item.isFree || isPro
            }
            // Recent — last 3 from owned.
            self.recent = Array(self.owned.prefix(3))
        }
        .store(in: &cancellables)
    }

    var visibleItems: [AnimationItem] {
        switch tab {
        case .owned: owned
        case .favorites: favorites
        case .recent: recent
        }
    }
}
