# GA4 Purchase-Journey Attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instrument the in-app purchase journey in Firebase/GA4 so we can see which journey steps most drive in-app purchase.

**Architecture:** Extend the existing `AnalyticsTracking` seam (protocol + Firebase/Console/NoOp backends) with new funnel events, a typed `AnalyticsUserProperty`, and a device-local `JourneyMetrics` counter. Instrument the missing intent moments (Pro-lock hit, purchase initiated/cancelled/failed, paywall dismissed) at shared view models so iOS and macOS get identical coverage. No new backend, no `setUserID`, no marketing attribution.

**Tech Stack:** Swift 5 / SwiftUI, StoreKit 2, Firebase Analytics (GA4) via SPM, XCTest.

**Spec:** `docs/superpowers/specs/2026-07-02-ga4-purchase-journey-attribution-design.md`

## Global Constraints

- **GA4 event rules:** event/param names snake_case, ≤40 chars, no `ga_`/`firebase_`/`google_` prefix; string param values ≤100 chars. **Never log PII** (`animation_id`/`category` are content ids, allowed).
- **GA4 user-property rules:** name ≤24 chars, value ≤36 chars, no PII.
- **Consent:** never bypass it. All transmission is gated by `Analytics.setAnalyticsCollectionEnabled`; do not add any parallel collection path. `JourneyMetrics` stores only device-local aggregate counters.
- **Identity:** device-scoped only. **Do not** call `Analytics.setUserID` anywhere.
- **Platforms:** every change must compile and behave on iOS 17+ and macOS 14+ (single multiplatform target; use `#if os(macOS)` only where required).
- **Keep `AnalyticsEvent` and `PurchaseContext` `Equatable`** (the test spy compares events with `==`).
- **Test command (substitute any available simulator):**
  `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'<TestClass>' 2>&1 | tail -25`
  First run resolves SPM packages (slow, minutes). Available sims include iPhone 17 / iPhone 16e.
- **Commit trailers:** end every commit message with:
  `-m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"`

---

## File Structure

**Create:**
- `InspireCreativityApp/Analytics/AnalyticsUserProperty.swift` — typed GA4 user properties (Task 2)
- `InspireCreativityApp/Analytics/JourneyMetrics.swift` — device-local journey counters + pure bucketing (Task 3)
- `InspireCreativityAppTests/AnalyticsUserPropertyTests.swift` (Task 2)
- `InspireCreativityAppTests/JourneyMetricsTests.swift` (Task 3)

**Modify:**
- `InspireCreativityApp/Analytics/AnalyticsEvent.swift` — 6 new cases + `PurchaseContext` (Task 1); enrich `purchaseCompleted` (Task 6)
- `InspireCreativityApp/Analytics/AnalyticsTracking.swift` — add `set(_:)` (Task 2)
- `InspireCreativityApp/Analytics/FirebaseAnalyticsTracker.swift` / `ConsoleAnalyticsTracker.swift` / `NoOpAnalyticsTracker.swift` — implement `set(_:)` (Task 2)
- `InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift` — record user properties + `set(_:)` (Task 2)
- `InspireCreativityAppTests/AnalyticsEventTests.swift` — cover new events (Tasks 1, 6)
- `InspireCreativityAppTests/AnalyticsInstrumentationTests.swift` — cover new call sites (Tasks 4, 5, 6)
- `InspireCreativityApp/Features/Detail/DetailViewModel.swift` — journeyMetrics dep + `logCodeUnlockAttempt` + recording (Task 4)
- `InspireCreativityApp/Features/Detail/DetailView.swift` — call `logCodeUnlockAttempt` in `onUnlock` (Task 4)
- `InspireCreativityApp/Features/Browse/BrowseViewModel.swift` — `recordSearch()` (Task 5)
- `InspireCreativityApp/Features/Paywall/PaywallViewModel.swift` — purchase events + dwell + deps (Task 6)
- `InspireCreativityApp/Features/Paywall/PaywallView.swift` — appeared/dismissed hooks (Task 6)
- `InspireCreativityApp/Features/MacShellV2/MacDetailPane.swift` — Mac CTA hook + screen tracking (Task 7)
- `InspireCreativityApp/App/AppContainer.swift` — own JourneyMetrics, inject it, observe isPro/session, set properties (Task 8)
- `docs/analytics-setup.md` — GA4 console setup (Task 9)

**Dependency order:** 1 → 2 → 3 → (4, 5) → 6 → 7 → 8 → 9. Tasks 1–3 are additive and independent; 4–8 depend on the interfaces from 2 and 3; 6 depends on `PurchaseContext` (Task 1) and `JourneyMetrics` (Task 3).

---

### Task 1: New funnel events + PurchaseContext

**Files:**
- Modify: `InspireCreativityApp/Analytics/AnalyticsEvent.swift`
- Test: `InspireCreativityAppTests/AnalyticsEventTests.swift`

**Interfaces:**
- Produces: `AnalyticsEvent.codeUnlockAttempt(result:animationID:category:isPro:)`, `.purchaseInitiated(productID:source:)`, `.purchaseCancelled(productID:source:reason:)`, `.purchaseFailed(productID:source:reason:)`, `.paywallDismissed(source:secondsBucket:)`, `.restoreCompleted(source:)`; and `struct PurchaseContext: Equatable { let hitProLock: Bool; let animationsViewedBucket: String; let timeToPurchaseBucket: String; let signedIn: Bool }`.
- Note: `purchaseCompleted` is **unchanged** in this task (enriched in Task 6).

