//
//  AnimationRepository.swift
//  InspireCreativityApp
//
//  Repository protocol + in-memory seeded implementation.
//  Domain code only depends on the protocol; the concrete impl is injected
//  at app startup.
//

import Foundation

/// Read access to the animation catalog.
protocol AnimationRepositoryProtocol {
    /// All animations in the catalog, sorted by `downloads` desc.
    func all() -> [AnimationItem]
    /// Lookup by id. Returns nil if missing.
    func find(id: String) -> AnimationItem?
    /// Filter by category. Pass `nil` for all.
    func items(in category: Category?) -> [AnimationItem]
    /// Top categories with counts.
    func categories() -> [(category: Category, count: Int)]
    /// Search across name, category, and author.
    func search(_ query: String) -> [AnimationItem]
    /// Featured item used as the Discover hero.
    func featured() -> AnimationItem
    /// Trending list (curated subset).
    func trending() -> [AnimationItem]
    /// Recently added list (curated subset).
    func newlyAdded() -> [AnimationItem]
    /// Re-fetches the catalog from the backing store. Returns true when the
    /// cache changed (the repository then posts `.animationsUpdated`).
    @discardableResult
    func refresh() async -> Bool
}

extension AnimationRepositoryProtocol {
    /// Seeded in-memory catalogs have nothing to re-fetch.
    @discardableResult
    func refresh() async -> Bool { false }
}

/// Curated id lists shared by every repository implementation so the
/// Discover rows can't drift between the bundled and remote catalogs.
enum CuratedRows {
    /// Discover rows are shuffled so the screen feels fresh on each launch and
    /// pull-to-refresh. (Previously a fixed curated id list — see git history.)
    static let trendingCount = 8
    static let newlyAddedCount = 6

    static func trending(from items: [AnimationItem]) -> [AnimationItem] {
        Array(items.shuffled().prefix(trendingCount))
    }

    static func newlyAdded(from items: [AnimationItem]) -> [AnimationItem] {
        Array(items.shuffled().prefix(newlyAddedCount))
    }
}

/// In-memory animation catalog. Data is seeded once at construction.
final class InMemoryAnimationRepository: AnimationRepositoryProtocol {

    private let seed: [AnimationItem]

    init(seed: [AnimationItem] = AnimationCatalogSeed.items) {
        self.seed = seed
    }

    func all() -> [AnimationItem] {
        seed.sorted { $0.downloads > $1.downloads }
    }

    func find(id: String) -> AnimationItem? {
        seed.first(where: { $0.id == id })
    }

    func items(in category: Category?) -> [AnimationItem] {
        guard let category else { return all() }
        return seed.filter { $0.category == category }
    }

    func categories() -> [(category: Category, count: Int)] {
        Category.allCases.compactMap { cat in
            let count = seed.filter { $0.category == cat }.count
            return count > 0 ? (cat, count) : nil
        }
    }

    func search(_ query: String) -> [AnimationItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return seed.filter {
            $0.name.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            $0.author.lowercased().contains(q)
        }
    }

    func featured() -> AnimationItem {
        seed.randomElement() ?? seed[0]
    }

    func trending() -> [AnimationItem] {
        CuratedRows.trending(from: seed)
    }

    func newlyAdded() -> [AnimationItem] {
        CuratedRows.newlyAdded(from: seed)
    }

    /// A seeded catalog has nothing to re-fetch, but re-broadcast anyway so
    /// Discover re-rolls its shuffled rows on pull-to-refresh.
    @discardableResult
    func refresh() async -> Bool {
        NotificationCenter.default.post(name: .animationsUpdated, object: nil)
        return true
    }
}
