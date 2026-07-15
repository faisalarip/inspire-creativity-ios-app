//
//  RecentSearchesStore.swift
//  InspireCreativityApp
//
//  Persisted recent search queries for Search v2's "Recent" chips.
//

import Combine
import Foundation

final class RecentSearchesStore {
    private let defaults: UserDefaults
    private let key = "engagement.search.recents"
    private let cap = 8
    private let subject: CurrentValueSubject<[String], Never>

    var queriesPublisher: AnyPublisher<[String], Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.subject = CurrentValueSubject(defaults.stringArray(forKey: key) ?? [])
    }

    func all() -> [String] {
        subject.value
    }

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = subject.value
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        current = Array(current.prefix(cap))
        subject.send(current)
        defaults.set(current, forKey: key)
    }

    func clear() {
        subject.send([])
        defaults.set([String](), forKey: key)
    }
}