- [ ] **Step 1: Write the failing test** — append to `AnalyticsEventTests.swift` (inside the class):

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsEventTests' 2>&1 | tail -25`
Expected: FAIL — compile error, `codeUnlockAttempt` etc. are not members of `AnalyticsEvent`.

- [ ] **Step 3: Add the struct + cases** — in `AnalyticsEvent.swift`, add above the enum:

```swift
/// Journey context snapshotted at purchase time. Non-PII, all bucketed.
struct PurchaseContext: Equatable {
    let hitProLock: Bool
    let animationsViewedBucket: String
    let timeToPurchaseBucket: String
    let signedIn: Bool
}
```

Add these cases to `enum AnalyticsEvent` (after `case auroraPromoTap`):

```swift
    case codeUnlockAttempt(result: String, animationID: String, category: String, isPro: Bool)
    case purchaseInitiated(productID: String, source: String)
    case purchaseCancelled(productID: String, source: String, reason: String)
    case purchaseFailed(productID: String, source: String, reason: String)
    case paywallDismissed(source: String, secondsBucket: String)
    case restoreCompleted(source: String)
```

Add to the `name` switch:

```swift
        case .codeUnlockAttempt:  return "code_unlock_attempt"
        case .purchaseInitiated:  return "purchase_initiated"
        case .purchaseCancelled:  return "purchase_cancelled"
        case .purchaseFailed:     return "purchase_failed"
        case .paywallDismissed:   return "paywall_dismissed"
        case .restoreCompleted:   return "restore_completed"
```

Add to the `parameters` switch:

```swift
        case let .codeUnlockAttempt(result, id, category, isPro):
            return ["result": result, "animation_id": id, "category": category, "is_pro": isPro]
        case let .purchaseInitiated(productID, source):
            return ["product_id": productID, "source": source]
        case let .purchaseCancelled(productID, source, reason):
            return ["product_id": productID, "source": source, "reason": reason]
        case let .purchaseFailed(productID, source, reason):
            return ["product_id": productID, "source": source, "reason": reason]
        case let .paywallDismissed(source, secondsBucket):
            return ["source": source, "seconds_bucket": secondsBucket]
        case let .restoreCompleted(source):
            return ["source": source]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsEventTests' 2>&1 | tail -25`
Expected: PASS — `** TEST SUCCEEDED **`, all `AnalyticsEventTests` pass.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Analytics/AnalyticsEvent.swift InspireCreativityAppTests/AnalyticsEventTests.swift
git commit -m "feat(analytics): add purchase-funnel events + PurchaseContext" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 2: AnalyticsUserProperty + `set(_:)` across all backends

**Files:**
- Create: `InspireCreativityApp/Analytics/AnalyticsUserProperty.swift`
- Create: `InspireCreativityAppTests/AnalyticsUserPropertyTests.swift`
- Modify: `AnalyticsTracking.swift`, `FirebaseAnalyticsTracker.swift`, `ConsoleAnalyticsTracker.swift`, `NoOpAnalyticsTracker.swift`, `InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift`

**Interfaces:**
- Produces: `enum AnalyticsUserProperty: Equatable` with `.isPro(Bool)`, `.signedIn(Bool)`, `.platform(String)`, `.engagementLevel(String)`, `.animationsViewedBucket(String)`, each exposing `var name: String` and `var value: String?`; and `AnalyticsTracking.set(_ property: AnalyticsUserProperty)`.
- Produces: `SpyAnalyticsTracker.userProperties: [(name: String, value: String?)]`.

> Adding a protocol method breaks compilation until **all four conformers** (`Firebase`, `Console`, `NoOp`, `Spy`) implement it — do them in one step.

- [ ] **Step 1: Write the failing test** — create `AnalyticsUserPropertyTests.swift`:

```swift
import XCTest
@testable import InspireCreativityApp

final class AnalyticsUserPropertyTests: XCTestCase {
    func testNamesAndValuesWithinGA4Limits() {
        let props: [AnalyticsUserProperty] = [
            .isPro(true), .signedIn(false), .platform("macos"),
            .engagementLevel("engaged"), .animationsViewedBucket("11_30")
        ]
        for p in props {
            XCTAssertLessThanOrEqual(p.name.count, 24, "\(p.name) exceeds 24-char user-property limit")
            XCTAssertEqual(p.name, p.name.lowercased(), "\(p.name) must be snake_case")
            if let v = p.value { XCTAssertLessThanOrEqual(v.count, 36, "\(p.name) value too long") }
        }
    }

    func testMapping() {
        XCTAssertEqual(AnalyticsUserProperty.isPro(true).name, "is_pro")
        XCTAssertEqual(AnalyticsUserProperty.isPro(true).value, "true")
        XCTAssertEqual(AnalyticsUserProperty.signedIn(false).value, "false")
        XCTAssertEqual(AnalyticsUserProperty.platform("ios").name, "platform")
        XCTAssertEqual(AnalyticsUserProperty.engagementLevel("power").name, "engagement_level")
        XCTAssertEqual(AnalyticsUserProperty.animationsViewedBucket("0").name, "animations_viewed_bucket")
    }

    func testSpyRecordsUserProperties() {
        let spy = SpyAnalyticsTracker()
        spy.set(.isPro(true))
        XCTAssertEqual(spy.userProperties.first?.name, "is_pro")
        XCTAssertEqual(spy.userProperties.first?.value, "true")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsUserPropertyTests' 2>&1 | tail -25`
