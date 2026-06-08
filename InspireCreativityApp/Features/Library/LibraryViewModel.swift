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
            // plus the whole library once Pro. Aurora background assets lead the
            // list (they're the visual showcase), then by popularity.
            self.owned = self.repository.all()
                .filter { $0.isFree || isPro }
                .sorted { lhs, rhs in
                    let lhsBackground = lhs.category == .backgrounds ? 0 : 1
                    let rhsBackground = rhs.category == .backgrounds ? 0 : 1
                    if lhsBackground != rhsBackground { return lhsBackground < rhsBackground }
                    return lhs.downloads > rhs.downloads
                }
            // Recent — first 3 of owned (a lightweight stand-in for recency).
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
