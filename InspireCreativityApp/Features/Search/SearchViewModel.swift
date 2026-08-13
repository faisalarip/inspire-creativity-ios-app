//
//  SearchViewModel.swift
//  InspireCreativityApp
//
//  v2.0 discovery-first search (artboard 08): trending searches, suggestion
//  chips, persisted recents and a popular grid instead of an empty box.
//

import Combine
import Foundation

enum SearchState: Equatable {
    case idle
    case empty(query: String)
    case results([AnimationItem])
}

@MainActor
final class SearchViewModel: ObservableObject {

    enum Delta { case up, down, same }

    @Published var query: String = ""
    @Published private(set) var state: SearchState = .idle
    @Published private(set) var recents: [String] = []

    let suggestions = ["aurora", "glass", "spring", "mesh", "liquid", "cosmic", "free"]
    let trendingSearches: [(query: String, delta: Delta)] = [
        ("aurora mesh", .up),
        ("liquid chrome", .up),
        ("metal shaders", .same),
        ("confetti", .up),
        ("tab bar", .down),
    ]
    /// "Popular this week" grid — curated ids, resolved against the catalog.
    private(set) var popular: [AnimationItem] = []

    private let repository: AnimationRepositoryProtocol
    private let recentSearches: RecentSearchesStore
    private let analytics: AnalyticsTracking
    private let journeyMetrics: JourneyMetrics
    private let searchLogSettle: TimeInterval
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol,
         recentSearches: RecentSearchesStore = RecentSearchesStore(),
         analytics: AnalyticsTracking = NoOpAnalyticsTracker(),
         journeyMetrics: JourneyMetrics = JourneyMetrics(),
         searchLogSettle: TimeInterval = 1.0) {
        self.repository = repository
        self.recentSearches = recentSearches
        self.analytics = analytics
        self.journeyMetrics = journeyMetrics
        self.searchLogSettle = searchLogSettle
        self.popular = ["aurora-mesh", "liquid-chrome", "liquid-tabs", "hologram-card"]
            .compactMap { repository.find(id: $0) }
        bind()
    }

    private func bind() {
        recentSearches.queriesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$recents)

        $query
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.runSearch(query: query)
            }
            .store(in: &cancellables)

        // Analytics settle: one `search` event per query the user stopped
        // typing at. The 180ms UI debounce is shorter than a typing pause, so
        // logging there fired on nearly every keystroke (~17 events per
        // searching user in GA).
        $query
            .debounce(for: .seconds(searchLogSettle), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.logSettledSearch(query)
            }
            .store(in: &cancellables)
    }

    private func runSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            state = .idle
            return
        }
        let results = repository.search(trimmed)
        state = results.isEmpty ? .empty(query: trimmed) : .results(results)
    }

    private func logSettledSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        analytics.log(.search(termLength: trimmed.count))
        journeyMetrics.recordSearch()
    }

    /// Commits a query (suggestion / trending / recent tap, or return key):
    /// runs it AND records it into the persisted recents.
    func commit(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        recentSearches.record(trimmed)
        self.query = trimmed
    }

    func clearRecents() {
        recentSearches.clear()
    }

    func clear() {
        query = ""
        state = .idle
    }
}