Expected: FAIL — `AnalyticsUserProperty` undefined; `SpyAnalyticsTracker` has no `userProperties`.

- [ ] **Step 3: Create the type + implement across backends**

Create `AnalyticsUserProperty.swift`:

```swift
//
//  AnalyticsUserProperty.swift
//  InspireCreativityApp
//
//  Typed GA4 user properties. Names ≤24 chars, values ≤36 chars, snake_case,
//  never PII. Mirrors the AnalyticsEvent pattern.
//

import Foundation

enum AnalyticsUserProperty: Equatable {
    case isPro(Bool)
    case signedIn(Bool)
    case platform(String)
    case engagementLevel(String)
    case animationsViewedBucket(String)

    var name: String {
        switch self {
        case .isPro:                  return "is_pro"
        case .signedIn:               return "signed_in"
        case .platform:               return "platform"
        case .engagementLevel:        return "engagement_level"
        case .animationsViewedBucket: return "animations_viewed_bucket"
        }
    }

    var value: String? {
        switch self {
        case let .isPro(on):                 return on ? "true" : "false"
        case let .signedIn(on):              return on ? "true" : "false"
        case let .platform(p):               return p
        case let .engagementLevel(l):        return l
        case let .animationsViewedBucket(b): return b
        }
    }
}
```

In `AnalyticsTracking.swift`, add to the protocol:

```swift
    func set(_ property: AnalyticsUserProperty)
```

In `FirebaseAnalyticsTracker.swift` (inside the `#if canImport(FirebaseAnalytics)` struct):

```swift
    func set(_ property: AnalyticsUserProperty) {
        Analytics.setUserProperty(property.value, forName: property.name)
    }
```

In `ConsoleAnalyticsTracker.swift`:

```swift
    func set(_ property: AnalyticsUserProperty) {
        print("[analytics] user_property \(property.name)=\(property.value ?? "nil")")
    }
```

In `NoOpAnalyticsTracker.swift`:

```swift
    func set(_ property: AnalyticsUserProperty) {}
```

In `SpyAnalyticsTracker.swift`, add the property and method:

```swift
    private(set) var userProperties: [(name: String, value: String?)] = []
    func set(_ property: AnalyticsUserProperty) { userProperties.append((property.name, property.value)) }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsUserPropertyTests' 2>&1 | tail -25`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Analytics/AnalyticsUserProperty.swift InspireCreativityApp/Analytics/AnalyticsTracking.swift InspireCreativityApp/Analytics/FirebaseAnalyticsTracker.swift InspireCreativityApp/Analytics/ConsoleAnalyticsTracker.swift InspireCreativityApp/Analytics/NoOpAnalyticsTracker.swift InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift InspireCreativityAppTests/AnalyticsUserPropertyTests.swift
git commit -m "feat(analytics): add typed AnalyticsUserProperty + set(_:) on all backends" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 3: JourneyMetrics counter + pure bucketing

**Files:**
- Create: `InspireCreativityApp/Analytics/JourneyMetrics.swift`
- Create: `InspireCreativityAppTests/JourneyMetricsTests.swift`

**Interfaces:**
- Consumes: `PurchaseContext` (Task 1), `CodeAccess` (`DetailViewModel.swift`, `Equatable`).
- Produces: `final class JourneyMetrics` with `init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() })`; `let didChange: PassthroughSubject<Void, Never>`; `recordAnimationView()`, `recordSearch()`, `recordFavorite()`, `recordCodeUnlockAttempt(result: CodeAccess)`; `var animationsViewedBucket: String`, `var engagementLevel: String`, `var hitProLock: Bool`; `func timeToPurchaseBucket() -> String`; `func snapshotForPurchase(signedIn: Bool) -> PurchaseContext`; and statics `viewsBucket(_:)`, `engagement(_:)`, `elapsedBucket(_:)`, `secondsBucket(_:)`.

- [ ] **Step 1: Write the failing test** — create `JourneyMetricsTests.swift`:

