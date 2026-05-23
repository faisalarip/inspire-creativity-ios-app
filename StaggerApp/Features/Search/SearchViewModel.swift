//
//  SearchViewModel.swift
//  StaggerApp
//
//  Debounced search with idle/loading/empty/loaded states. ViewState is
//  generic so the view can render uniformly across data shapes.
//

import Foundation
import Combine

enum SearchState: Equatable {
    case idle
    case empty(query: String)
    case results([AnimationItem])
}

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published private(set) var state: SearchState = .idle

    let recentQueries: [String] = ["heart burst", "loading", "tab bar", "shimmer"]
    let trendingTags: [String] = ["spring", "loaders", "matchedGeometry", "iOS 18", "free", "haptic"]

    private let repository: AnimationRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol) {
        self.repository = repository
        bind()
    }

    private func bind() {
        $query
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.runSearch(query: query)
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

    func use(query: String) {
        self.query = query
    }

    func clear() {
        query = ""
    }
}
