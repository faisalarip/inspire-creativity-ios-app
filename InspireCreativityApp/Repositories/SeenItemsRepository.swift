//
//  SeenItemsRepository.swift
//  InspireCreativityApp
//
//  Which animations has this user actually looked at? With a 300+ catalog
//  the "explored X of Y" progress and NEW badges turn sheer size into a
//  collection game instead of an invisible wall.
//

import Combine
import Foundation

protocol SeenItemsRepositoryProtocol: AnyObject {
    var idsPublisher: AnyPublisher<Set<String>, Never> { get }
    func isSeen(_ id: String) -> Bool
    func markSeen(_ id: String)
    func all() -> Set<String>
}

final class SeenItemsRepository: SeenItemsRepositoryProtocol {
    private let defaults: UserDefaults
    private let key = "engagement.seen.ids"
    private let subject: CurrentValueSubject<Set<String>, Never>

    var idsPublisher: AnyPublisher<Set<String>, Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.subject = CurrentValueSubject(Set(defaults.stringArray(forKey: key) ?? []))
    }

    func isSeen(_ id: String) -> Bool {
        subject.value.contains(id)
    }

    func markSeen(_ id: String) {
        guard !subject.value.contains(id) else { return }
        var ids = subject.value
        ids.insert(id)
        subject.send(ids)
        defaults.set(Array(ids), forKey: key)
    }

    func all() -> Set<String> {
        subject.value
    }
}
