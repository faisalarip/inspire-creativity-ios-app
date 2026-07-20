import XCTest
@testable import InspireCreativityApp

final class AnalyticsEventTests: XCTestCase {

    private let reservedPrefixes = ["ga_", "firebase_", "google_"]

    func testEventNamesAreGA4Valid() {
        let events: [AnalyticsEvent] = [
            .animationView(id: "ges-x", category: "Gestures", isPro: true),
            .codeCopied(id: "ges-x"),
            .favoriteToggled(id: "ges-x", on: true),
            .search(termLength: 4),
            .categorySelected("Gestures"),
            .paywallViewed(source: "detail", animationId: "aurora-mesh"),
            .purchaseCompleted(productID: "pro.lifetime", source: "detail",
                               context: PurchaseContext(hitProLock: true, animationsViewedBucket: "4_10",
                                                        timeToPurchaseBucket: "1_24h", signedIn: false)),
            .signIn(method: "apple"),
            .restoreFailed(source: "detail", reason: "no_purchases"),
            .pricingUnavailable(source: "library"),
            .meterCopyUsed(animationId: "aurora-mesh", remaining: 2),
            .meterExhausted(animationId: "aurora-mesh"),
            .onboardingCompleted(categoriesCount: 3),
            .campaignDetails(source: "medium", medium: "referral", campaign: "launch"),
            .auroraPromoTap
        ]
        for event in events {
            let name = event.name
            XCTAssertLessThanOrEqual(name.count, 40, "\(name) exceeds GA4's 40-char limit")
            XCTAssertEqual(name, name.lowercased(), "\(name) must be snake_case")
            XCTAssertTrue(name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" },
                          "\(name) has invalid characters")
            XCTAssertFalse(reservedPrefixes.contains { name.hasPrefix($0) },
                           "\(name) uses a reserved GA4 prefix")
        }
    }

    func testSearchCarriesLengthNotRawQuery() {
        let params = AnalyticsEvent.search(termLength: 7).parameters
        XCTAssertEqual(params["term_length"] as? Int, 7)
        XCTAssertNil(params["query"], "raw query must never be logged (PII)")
        XCTAssertNil(params["term"], "raw term must never be logged (PII)")
    }

    func testParameterValuesAreWithinGA4Limits() {
        let params = AnalyticsEvent.animationView(id: "ges-x", category: "Gestures", isPro: false).parameters
        XCTAssertEqual(params["animation_id"] as? String, "ges-x")
        XCTAssertEqual(params["category"] as? String, "Gestures")
        XCTAssertEqual(params["is_pro"] as? Bool, false)
        for (key, value) in params {
            XCTAssertLessThanOrEqual(key.count, 40, "param key \(key) too long")
            if let s = value as? String { XCTAssertLessThanOrEqual(s.count, 100, "param \(key) value too long") }
        }
    }

    func testPurchaseCompletedCarriesProductAndSource() {
        let event = AnalyticsEvent.purchaseCompleted(
            productID: "com.faisalarip.InspireCreativityApp.pro.lifetime",
            source: "settings",
            context: PurchaseContext(hitProLock: true, animationsViewedBucket: "4_10",
                                     timeToPurchaseBucket: "1_24h", signedIn: false)
        )
        XCTAssertEqual(event.name, "purchase_completed")
        let params = event.parameters
        XCTAssertEqual(params["product_id"] as? String, "com.faisalarip.InspireCreativityApp.pro.lifetime")
        XCTAssertEqual(params["source"] as? String, "settings")
        XCTAssertEqual(params["hit_pro_lock"] as? Bool, true)
        XCTAssertEqual(params["animations_viewed_bucket"] as? String, "4_10")
        XCTAssertEqual(params["time_to_purchase_bucket"] as? String, "1_24h")
        XCTAssertEqual(params["signed_in"] as? Bool, false)
    }

    func testEventEquatable() {
        XCTAssertEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                       AnalyticsEvent.favoriteToggled(id: "a", on: true))
        XCTAssertNotEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                          AnalyticsEvent.favoriteToggled(id: "a", on: false))
    }

    func testNewFunnelEventsAreGA4Valid() {
        let events: [AnalyticsEvent] = [
            .codeUnlockAttempt(result: "needs_pro", animationID: "ges-x", category: "Gestures", isPro: true),
            .purchaseInitiated(productID: "pro.lifetime", source: "detail"),
            .purchaseCancelled(productID: "pro.lifetime", source: "detail", reason: "user_cancelled"),
            .purchaseFailed(productID: "pro.lifetime", source: "detail", reason: "verification_failed"),
            .paywallDismissed(source: "detail", secondsBucket: "5_15s"),
            .restoreCompleted(source: "settings")
        ]
        for event in events {
            let name = event.name
            XCTAssertLessThanOrEqual(name.count, 40, "\(name) too long")
            XCTAssertEqual(name, name.lowercased(), "\(name) must be snake_case")
            XCTAssertTrue(name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" }, "\(name) invalid chars")
            XCTAssertFalse(["ga_", "firebase_", "google_"].contains { name.hasPrefix($0) }, "\(name) reserved prefix")
            for (key, value) in event.parameters {
                XCTAssertLessThanOrEqual(key.count, 40, "param \(key) too long")
                if let s = value as? String { XCTAssertLessThanOrEqual(s.count, 100, "param \(key) value too long") }
            }
        }
    }

    func testCodeUnlockAttemptParameters() {
        let p = AnalyticsEvent.codeUnlockAttempt(result: "needs_pro", animationID: "ges-x", category: "Gestures", isPro: true).parameters
        XCTAssertEqual(p["result"] as? String, "needs_pro")
        XCTAssertEqual(p["animation_id"] as? String, "ges-x")
        XCTAssertEqual(p["category"] as? String, "Gestures")
        XCTAssertEqual(p["is_pro"] as? Bool, true)
    }

    func testPurchaseFunnelEventNames() {
        XCTAssertEqual(AnalyticsEvent.purchaseInitiated(productID: "p", source: "s").name, "purchase_initiated")
        XCTAssertEqual(AnalyticsEvent.purchaseCancelled(productID: "p", source: "s", reason: "pending").name, "purchase_cancelled")
        XCTAssertEqual(AnalyticsEvent.purchaseFailed(productID: "p", source: "s", reason: "error").name, "purchase_failed")
        XCTAssertEqual(AnalyticsEvent.paywallDismissed(source: "s", secondsBucket: "lt_5s").name, "paywall_dismissed")
        XCTAssertEqual(AnalyticsEvent.restoreCompleted(source: "s").name, "restore_completed")
    }
}
