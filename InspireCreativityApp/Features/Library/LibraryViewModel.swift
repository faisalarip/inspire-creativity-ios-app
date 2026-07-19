//
//  LibraryViewModel.swift
//  InspireCreativityApp
//
//  v2.0 Library: streak + weekly-activity stats, a real continue row
//  (recently viewed), user collections, owned/favorites tabs and a
//  combined .swift export.
//

import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {

    enum Tab: String, CaseIterable {
        case owned, favorites
        var title: String {
            switch self {
            case .owned: "Owned"
            case .favorites: "Favorites"
            }
        }
    }

    @Published var tab: Tab = .owned
    @Published private(set) var owned: [AnimationItem] = []
    @Published private(set) var favorites: [AnimationItem] = []
    @Published private(set) var recentItems: [AnimationItem] = []
    @Published private(set) var collections: [AnimationCollection] = []
    @Published private(set) var streak = 0
    @Published private(set) var weekBars: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var copiesThisWeek = 0
    @Published private(set) var isPro: Bool = false

    private let repository: AnimationRepositoryProtocol
    private let favoritesRepo: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private let recents: RecentItemsRepositoryProtocol
    private let collectionsRepo: CollectionsRepositoryProtocol
    private let streakTracker: StreakTracker
    private let copyActivity: CopyActivityStore
    private let now: () -> Date
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: AnimationRepositoryProtocol,
        favoritesRepo: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        recents: RecentItemsRepositoryProtocol,
        collectionsRepo: CollectionsRepositoryProtocol,
        streakTracker: StreakTracker,
        copyActivity: CopyActivityStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.favoritesRepo = favoritesRepo
        self.purchases = purchases
        self.recents = recents
        self.collectionsRepo = collectionsRepo
        self.streakTracker = streakTracker
        self.copyActivity = copyActivity
        self.now = now
        bind()
        refreshStats()
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
        }
        .store(in: &cancellables)

        recents.idsPublisher
            .sink { [weak self] ids in
                guard let self else { return }
                self.recentItems = ids.compactMap { self.repository.find(id: $0) }
            }
            .store(in: &cancellables)

        collectionsRepo.collectionsPublisher
            .assign(to: &$collections)

        copyActivity.didChange
            .sink { [weak self] in self?.refreshStats() }
            .store(in: &cancellables)

        streakTracker.didChange
            .sink { [weak self] in self?.refreshStats() }
            .store(in: &cancellables)
    }

    /// Recomputed on copy/streak changes and from the view's onAppear so the
    /// bars roll over correctly at week boundaries.
    func refreshStats() {
        let date = now()
        weekBars = copyActivity.weekBars(for: date)
        copiesThisWeek = copyActivity.copiesThisWeek(for: date)
        streak = streakTracker.current
    }

    var visibleItems: [AnimationItem] {
        switch tab {
        case .owned: owned
        case .favorites: favorites
        }
    }

    func items(for collection: AnimationCollection) -> [AnimationItem] {
        collection.animationIds.compactMap { repository.find(id: $0) }
    }

    @discardableResult
    func createCollection(named name: String) -> AnimationCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return collectionsRepo.create(name: trimmed)
    }

    /// One combined `.swift` file of the visible tab's unlocked items,
    /// capped at 20 so the share payload stays reasonable.
    var exportSnippet: SwiftSnippet {
        let exportable = visibleItems
            .filter { $0.isFree || isPro }
            .prefix(20)
        let sections = exportable.map { item in
            "// MARK: - \(item.name) (\(item.id))\n\n\(AnimationCodeResolver.code(for: item))"
        }
        let header = """
        //
        //  InspireCreativityLibrary.swift
        //  Exported from Inspire Creativity — \(exportable.count) animation\(exportable.count == 1 ? "" : "s")
        //  \(AppLinks.appStoreURL.absoluteString)
        //
        """
        return SwiftSnippet(
            filename: "InspireCreativityLibrary.swift",
            source: ([header] + sections).joined(separator: "\n\n")
        )
    }
}