```swift
import XCTest
@testable import InspireCreativityApp

final class JourneyMetricsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "JourneyMetricsTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testViewsBucketBoundaries() {
        XCTAssertEqual(JourneyMetrics.viewsBucket(0), "0")
        XCTAssertEqual(JourneyMetrics.viewsBucket(1), "1_3")
        XCTAssertEqual(JourneyMetrics.viewsBucket(3), "1_3")
        XCTAssertEqual(JourneyMetrics.viewsBucket(4), "4_10")
        XCTAssertEqual(JourneyMetrics.viewsBucket(10), "4_10")
        XCTAssertEqual(JourneyMetrics.viewsBucket(11), "11_30")
        XCTAssertEqual(JourneyMetrics.viewsBucket(30), "11_30")
        XCTAssertEqual(JourneyMetrics.viewsBucket(31), "31_plus")
    }

    func testEngagementBoundaries() {
        XCTAssertEqual(JourneyMetrics.engagement(0), "new")
        XCTAssertEqual(JourneyMetrics.engagement(3), "browser")
        XCTAssertEqual(JourneyMetrics.engagement(4), "engaged")
        XCTAssertEqual(JourneyMetrics.engagement(15), "engaged")
        XCTAssertEqual(JourneyMetrics.engagement(16), "power")
    }

    func testElapsedAndSecondsBuckets() {
        XCTAssertEqual(JourneyMetrics.elapsedBucket(59 * 60), "lt_1h")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(2 * 3600), "1_24h")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(3 * 86_400), "1_7d")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(10 * 86_400), "7_30d")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(40 * 86_400), "gt_30d")
        XCTAssertEqual(JourneyMetrics.secondsBucket(4), "lt_5s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(10), "5_15s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(30), "15_60s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(90), "gt_60s")
    }

    func testRecordingAndSnapshot() {
        let d = freshDefaults()
        var t = Date(timeIntervalSince1970: 1_000_000)      // first-open time
        let m = JourneyMetrics(defaults: d, now: { t })
        m.recordAnimationView(); m.recordAnimationView(); m.recordAnimationView(); m.recordAnimationView() // 4
        m.recordCodeUnlockAttempt(result: .needsSignIn)     // does NOT count as pro lock
        XCTAssertFalse(m.hitProLock)
        m.recordCodeUnlockAttempt(result: .needsPro)        // pro lock
        XCTAssertTrue(m.hitProLock)
        t = Date(timeIntervalSince1970: 1_000_000 + 2 * 3600) // 2h later
        let ctx = m.snapshotForPurchase(signedIn: true)
        XCTAssertEqual(ctx.hitProLock, true)
        XCTAssertEqual(ctx.animationsViewedBucket, "4_10")
        XCTAssertEqual(ctx.timeToPurchaseBucket, "1_24h")
        XCTAssertEqual(ctx.signedIn, true)
    }

    func testPersistenceAcrossInstances() {
        let d = freshDefaults()
        JourneyMetrics(defaults: d).recordAnimationView()
        XCTAssertEqual(JourneyMetrics(defaults: d).animationsViewedBucket, "1_3")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/JourneyMetricsTests' 2>&1 | tail -25`
Expected: FAIL — `JourneyMetrics` undefined.

- [ ] **Step 3: Implement** — create `JourneyMetrics.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/JourneyMetricsTests' 2>&1 | tail -25`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Analytics/JourneyMetrics.swift InspireCreativityAppTests/JourneyMetricsTests.swift
git commit -m "feat(analytics): add device-local JourneyMetrics counter + bucketing" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 4: Instrument DetailViewModel + DetailView (code-unlock intent, view/favorite recording)

**Files:**
- Modify: `InspireCreativityApp/Features/Detail/DetailViewModel.swift`
- Modify: `InspireCreativityApp/Features/Detail/DetailView.swift:137-143`
- Test: `InspireCreativityAppTests/AnalyticsInstrumentationTests.swift`

**Interfaces:**
- Consumes: `JourneyMetrics` (Task 3), `AnalyticsEvent.codeUnlockAttempt` (Task 1).
- Produces: `DetailViewModel.init(..., journeyMetrics: JourneyMetrics = JourneyMetrics())` and `func logCodeUnlockAttempt(_ access: CodeAccess)`. Records `recordAnimationView()` on init and `recordFavorite()` on favoriting.

- [ ] **Step 1: Write the failing test** — append to `AnalyticsInstrumentationTests.swift`:

```swift
func testCodeUnlockAttemptLogsNeedsPro() {
    let spy = SpyAnalyticsTracker()
    // Pick a Pro item so the gate is needs_pro when signed out & not Pro.
    let proItem = AnimationCatalogSeed.items.first { $0.isPro }!
    let vm = DetailViewModel(animationId: proItem.id,
                             repository: InMemoryAnimationRepository(),
                             favorites: FavoritesRepository(),
                             purchases: StoreManager(),
                             analytics: spy)
    vm.logCodeUnlockAttempt(.needsPro)
    XCTAssertTrue(spy.events.contains {
        if case let .codeUnlockAttempt(result, _, _, _) = $0 { return result == "needs_pro" } else { return false }
    }, "unlock attempt on a Pro item must log code_unlock_attempt result=needs_pro")
}

func testCodeUnlockAttemptGrantedLogsNothing() {
    let spy = SpyAnalyticsTracker()
    let vm = DetailViewModel(animationId: AnimationCatalogSeed.items[0].id,
                             repository: InMemoryAnimationRepository(),
                             favorites: FavoritesRepository(),
                             purchases: StoreManager(),
                             analytics: spy)
    let before = spy.events.count
    vm.logCodeUnlockAttempt(.granted)
    XCTAssertEqual(spy.events.count, before, "granted access must not log an unlock attempt")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' 2>&1 | tail -25`
Expected: FAIL — `logCodeUnlockAttempt` not a member.

- [ ] **Step 3: Implement** — in `DetailViewModel.swift`:

Add stored property (near `private let analytics`):

```swift
    private let journeyMetrics: JourneyMetrics
```

Change the initializer signature (add param with default, keep existing params):

