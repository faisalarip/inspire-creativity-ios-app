//
//  JourneyMetrics.swift
//  InspireCreativityApp
//
//  Device-local, non-PII journey counters that feed GA4 user properties and
//  the purchase-attribution snapshot. Recording is local state (not analytics
//  "collection"), so it always runs; transmission is gated at the Firebase
//  layer. Cross-platform — no #if os(...).
//

import Foundation
import Combine

final class JourneyMetrics {
    private let defaults: UserDefaults
    private let now: () -> Date

    /// Emitted AFTER any counter mutation so observers read fresh values.
    let didChange = PassthroughSubject<Void, Never>()

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        if defaults.object(forKey: Keys.firstOpen) == nil {
            defaults.set(now(), forKey: Keys.firstOpen)
        }
    }

    private enum Keys {
        static let firstOpen = "journey.firstOpenDate"
        static let animationsViewed = "journey.animationsViewedCount"
        static let searches = "journey.searchesCount"
        static let favorites = "journey.favoritesCount"
        static let codeUnlockAttempts = "journey.codeUnlockAttempts"
        static let proLocksHit = "journey.proLocksHit"
    }

    // MARK: Recording
    func recordAnimationView() { increment(Keys.animationsViewed) }
    func recordSearch() { increment(Keys.searches) }
    func recordFavorite() { increment(Keys.favorites) }
    func recordCodeUnlockAttempt(result: CodeAccess) {
        increment(Keys.codeUnlockAttempts)
        if result == .needsPro { increment(Keys.proLocksHit) }
    }

    private func increment(_ key: String) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        didChange.send()
    }

    // MARK: Derived
    var animationsViewedCount: Int { defaults.integer(forKey: Keys.animationsViewed) }
    var proLocksHit: Int { defaults.integer(forKey: Keys.proLocksHit) }
    var hitProLock: Bool { proLocksHit > 0 }
    private var firstOpenDate: Date { defaults.object(forKey: Keys.firstOpen) as? Date ?? now() }

    var animationsViewedBucket: String { Self.viewsBucket(animationsViewedCount) }
    var engagementLevel: String { Self.engagement(animationsViewedCount) }
    func timeToPurchaseBucket() -> String { Self.elapsedBucket(now().timeIntervalSince(firstOpenDate)) }

    func snapshotForPurchase(signedIn: Bool) -> PurchaseContext {
        PurchaseContext(hitProLock: hitProLock,
                        animationsViewedBucket: animationsViewedBucket,
                        timeToPurchaseBucket: timeToPurchaseBucket(),
                        signedIn: signedIn)
    }

    // MARK: Pure bucketing
    static func viewsBucket(_ n: Int) -> String {
        switch n {
        case ..<1: return "0"
        case 1...3: return "1_3"
        case 4...10: return "4_10"
        case 11...30: return "11_30"
        default: return "31_plus"
        }
    }
    static func engagement(_ n: Int) -> String {
        switch n {
        case ..<1: return "new"
        case 1...3: return "browser"
        case 4...15: return "engaged"
        default: return "power"
        }
    }
    static func elapsedBucket(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<3_600: return "lt_1h"
        case ..<86_400: return "1_24h"
        case ..<604_800: return "1_7d"
        case ..<2_592_000: return "7_30d"
        default: return "gt_30d"
        }
    }
    static func secondsBucket(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<5: return "lt_5s"
        case ..<15: return "5_15s"
        case ..<60: return "15_60s"
        default: return "gt_60s"
        }
    }
}
