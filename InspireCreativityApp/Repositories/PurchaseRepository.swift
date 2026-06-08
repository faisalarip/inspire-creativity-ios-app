//
//  PurchaseRepository.swift
//  InspireCreativityApp
//
//  Entitlement abstraction consumed by the view models. The concrete
//  implementation is `StoreManager`, which derives entitlement state purely
//  from verified StoreKit 2 transactions. There is intentionally no local
//  "grant ownership" method — Pro can only come from a real purchase.
//

import Foundation
import Combine

protocol PurchaseRepositoryProtocol: AnyObject {
    /// Emits whenever the user's Pro entitlement changes.
    var isProPublisher: AnyPublisher<Bool, Never> { get }
    /// True when the user holds an active subscription or the lifetime unlock.
    var isPro: Bool { get }
    /// Whether a given animation is accessible: free content, or anything once Pro.
    func isOwned(_ id: String, freeOverride: Bool) -> Bool
}