```swift
    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker(),
        journeyMetrics: JourneyMetrics = JourneyMetrics()
    ) {
```

Assign it (with the other assignments, before `bind()`):

```swift
        self.journeyMetrics = journeyMetrics
```

Right after the existing `analytics.log(.animationView(...))` in `init` (line 75-77), add:

```swift
        journeyMetrics.recordAnimationView()
```

In `toggleFavorite()`, after the existing `analytics.log(.favoriteToggled(...))`, add:

```swift
        if favorites.isFavorite(item.id) { journeyMetrics.recordFavorite() }
```

Add this method (next to `logCodeCopied()`):

```swift
    /// Logs the code-unlock intent from the leaf view's CTA. Granted access
    /// never reaches the lock CTA, so it is intentionally a no-op.
    func logCodeUnlockAttempt(_ access: CodeAccess) {
        let result: String
        switch access {
        case .needsPro:    result = "needs_pro"
        case .needsSignIn: result = "needs_sign_in"
        case .granted:     return
        }
        analytics.log(.codeUnlockAttempt(result: result,
                                         animationID: item.id,
                                         category: item.category.rawValue,
                                         isPro: item.isPro))
        journeyMetrics.recordCodeUnlockAttempt(result: access)
    }
```

In `DetailView.swift`, in the `onUnlock` closure (lines 137-143), call the VM at the top of the closure:

```swift
                        onUnlock: {
                            viewModel.logCodeUnlockAttempt(access)
                            switch access {
                            case .needsPro: router.push(.paywall(source: "detail"))
                            case .needsSignIn: showAuthSheet = true
                            case .granted: break
                            }
                        },
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' 2>&1 | tail -25`
Expected: PASS (existing tests still green — the new init param has a default).

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Features/Detail/DetailViewModel.swift InspireCreativityApp/Features/Detail/DetailView.swift InspireCreativityAppTests/AnalyticsInstrumentationTests.swift
git commit -m "feat(analytics): log code_unlock_attempt + journey recording in Detail" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 5: Record searches in BrowseViewModel

**Files:**
- Modify: `InspireCreativityApp/Features/Browse/BrowseViewModel.swift`
- Test: `InspireCreativityAppTests/AnalyticsInstrumentationTests.swift`

**Interfaces:**
- Produces: `BrowseViewModel.init(repository:analytics:journeyMetrics: JourneyMetrics = JourneyMetrics())`; calls `recordSearch()` where `search` is logged (`BrowseViewModel.swift:72`).

- [ ] **Step 1: Write the failing test** — append to `AnalyticsInstrumentationTests.swift`:

```swift
func testSearchRecordsJourneySearch() {
    let d = UserDefaults(suiteName: "BrowseSearch.\(UUID().uuidString)")!
    let metrics = JourneyMetrics(defaults: d)
    let vm = BrowseViewModel(repository: InMemoryAnimationRepository(),
                             analytics: SpyAnalyticsTracker(),
                             journeyMetrics: metrics)
    vm.searchText = "spinner"
    let settled = expectation(description: "debounce settled")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
    wait(for: [settled], timeout: 1.0)
    XCTAssertGreaterThanOrEqual(d.integer(forKey: "journey.searchesCount"), 1,
                                "a debounced search must record a journey search")
}
```

> Confirmed: `BrowseViewModel` has `@Published var searchText: String = ""` (line 19); the search log fires at line 72 inside a 120ms-debounced CombineLatest3 sink — the 0.3s test wait covers it.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests/testSearchRecordsJourneySearch' 2>&1 | tail -25`
Expected: FAIL — `journeyMetrics` is not a parameter of `BrowseViewModel.init`.

- [ ] **Step 3: Implement** — in `BrowseViewModel.swift`:

Add stored property + init param (default) mirroring the analytics one, assign in init. Then in the sink that logs `.search(termLength:)` (line ~72), add immediately after the `analytics.log(.search(...))` call:

```swift
                    self.journeyMetrics.recordSearch()
```

