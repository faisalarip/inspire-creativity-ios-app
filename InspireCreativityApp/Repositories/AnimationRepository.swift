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
        ["liquid-heart", "hologram-card", "elastic-tabs", "morphing-fab", "aurora-mesh"]
            .compactMap(find(id:))
    }

    func newlyAdded() -> [AnimationItem] {
        ["parallax-card", "glitch-text", "spring-chain", "liquid-tabs"]
            .compactMap(find(id:))
    }
}
