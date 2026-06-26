//
//  BrowseViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

@MainActor
final class BrowseViewModel: ObservableObject {

    enum SortOrder: String, CaseIterable {
        case featured = "Featured"
        case nameAsc = "A–Z"
    }

    @Published var selectedCategory: Category? = nil
    @Published var sortOrder: SortOrder = .featured
    @Published var searchText: String = ""

    @Published private(set) var visibleItems: [AnimationItem] = []
    @Published private(set) var categories: [(category: Category, count: Int)] = []
    @Published private(set) var totalCount: Int = 0
    /// Number of items matching the current filter/search, regardless of how
    /// many are currently paged in (drives the "N results" label).
    @Published private(set) var resultCount: Int = 0

    /// How many cards to reveal per page. The grid renders a *live* animated
    /// preview per card, so showing the whole ~300-item catalog at once spins
    /// up hundreds of simultaneous animations and stalls the first frames.
    /// Paging caps the live previews to roughly what's on screen.
    private let pageSize = 30
    /// Full filtered + sorted result; `visibleItems` is a prefix of this.
    private var filtered: [AnimationItem] = []
    private var page = 1

    /// True while more matching items remain to be paged in.
    var canLoadMore: Bool { visibleItems.count < filtered.count }

    private let repository: AnimationRepositoryProtocol
    private let analytics: AnalyticsTracking
    private var cancellables: Set<AnyCancellable> = []
    /// Last-logged values so we fire `category_selected` / `search` only when
    /// the dimension actually changes (the sink fires on every debounced edit).
    /// Seeded to the initial category (`nil`/"all") so CombineLatest3's synthetic
    /// emission on subscription is treated as already-seen and does NOT log.
    private var lastLoggedCategory: Category?? = .some(nil)
    private var lastLoggedQueryLen: Int = -1

    init(repository: AnimationRepositoryProtocol,
         analytics: AnalyticsTracking = NoOpAnalyticsTracker()) {
        self.repository = repository
        self.analytics = analytics
        self.categories = repository.categories()
        self.totalCount = repository.all().count
        bind()
    }

    private func bind() {
        Publishers.CombineLatest3($selectedCategory, $sortOrder, $searchText)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] cat, sort, query in
                guard let self else { return }
                self.refresh(category: cat, sort: sort, query: query)
                if self.lastLoggedCategory != .some(cat) {
                    self.lastLoggedCategory = .some(cat)
                    self.analytics.log(.categorySelected(cat?.rawValue ?? "all"))
                }
                let len = query.trimmingCharacters(in: .whitespacesAndNewlines).count
                if len > 0 && len != self.lastLoggedQueryLen {
                    self.lastLoggedQueryLen = len
                    self.analytics.log(.search(termLength: len))
                }
            }
            .store(in: &cancellables)

        // Re-read the catalog (and re-emit derived state) when the remote
        // Supabase fetch lands.
        NotificationCenter.default.publisher(for: .animationsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.categories = self.repository.categories()
                self.totalCount = self.repository.all().count
                self.refresh(category: self.selectedCategory,
                             sort: self.sortOrder,
                             query: self.searchText)
            }
            .store(in: &cancellables)
    }

    private func refresh(category: Category?, sort: SortOrder, query: String) {
        var items = repository.items(in: category)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter {
                $0.name.lowercased().contains(q) ||
                $0.category.rawValue.lowercased().contains(q) ||
                $0.author.lowercased().contains(q)
            }
        }
        switch sort {
        case .featured:
            // Curated order: featured first, then the repository's default
            // ranking. (The ranking signal is internal and never shown as a
            // user-facing metric.)
            filtered = items.sorted {
                ($0.isFeatured ? 1 : 0, $0.downloads) > ($1.isFeatured ? 1 : 0, $1.downloads)
            }
        case .nameAsc:
            filtered = items.sorted { $0.name < $1.name }
        }
        // Any change to category/sort/search is a fresh result set — reset to
        // the first page so the grid scrolls from the top with a capped count.
        page = 1
        resultCount = filtered.count
        applyPage()
    }

    /// Reveals the next page of results. No-op once everything is shown.
    func loadMore() {
        guard canLoadMore else { return }
        page += 1
        applyPage()
    }

    private func applyPage() {
        visibleItems = Array(filtered.prefix(page * pageSize))
    }

    func toggleSort() {
        sortOrder = sortOrder == .featured ? .nameAsc : .featured
    }

    /// Pull-to-refresh: re-fetches the remote catalog. On success the
    /// repository posts `.animationsUpdated`, which re-derives the grid.
    func reload() async {
        await repository.refresh()
    }
}