(Model the property/init edits on how `analytics` is stored and injected in the same file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' 2>&1 | tail -25`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Features/Browse/BrowseViewModel.swift InspireCreativityAppTests/AnalyticsInstrumentationTests.swift
git commit -m "feat(analytics): record journey searches in Browse" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 6: Purchase funnel + enriched purchase_completed + paywall dwell

**Files:**
- Modify: `InspireCreativityApp/Analytics/AnalyticsEvent.swift` (enrich `purchaseCompleted`)
- Modify: `InspireCreativityApp/Features/Paywall/PaywallViewModel.swift`
- Modify: `InspireCreativityApp/Features/Paywall/PaywallView.swift:30-35`
- Modify: `InspireCreativityAppTests/AnalyticsEventTests.swift` (fix existing purchaseCompleted test)
- Test: `InspireCreativityAppTests/AnalyticsInstrumentationTests.swift`

**Interfaces:**
- Consumes: `PurchaseContext`, `JourneyMetrics.snapshotForPurchase(signedIn:)`, `JourneyMetrics.secondsBucket(_:)`, `StoreManager.PurchaseOutcome`, `StoreManager.StoreError`.
- Produces: enriched `AnalyticsEvent.purchaseCompleted(productID:source:context:)`; `PaywallViewModel.init(store:analytics:source:journeyMetrics:signedIn:now:)`; `PaywallViewModel.markAppeared()`, `logDismissedIfNeeded()`.

- [ ] **Step 1: Write the failing test** — append to `AnalyticsInstrumentationTests.swift`:

```swift
func testPaywallDismissWithoutPurchaseLogsDismissed() {
    let spy = SpyAnalyticsTracker()
    var t = Date(timeIntervalSince1970: 0)
    let vm = PaywallViewModel(store: StoreManager(), analytics: spy, source: "detail",
                              journeyMetrics: JourneyMetrics(defaults: UserDefaults(suiteName: "pw.\(UUID().uuidString)")!),
                              signedIn: { false }, now: { t })
    vm.markAppeared()
    t = Date(timeIntervalSince1970: 8)          // 8s dwell
    vm.logDismissedIfNeeded()
    XCTAssertEqual(spy.events.last, .paywallDismissed(source: "detail", secondsBucket: "5_15s"),
                   "closing the paywall without buying must log paywall_dismissed with a dwell bucket")
}

func testPaywallDismissAfterCompletionLogsNothing() {
    let spy = SpyAnalyticsTracker()
    let vm = PaywallViewModel(store: StoreManager(), analytics: spy, source: "detail",
                              journeyMetrics: JourneyMetrics(defaults: UserDefaults(suiteName: "pw.\(UUID().uuidString)")!),
                              signedIn: { false }, now: { Date() })
    vm.markAppeared()
    vm.markCompletedForTesting()                // simulates a successful purchase
    vm.logDismissedIfNeeded()
    XCTAssertFalse(spy.events.contains { if case .paywallDismissed = $0 { return true } else { return false } },
                   "a completed purchase must not also log paywall_dismissed")
}
```

Also update the existing `AnalyticsEventTests.testPurchaseCompletedCarriesProductAndSource` to the enriched signature:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' 2>&1 | tail -25`
Expected: FAIL — `purchaseCompleted` has no `context:`; `markAppeared`/`logDismissedIfNeeded`/`markCompletedForTesting` undefined.

- [ ] **Step 3: Implement**

In `AnalyticsEvent.swift`, change the case:

```swift
    case purchaseCompleted(productID: String, source: String, context: PurchaseContext)
```

and its `parameters` branch:

```swift
        case let .purchaseCompleted(productID, source, context):
            return ["product_id": productID, "source": source,
                    "hit_pro_lock": context.hitProLock,
                    "animations_viewed_bucket": context.animationsViewedBucket,
                    "time_to_purchase_bucket": context.timeToPurchaseBucket,
                    "signed_in": context.signedIn]
```

In `PaywallViewModel.swift`, add stored deps + init params:

```swift
    private let journeyMetrics: JourneyMetrics
    private let signedIn: () -> Bool
    private let now: () -> Date
    private var appearedAt: Date?

    init(store: StoreManager, analytics: AnalyticsTracking, source: String,
         journeyMetrics: JourneyMetrics = JourneyMetrics(),
         signedIn: @escaping () -> Bool = { false },
         now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.analytics = analytics
        self.source = source
        self.journeyMetrics = journeyMetrics
        self.signedIn = signedIn
        self.now = now
    }
```

Replace `purchaseSelected()` body with the instrumented version:

```swift
    func purchaseSelected() async {
        errorMessage = nil
        guard let product = product(for: plan) else {
            errorMessage = StoreManager.StoreError.productsUnavailable.errorDescription
            return
        }
        analytics.log(.purchaseInitiated(productID: product.id, source: source))
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(product) {
            case .success:
                analytics.log(.purchaseCompleted(productID: product.id, source: source,
                                                 context: journeyMetrics.snapshotForPurchase(signedIn: signedIn())))
                didComplete = true
            case .pending:
                analytics.log(.purchaseCancelled(productID: product.id, source: source, reason: "pending"))
                errorMessage = "Your purchase is pending approval. You'll get access once it's approved."
            case .cancelled:
                analytics.log(.purchaseCancelled(productID: product.id, source: source, reason: "user_cancelled"))
            }
        } catch {
            let reason = (error as? StoreManager.StoreError) == .failedVerification ? "verification_failed" : "error"
            analytics.log(.purchaseFailed(productID: product.id, source: source, reason: reason))
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Purchase failed. Please try again."
        }
    }
```

In `restore()`, inside `if store.isPro { ... }` add before `didComplete = true`:

```swift
                analytics.log(.restoreCompleted(source: source))
```

Add the dwell methods:

```swift
    func markAppeared() { appearedAt = now() }

    func logDismissedIfNeeded() {
        guard !didComplete, let appearedAt else { return }
        let bucket = JourneyMetrics.secondsBucket(now().timeIntervalSince(appearedAt))
        analytics.log(.paywallDismissed(source: source, secondsBucket: bucket))
    }

    #if DEBUG
    /// Test hook: simulate a completed purchase without StoreKit.
    func markCompletedForTesting() { didComplete = true }
    #endif
```

> `StoreManager.StoreError` must be `Equatable` for the `== .failedVerification` check. It is a simple enum with no associated values, so add `: Equatable` to its declaration if the compiler requires it (`enum StoreError: LocalizedError, Equatable`).

In `PaywallView.swift`, extend the `.onAppear` and add `.onDisappear` (replace lines 30-35):

```swift
        .onChange(of: viewModel.didComplete) { _, done in
            if done { dismiss() }
        }
        .onAppear {
            container.analytics.log(.paywallViewed(source: viewModel.source))
            viewModel.markAppeared()
        }
        .onDisappear {
            viewModel.logDismissedIfNeeded()
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' -only-testing:'InspireCreativityAppTests/AnalyticsEventTests' 2>&1 | tail -25`
Expected: PASS (both classes).

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Analytics/AnalyticsEvent.swift InspireCreativityApp/Features/Paywall/PaywallViewModel.swift InspireCreativityApp/Features/Paywall/PaywallView.swift InspireCreativityApp/Store/StoreManager.swift InspireCreativityAppTests/AnalyticsEventTests.swift InspireCreativityAppTests/AnalyticsInstrumentationTests.swift
git commit -m "feat(analytics): instrument purchase funnel + enrich purchase_completed" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 7: macOS parity (MacDetailPane)

**Files:**
- Modify: `InspireCreativityApp/Features/MacShellV2/MacDetailPane.swift`

**Interfaces:**
- Consumes: `DetailViewModel.logCodeUnlockAttempt(_:)` (Task 4) — `MacDetailPane` already holds a `DetailViewModel` and computes `access` (line 41-47), so recording + event logic are shared; only the CTA call and screen tracking are Mac-specific.

- [ ] **Step 1: Locate the Mac unlock CTA** — the button whose label is `access == .needsPro ? "Unlock with Pro" : "Sign in to view the code"` (~line 439) and its action branch on `access` (~line 186 `if access == .needsSignIn { showAuth = true }`).

- [ ] **Step 2: Add the shared log call** — at the top of that CTA's action closure, before it opens auth/paywall, add:

```swift
                viewModel.logCodeUnlockAttempt(access)
```

- [ ] **Step 3: Ensure Mac screen tracking parity** — verify the Mac shell tracks `paywall`/`detail` screens. `AppRouter.push` already calls `analytics.track(screen:)` for mapped routes; if `MacDetailPane`/`MacAppView` navigate without the router, add `container.analytics.track(screen: .detail)` in the Mac detail pane's `.onAppear` and `.paywall` where the Mac paywall is presented. (No-op if the router already handles it.)

- [ ] **Step 4: Build both platforms**

Run: `xcodebuild build -scheme InspireCreativityApp -destination 'platform=macOS' 2>&1 | tail -15`
Then: `xcodebuild build -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **` for both.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Features/MacShellV2/MacDetailPane.swift
git commit -m "feat(analytics): macOS parity for code_unlock_attempt + screen tracking" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 8: Wire JourneyMetrics + user properties in AppContainer

**Files:**
- Modify: `InspireCreativityApp/App/AppContainer.swift`

**Interfaces:**
- Consumes: `JourneyMetrics`, `AnalyticsUserProperty`, `store.isProPublisher`, `authStore.$session`, `journeyMetrics.didChange`.
- Produces: `AppContainer.journeyMetrics`; injects it into `makeDetailViewModel`, `makeBrowseViewModel`, `makePaywallViewModel`; sets 5 user properties initially and reactively.

- [ ] **Step 1: Add the stored instance + cancellables** — near the other `let` deps:

```swift
    let journeyMetrics: JourneyMetrics
    private var analyticsCancellables = Set<AnyCancellable>()
```

Ensure `import Combine` is present at the top of the file.

- [ ] **Step 2: Construct + wire in `init`** — after `analytics`, `store`, and `authStore` are assigned (they exist by line ~62), add:

```swift
        let journeyMetrics = JourneyMetrics()
        self.journeyMetrics = journeyMetrics

        #if os(macOS)
        analytics.set(.platform("macos"))
        #else
        analytics.set(.platform("ios"))
        #endif
        analytics.set(.isPro(store.isPro))
        analytics.set(.signedIn(authStore.isAuthenticated))
        analytics.set(.engagementLevel(journeyMetrics.engagementLevel))
        analytics.set(.animationsViewedBucket(journeyMetrics.animationsViewedBucket))

        store.isProPublisher
            .sink { [analytics] isPro in analytics.set(.isPro(isPro)) }
            .store(in: &analyticsCancellables)

        authStore.$session
            .sink { [analytics] session in analytics.set(.signedIn(session != nil)) }
            .store(in: &analyticsCancellables)

        journeyMetrics.didChange
            .sink { [analytics, journeyMetrics] in
                analytics.set(.engagementLevel(journeyMetrics.engagementLevel))
                analytics.set(.animationsViewedBucket(journeyMetrics.animationsViewedBucket))
            }
            .store(in: &analyticsCancellables)
```

> `analyticsCancellables` is mutated after `self` is initialized — place this block after all stored `let`s are assigned. If Swift complains about using `self` early, move the `.store(in:)` subscriptions to the end of `init`.

- [ ] **Step 3: Inject into the factories** — update the three factory methods:

```swift
    func makeBrowseViewModel() -> BrowseViewModel {
        BrowseViewModel(repository: animationRepository, analytics: analytics, journeyMetrics: journeyMetrics)
    }

    func makeDetailViewModel(animationId: String) -> DetailViewModel {
        DetailViewModel(
            animationId: animationId,
            repository: animationRepository,
            favorites: favoritesRepository,
            purchases: store,
            analytics: analytics,
            journeyMetrics: journeyMetrics
        )
    }

    func makePaywallViewModel(source: String) -> PaywallViewModel {
        PaywallViewModel(store: store, analytics: analytics, source: source,
                         journeyMetrics: journeyMetrics,
                         signedIn: { [authStore] in authStore.isAuthenticated })
    }
```

> Match the exact existing argument labels/values for `repository`/`favorites`/`purchases` as currently written in `AppContainer` (e.g. `favoritesRepository`), changing only the added `journeyMetrics`/`signedIn` arguments.

- [ ] **Step 4: Build + run full analytics test suite**

Run: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'InspireCreativityAppTests/AnalyticsEventTests' -only-testing:'InspireCreativityAppTests/AnalyticsUserPropertyTests' -only-testing:'InspireCreativityAppTests/JourneyMetricsTests' -only-testing:'InspireCreativityAppTests/AnalyticsInstrumentationTests' -only-testing:'InspireCreativityAppTests/AnalyticsConsentTests' 2>&1 | tail -25`
Expected: PASS (all analytics suites). Then macOS build:
`xcodebuild build -scheme InspireCreativityApp -destination 'platform=macOS' 2>&1 | tail -15` → `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/App/AppContainer.swift
git commit -m "feat(analytics): set GA4 user properties + wire JourneyMetrics DI" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

### Task 9: GA4 console setup docs

**Files:**
- Modify: `docs/analytics-setup.md`

- [ ] **Step 1: Append a "Purchase-journey attribution" section** documenting exactly:

```markdown
## Purchase-journey attribution (GA4)

New events: `code_unlock_attempt`, `purchase_initiated`, `purchase_cancelled`,
`purchase_failed`, `paywall_dismissed`, `restore_completed`; enriched
`purchase_completed` (params `hit_pro_lock`, `animations_viewed_bucket`,
`time_to_purchase_bucket`, `signed_in`).
New user properties: `is_pro`, `signed_in`, `platform`, `engagement_level`,
`animations_viewed_bucket`.

### Register custom dimensions (Admin → Custom definitions)
- Event-scoped: `result`, `category`, `is_pro`, `reason`, `source`,
  `seconds_bucket`, `hit_pro_lock`, `animations_viewed_bucket`,
  `time_to_purchase_bucket`. (Do NOT register `animation_id` — high cardinality;
  it stays a queryable param / BigQuery field.)
- User-scoped: `is_pro`, `signed_in`, `platform`, `engagement_level`,
  `animations_viewed_bucket`.

### Mark the conversion
- Admin → Events → mark `purchase_completed` as a **Key Event**.

### Explorations to build
1. Funnel: `animation_view` → `code_unlock_attempt` (result=needs_pro) →
   `paywall_viewed` → `purchase_initiated` → `purchase_completed`.
2. Path exploration backward from `purchase_completed`.
3. Segment comparison: buyers × `engagement_level`.
4. Conversion rate by paywall `source`.

### Optional
- Enable the free BigQuery export (Admin → BigQuery links) for raw SQL path analysis.

### Verify (DebugView)
Run a debug build, exercise browse → Pro lock → paywall → cancel → buy, and
confirm each event, its params, the 5 user properties, and the enriched
`purchase_completed` appear. Toggle analytics off and confirm nothing is sent.
```

- [ ] **Step 2: Confirm privacy manifest** — open `InspireCreativityApp/PrivacyInfo.xcprivacy`; verify the declared collected-data types already include "Product Interaction" (they do today). No new data category is introduced, so no edit is expected; note the check in the commit body if confirmed.

- [ ] **Step 3: Commit**

```bash
git add docs/analytics-setup.md
git commit -m "docs(analytics): GA4 setup for purchase-journey attribution" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01GtwAscm7WbjBAT8XzzHbB6"
```

---

## Final verification (after all tasks)

- [ ] Full suite: `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30` → `** TEST SUCCEEDED **`.
- [ ] macOS build: `xcodebuild build -scheme InspireCreativityApp -destination 'platform=macOS' 2>&1 | tail -15` → `** BUILD SUCCEEDED **`.
- [ ] Manual GA4 DebugView pass per Task 9 Step 3 (iOS and macOS).

## Self-Review (author checklist — completed)

- **Spec coverage:** §5.1→T1; §5.2/5.3→T2; §5.4→T3; §5.6 detail→T4, search→T5, paywall/purchase→T6, Mac→T7; §5.5 user-property wiring→T8; §9 docs→T9; §10 tests spread across T1–T6; §8 privacy→T9 Step 2. All spec sections mapped.
- **Placeholder scan:** every code step contains real code; test commands have expected output. The two "confirm exact label/property name" notes (T5 `searchText`, T8 factory labels, T7 CTA location) are verification cues against named line numbers, not missing content.
- **Type consistency:** `PurchaseContext` fields identical across T1/T3/T6; `logCodeUnlockAttempt(_:)`, `recordCodeUnlockAttempt(result:)`, `snapshotForPurchase(signedIn:)`, `secondsBucket(_:)` names consistent T3↔T4↔T6; new init params use defaults so earlier call sites keep compiling until T8 threads the real instance.
