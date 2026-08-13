//
//  BrowseViewModel.swift
//  InspireCreativityApp
//
//  v2.0 category-first browse: an overview (category cards, aurora theme
//  moods, popular grid) that drills into a filtered, sortable, paged grid.
//

import Combine
import Foundation

@MainActor
final class BrowseViewModel: ObservableObject {

    enum Sort: String, CaseIterable {
        case popular = "Popular"
        case rating = "Top rated"
        case freeFirst = "Free first"
    }

    enum Scope: Hashable {
        case overview
        case category(Category)
        case theme(String)

        var title: String? {
            switch self {
            case .overview: return nil
            case .category(let category): return category.displayName
            case .theme(let theme): return theme
            }
        }
    }

    @Published var scope: Scope = .overview { didSet { scopeChanged(from: oldValue) } }
    @Published var sort: Sort = .popular { didSet { rebuildDrill() } }

    @Published private(set) var categories: [(category: Category, count: Int)] = []
    @Published private(set) var themes: [(name: String, count: Int)] = []
    @Published private(set) var popular: [AnimationItem] = []
    @Published private(set) var drillItems: [AnimationItem] = []
    @Published private(set) var drillTotal = 0
    @Published private(set) var totalCount = 0

    /// Cards revealed per "Show more" (each renders a live animated preview,
    /// so the page size caps simultaneous animations).
    private let pageSize = 12
    private var pageLimit = 12
    private var drillAll: [AnimationItem] = []

    var canLoadMore: Bool { drillItems.count < drillTotal }
    var remainingCount: Int { drillTotal - drillItems.count }

    private let repository: AnimationRepositoryProtocol
    private let analytics: AnalyticsTracking
    private let journeyMetrics: JourneyMetrics
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol,
         analytics: AnalyticsTracking = NoOpAnalyticsTracker(),
         journeyMetrics: JourneyMetrics = JourneyMetrics()) {
        self.repository = repository
        self.analytics = analytics
        self.journeyMetrics = journeyMetrics
        rebuildOverview()

        NotificationCenter.default.publisher(for: .animationsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildOverview()
                self?.rebuildDrill()
            }
            .store(in: &cancellables)
    }

    /// Representative preview for a category card's right edge.
    func representativeItem(for category: Category) -> AnimationItem? {
        repository.items(in: category).first
    }

    func loadMore() {
        guard canLoadMore else { return }
        pageLimit += pageSize
        rebuildDrill()
    }

    /// Pull-to-refresh: re-fetches the remote catalog. On success the
    /// repository posts `.animationsUpdated`, which re-derives everything.
    func reload() async {
        await repository.refresh()
    }

    // MARK: - Derivations

    private func rebuildOverview() {
        categories = repository.categories()
        totalCount = repository.all().count
        popular = Array(repository.all().sorted { $0.downloads > $1.downloads }.prefix(6))

        var themeCounts: [String: Int] = [:]
        for descriptor in AuroraDescriptors.all {
            themeCounts[descriptor.theme, default: 0] += 1
        }
        themes = themeCounts.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }
    }

    private func scopeChanged(from oldValue: Scope) {
        guard scope != oldValue else { return }
        pageLimit = pageSize
        rebuildDrill()
        switch scope {
        case .overview:
            break
        case .category(let category):
            analytics.log(.categorySelected(category.rawValue))
        case .theme(let theme):
            analytics.log(.categorySelected("theme:\(theme)"))
        }
    }

    private func rebuildDrill() {
        switch scope {
        case .overview:
            drillAll = []
        case .category(let category):
            drillAll = repository.items(in: category)
        case .theme(let theme):
            let ids = Set(AuroraDescriptors.all.filter { $0.theme == theme }.map(\.id))
            drillAll = repository.all().filter { ids.contains($0.id) }
        }
        switch sort {
        case .popular:
            drillAll.sort { $0.downloads > $1.downloads }
        case .rating:
            drillAll.sort { $0.rating > $1.rating }
        case .freeFirst:
            drillAll.sort {
                (($0.isFree ? 0 : 1), $1.downloads) < (($1.isFree ? 0 : 1), $0.downloads)
            }
        }
        drillTotal = drillAll.count
        drillItems = Array(drillAll.prefix(pageLimit))
    }
}
