//
//  FavoritesRepository.swift
//  StaggerApp
//
//  Lightweight UserDefaults-backed favorites store. Suitable for non-secure,
//  small-volume data. For the production app, swap with SwiftData behind the
//  same protocol.
//

import Foundation
import Combine

protocol FavoritesRepositoryProtocol: AnyObject {
    var idsPublisher: AnyPublisher<Set<String>, Never> { get }
    func isFavorite(_ id: String) -> Bool
    func toggle(_ id: String)
    func all() -> Set<String>
}

final class FavoritesRepository: FavoritesRepositoryProtocol {
    private let defaults: UserDefaults
    private let key = "stagger.favorites.ids"
    private let subject: CurrentValueSubject<Set<String>, Never>

    var idsPublisher: AnyPublisher<Set<String>, Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = Set(defaults.stringArray(forKey: key) ?? [])
        self.subject = CurrentValueSubject(saved)
    }

    func isFavorite(_ id: String) -> Bool {
        subject.value.contains(id)
    }

    func toggle(_ id: String) {
        var current = subject.value
        if current.contains(id) { current.remove(id) }
        else { current.insert(id) }
        subject.send(current)
        defaults.set(Array(current), forKey: key)
    }

    func all() -> Set<String> {
        subject.value
    }
}
