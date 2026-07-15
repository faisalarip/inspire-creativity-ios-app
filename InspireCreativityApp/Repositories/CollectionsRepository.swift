//
//  CollectionsRepository.swift
//  InspireCreativityApp
//
//  User-curated animation collections shown on Library v2. Persisted as a
//  JSON blob in UserDefaults (same pattern as AuthStore's session).
//

import Combine
import Foundation

struct AnimationCollection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var animationIds: [String]
}

protocol CollectionsRepositoryProtocol: AnyObject {
    var collectionsPublisher: AnyPublisher<[AnimationCollection], Never> { get }
    func all() -> [AnimationCollection]
    @discardableResult func create(name: String) -> AnimationCollection
    func delete(_ id: UUID)
    func add(_ animationId: String, to collectionId: UUID)
    func remove(_ animationId: String, from collectionId: UUID)
}

final class CollectionsRepository: CollectionsRepositoryProtocol {
    private let defaults: UserDefaults
    private let key = "engagement.collections"
    private let subject: CurrentValueSubject<[AnimationCollection], Never>

    var collectionsPublisher: AnyPublisher<[AnimationCollection], Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([AnimationCollection].self, from: data) {
            self.subject = CurrentValueSubject(saved)
        } else {
            // First run: seed two starter collections so the shelf isn't empty.
            let seed = [
                AnimationCollection(
                    id: UUID(), name: "Onboarding ideas",
                    animationIds: ["aurora-mesh", "onboarding", "confetti", "spring-button"]
                ),
                AnimationCollection(
                    id: UUID(), name: "Client app · Nova",
                    animationIds: ["liquid-tabs", "shimmer", "progress-arc", "toast"]
                ),
            ]
            self.subject = CurrentValueSubject(seed)
            persist(seed)
        }
    }

    func all() -> [AnimationCollection] {
        subject.value
    }

    @discardableResult
    func create(name: String) -> AnimationCollection {
        let collection = AnimationCollection(id: UUID(), name: name, animationIds: [])
        update(subject.value + [collection])
        return collection
    }

    func delete(_ id: UUID) {
        update(subject.value.filter { $0.id != id })
    }

    func add(_ animationId: String, to collectionId: UUID) {
        mutate(collectionId) { collection in
            guard !collection.animationIds.contains(animationId) else { return }
            collection.animationIds.append(animationId)
        }
    }

    func remove(_ animationId: String, from collectionId: UUID) {
        mutate(collectionId) { collection in
            collection.animationIds.removeAll { $0 == animationId }
        }
    }

    private func mutate(_ id: UUID, _ transform: (inout AnimationCollection) -> Void) {
        var collections = subject.value
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        transform(&collections[index])
        update(collections)
    }

    private func update(_ collections: [AnimationCollection]) {
        subject.send(collections)
        persist(collections)
    }

    private func persist(_ collections: [AnimationCollection]) {
        defaults.set(try? JSONEncoder().encode(collections), forKey: key)
    }
}
