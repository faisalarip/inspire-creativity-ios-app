//
//  BrowseViewModel.swift
//  StaggerApp
//

import Foundation
import Combine

@MainActor
final class BrowseViewModel: ObservableObject {

    enum SortOrder: String, CaseIterable {
        case popular = "Most popular"
        case rating = "Highest rated"
    }

    @Published var selectedCategory: Category? = nil
    @Published var sortOrder: SortOrder = .popular

    @Published private(set) var visibleItems: [AnimationItem] = []
    @Published private(set) var categories: [(category: Category, count: Int)] = []
    @Published private(set) var totalCount: Int = 0

    private let repository: AnimationRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol) {
        self.repository = repository
        self.categories = repository.categories()
        self.totalCount = repository.all().count
        bind()
    }

    private func bind() {
        Publishers.CombineLatest($selectedCategory, $sortOrder)
            .sink { [weak self] cat, sort in
                self?.refresh(category: cat, sort: sort)
            }
            .store(in: &cancellables)
    }

    private func refresh(category: Category?, sort: SortOrder) {
        let items = repository.items(in: category)
        switch sort {
        case .popular:
            visibleItems = items.sorted { $0.downloads > $1.downloads }
        case .rating:
            visibleItems = items.sorted { $0.rating > $1.rating }
        }
    }

    func toggleSort() {
        sortOrder = sortOrder == .popular ? .rating : .popular
    }
}
