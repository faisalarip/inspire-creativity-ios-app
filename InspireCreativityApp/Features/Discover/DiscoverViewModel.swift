//
//  DiscoverViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published private(set) var featured: AnimationItem
    @Published private(set) var trending: [AnimationItem]
    @Published private(set) var newlyAdded: [AnimationItem]
    @Published private(set) var categories: [(category: Category, count: Int)]
    @Published private(set) var totalCount: Int
    /// StoreKit-derived Pro entitlement. Gates the Aurora Pack promo card so the
    /// Pro upsell disappears once the user owns Pro (mirrors Library/Detail).
    @Published private(set) var isPro: Bool

    private let repository: AnimationRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol,
         purchases: PurchaseRepositoryProtocol) {
        self.repository = repository
        self.purchases = purchases
        self.featured = repository.featured()
        self.trending = repository.trending()
        self.newlyAdded = repository.newlyAdded()
        self.categories = repository.categories()
        self.totalCount = repository.all().count
        self.isPro = purchases.isPro

        purchases.isProPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPro)

        NotificationCenter.default.publisher(for: .animationsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.featured = self.repository.featured()
                self.trending = self.repository.trending()
                self.newlyAdded = self.repository.newlyAdded()
                self.categories = self.repository.categories()
                self.totalCount = self.repository.all().count
            }
            .store(in: &cancellables)
    }

    /// Pull-to-refresh: re-fetches the remote catalog. On success the
    /// repository posts `.animationsUpdated`, which refreshes the rows above.
    func reload() async {
        await repository.refresh()
    }
}
