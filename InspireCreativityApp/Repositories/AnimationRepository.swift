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
    /// Lead with the (free) aurora backgrounds — they're the visual hook —
    /// then a couple of popular hand-crafted pieces.
    static let trendingIDs = ["au-nebula", "au-solar", "au-bokeh",
                              "liquid-heart", "hologram-card"]
    static let newlyAddedIDs = ["parallax-card", "glitch-text",
                                "spring-chain", "liquid-tabs"]
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
        seed.first(where: { $0.isFeatured }) ?? seed[0]
    }

    func trending() -> [AnimationItem] {
        CuratedRows.trendingIDs.compactMap(find(id:))
    }

    func newlyAdded() -> [AnimationItem] {
        CuratedRows.newlyAddedIDs.compactMap(find(id:))
    }
}
