//
//  PurchaseRepository.swift
//  InspireCreativityApp
//
//  Tracks ownership state. For now, "owned" = (free OR pro-subscribed OR
//  individually purchased). A real implementation would talk to StoreKit.
//

import Foundation
import Combine

protocol PurchaseRepositoryProtocol: AnyObject {
    var ownedIdsPublisher: AnyPublisher<Set<String>, Never> { get }
    var isProPublisher: AnyPublisher<Bool, Never> { get }
    var isPro: Bool { get }
    func isOwned(_ id: String, freeOverride: Bool) -> Bool
    func purchase(id: String)
    func subscribePro()
}

final class PurchaseRepository: PurchaseRepositoryProtocol {
    private let defaults: UserDefaults
    private let purchasedKey = "stagger.purchased.ids"
    private let proKey = "stagger.isPro"

    private let ownedSubject: CurrentValueSubject<Set<String>, Never>
    private let proSubject: CurrentValueSubject<Bool, Never>

    var ownedIdsPublisher: AnyPublisher<Set<String>, Never> { ownedSubject.eraseToAnyPublisher() }
    var isProPublisher: AnyPublisher<Bool, Never> { proSubject.eraseToAnyPublisher() }
    var isPro: Bool { proSubject.value }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let owned = Set(defaults.stringArray(forKey: purchasedKey) ?? [])
        let pro = defaults.bool(forKey: proKey)
        self.ownedSubject = CurrentValueSubject(owned)
        self.proSubject = CurrentValueSubject(pro)
    }

    func isOwned(_ id: String, freeOverride: Bool) -> Bool {
        freeOverride || proSubject.value || ownedSubject.value.contains(id)
    }

    func purchase(id: String) {
        var current = ownedSubject.value
        current.insert(id)
        ownedSubject.send(current)
        defaults.set(Array(current), forKey: purchasedKey)
    }

    func subscribePro() {
        proSubject.send(true)
        defaults.set(true, forKey: proKey)
    }
}
