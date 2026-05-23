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
    private var cancellables: Set<AnyCancellable> = []

    init(repository: AnimationRepositoryProtocol) {
        self.repository = repository
        self.featured = repository.featured()
        self.trending = repository.trending()
        self.newlyAdded = repository.newlyAdded()
        self.categories = repository.categories()
        self.totalCount = repository.all().count

        NotificationCenter.default.publisher(for: .animationsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.featured = self.repository.featured()
                self.trending = self.repository.trending()
                self.newlyAdded = self.repository.newlyAdded()
                self.categories = self.repository.categories()
                self.totalCount = self.repository.all().count
            }
            .store(in: &cancellables)
    }
}
