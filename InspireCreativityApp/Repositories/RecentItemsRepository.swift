//
//  RecentItemsRepository.swift
//  InspireCreativityApp
//
//  Recently-viewed animations, most recent first — powers Library's
//  "Pick up where you left off" row.
//

import Combine
import Foundation

protocol RecentItemsRepositoryProtocol: AnyObject {
    var idsPublisher: AnyPublisher<[String], Never> { get }
    func all() -> [String]
    func record(_ id: String)
}

final class RecentItemsRepository: RecentItemsRepositoryProtocol {
    private let defaults: UserDefaults
    private let key = "engagement.recents.ids"
    private let cap = 10
    private let subject: CurrentValueSubject<[String], Never>

    var idsPublisher: AnyPublisher<[String], Never> {
        subject.eraseToAnyPublisher()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.subject = CurrentValueSubject(defaults.stringArray(forKey: key) ?? [])
    }

    func all() -> [String] {
        subject.value
    }

    func record(_ id: String) {
        var current = subject.value
        current.removeAll { $0 == id }
        current.insert(id, at: 0)
        current = Array(current.prefix(cap))
        subject.send(current)
        defaults.set(current, forKey: key)
    }
}
