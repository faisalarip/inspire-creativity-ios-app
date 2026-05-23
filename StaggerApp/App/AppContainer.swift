//
//  AppContainer.swift
//  StaggerApp
//
//  Lightweight dependency container + view-model factories. Composition
//  root — all concrete deps are instantiated once here and exposed as
//  protocols downstream.
//

import Foundation

/// Composition root. One instance per app launch, kept alive by the App.
@MainActor
final class AppContainer: ObservableObject {

    let animationRepository: AnimationRepositoryProtocol
    let favoritesRepository: FavoritesRepositoryProtocol
    let purchaseRepository: PurchaseRepositoryProtocol

    init(
        animationRepository: AnimationRepositoryProtocol = InMemoryAnimationRepository(),
        favoritesRepository: FavoritesRepositoryProtocol = FavoritesRepository(),
        purchaseRepository: PurchaseRepositoryProtocol = PurchaseRepository()
    ) {
        self.animationRepository = animationRepository
        self.favoritesRepository = favoritesRepository
        self.purchaseRepository = purchaseRepository
    }

    // MARK: - View-model factories

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: animationRepository)
    }

    func makeBrowseViewModel() -> BrowseViewModel {
        BrowseViewModel(repository: animationRepository)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(repository: animationRepository)
    }

    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(
            repository: animationRepository,
            favoritesRepo: favoritesRepository,
            purchases: purchaseRepository
        )
    }

    func makeDetailViewModel(animationId: String) -> DetailViewModel {
        DetailViewModel(
            animationId: animationId,
            repository: animationRepository,
            favorites: favoritesRepository,
            purchases: purchaseRepository
        )
    }

    func makePaywallViewModel() -> PaywallViewModel {
        PaywallViewModel(purchases: purchaseRepository)
    }
}
