//
//  DiscoverViewModel.swift
//  StaggerApp
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

    private let repository: AnimationRepositoryProtocol

    init(repository: AnimationRepositoryProtocol) {
        self.repository = repository
        self.featured = repository.featured()
        self.trending = repository.trending()
        self.newlyAdded = repository.newlyAdded()
        self.categories = repository.categories()
        self.totalCount = repository.all().count
    }
}
