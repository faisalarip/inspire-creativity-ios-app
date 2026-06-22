# Google Analytics (Firebase) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Google Analytics (Firebase Analytics / GA4) to the iOS app behind a swappable `AnalyticsTracking` protocol, on-by-default with a Settings opt-out, emitting auto screen views + ~10 curated product events.

**Architecture:** A tiny analytics abstraction (`AnalyticsTracking` protocol + typed `AnalyticsEvent`/`AnalyticsScreen` enums) is injected from `AppContainer` (the composition root) into view-models and `AuthStore`, exactly like the existing repository dependencies. Concrete backends: `FirebaseAnalyticsTracker` (the only file importing Firebase), `NoOpAnalyticsTracker` (tests/previews/no-plist), `ConsoleAnalyticsTracker` (DEBUG). `FirebaseApp.configure()` is **guarded** by the presence of `GoogleService-Info.plist`, so the project builds and runs without it (CI/contributors get the no-op path).

**Tech Stack:** Swift / SwiftUI, Firebase iOS SDK (`FirebaseAnalytics` product) via SPM, XCTest. New files are added to the explicit-reference Xcode target with the existing `ruby Tools/add_sources.rb`.

**Spec:** `docs/superpowers/specs/2026-06-22-google-analytics-design.md`

**Conventions for every task:**
- Build: `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build`
- Test: same command with `test` instead of `build`.
- New `.swift` files must be registered in the target: `ruby Tools/add_sources.rb <relpath ...>` (idempotent), then build.
- Branch: `feat/google-analytics` (already created; spec committed there).

---

## Task 1: Analytics core — protocol + typed event/screen enums

**Files:**
- Create: `InspireCreativityApp/Analytics/AnalyticsScreen.swift`
- Create: `InspireCreativityApp/Analytics/AnalyticsEvent.swift`
- Create: `InspireCreativityApp/Analytics/AnalyticsTracking.swift`
- Test: `InspireCreativityAppTests/AnalyticsEventTests.swift`

- [ ] **Step 1: Write the failing test** — `InspireCreativityAppTests/AnalyticsEventTests.swift`

```swift
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
            .paywallViewed(source: "detail"),
            .purchaseCompleted(productID: "pro.lifetime"),
            .signIn(method: "apple"),
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

    func testEventEquatable() {
        XCTAssertEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                       AnalyticsEvent.favoriteToggled(id: "a", on: true))
        XCTAssertNotEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                          AnalyticsEvent.favoriteToggled(id: "a", on: false))
    }
}
```

- [ ] **Step 2: Run the test, verify it fails to compile** — `AnalyticsEvent` undefined.

Run the Test command. Expected: FAIL (cannot find `AnalyticsEvent`).

- [ ] **Step 3: Create `AnalyticsScreen.swift`**

```swift
//
//  AnalyticsScreen.swift
//  InspireCreativityApp
//
//  Logical screens for GA4 `screen_view`. Raw value == GA4 screen_name.
//

import Foundation

enum AnalyticsScreen: String {
    case discover, browse, detail, paywall, settings, samples, library
}
```

- [ ] **Step 4: Create `AnalyticsEvent.swift`**

```swift
//
//  AnalyticsEvent.swift
//  InspireCreativityApp
//
//  Typed analytics events. `name`/`parameters` map to GA4 (snake_case, ≤40-char
//  names, ≤100-char string values, no reserved ga_/firebase_/google_ prefix).
//  NEVER carries PII — search logs term length, not the query.
//

import Foundation

enum AnalyticsEvent: Equatable {
    case animationView(id: String, category: String, isPro: Bool)
    case codeCopied(id: String)
    case favoriteToggled(id: String, on: Bool)
    case search(termLength: Int)
    case categorySelected(String)
    case paywallViewed(source: String)
    case purchaseCompleted(productID: String)
    case signIn(method: String)
    case auroraPromoTap

    var name: String {
        switch self {
        case .animationView:     return "animation_view"
        case .codeCopied:        return "code_copied"
        case .favoriteToggled:   return "favorite_toggled"
        case .search:            return "search"
        case .categorySelected:  return "category_selected"
        case .paywallViewed:     return "paywall_viewed"
        case .purchaseCompleted: return "purchase_completed"
        case .signIn:            return "sign_in"
        case .auroraPromoTap:    return "aurora_promo_tap"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .animationView(id, category, isPro):
            return ["animation_id": id, "category": category, "is_pro": isPro]
        case let .codeCopied(id):
            return ["animation_id": id]
        case let .favoriteToggled(id, on):
            return ["animation_id": id, "favorited": on]
        case let .search(termLength):
            return ["term_length": termLength]
        case let .categorySelected(category):
            return ["category": category]
        case let .paywallViewed(source):
            return ["source": source]
        case let .purchaseCompleted(productID):
            return ["product_id": productID]
        case let .signIn(method):
            return ["method": method]
        case .auroraPromoTap:
            return [:]
        }
    }
}
```

- [ ] **Step 5: Create `AnalyticsTracking.swift`**

```swift
//
//  AnalyticsTracking.swift
//  InspireCreativityApp
//
//  Abstraction over the analytics backend. Call sites depend on this; only
//  FirebaseAnalyticsTracker imports Firebase.
//

import Foundation

protocol AnalyticsTracking {
    func log(_ event: AnalyticsEvent)
    func track(screen: AnalyticsScreen)
    func setCollectionEnabled(_ on: Bool)
}
```

- [ ] **Step 6: Register the files in the Xcode target**

Run: `ruby Tools/add_sources.rb InspireCreativityApp/Analytics/AnalyticsScreen.swift InspireCreativityApp/Analytics/AnalyticsEvent.swift InspireCreativityApp/Analytics/AnalyticsTracking.swift`
Expected: `added 3: …`

- [ ] **Step 7: Run the tests, verify they pass**

Run the Test command. Expected: PASS (all `AnalyticsEventTests`), existing suite still green.

- [ ] **Step 8: Commit**

```bash
git add InspireCreativityApp/Analytics InspireCreativityAppTests/AnalyticsEventTests.swift InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): typed AnalyticsEvent/Screen + AnalyticsTracking protocol"
```

---

## Task 2: Trackers — NoOp, Console, and a test Spy

**Files:**
- Create: `InspireCreativityApp/Analytics/NoOpAnalyticsTracker.swift`
- Create: `InspireCreativityApp/Analytics/ConsoleAnalyticsTracker.swift`
- Test: `InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift`

- [ ] **Step 1: Create `NoOpAnalyticsTracker.swift`**

```swift
//
//  NoOpAnalyticsTracker.swift
//  InspireCreativityApp
//
//  Used in tests/previews and whenever GoogleService-Info.plist is absent.
//

import Foundation

struct NoOpAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {}
    func track(screen: AnalyticsScreen) {}
    func setCollectionEnabled(_ on: Bool) {}
}
```

- [ ] **Step 2: Create `ConsoleAnalyticsTracker.swift`**

```swift
//
//  ConsoleAnalyticsTracker.swift
//  InspireCreativityApp
//
//  DEBUG-only echo so events are verifiable locally without a backend.
//

import Foundation

struct ConsoleAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {
        print("[analytics] event=\(event.name) params=\(event.parameters)")
    }
    func track(screen: AnalyticsScreen) {
        print("[analytics] screen_view screen=\(screen.rawValue)")
    }
    func setCollectionEnabled(_ on: Bool) {
        print("[analytics] collection_enabled=\(on)")
    }
}
```

- [ ] **Step 3: Create the test Spy** — `InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift`

```swift
import Foundation
@testable import InspireCreativityApp

/// Records calls so tests can assert which events a view-model emits.
final class SpyAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var screens: [AnalyticsScreen] = []
    private(set) var collectionEnabledCalls: [Bool] = []

    func log(_ event: AnalyticsEvent) { events.append(event) }
    func track(screen: AnalyticsScreen) { screens.append(screen) }
    func setCollectionEnabled(_ on: Bool) { collectionEnabledCalls.append(on) }

    var loggedNames: [String] { events.map(\.name) }
}
```

- [ ] **Step 4: Register the source files** (the Spy is a test file — `add_sources.rb` targets the app target only, so the Spy must be added to the **test** target manually in Xcode, or via the ruby `xcodeproj` API targeting `InspireCreativityAppTests`. For this plan, add the two app files now:)

Run: `ruby Tools/add_sources.rb InspireCreativityApp/Analytics/NoOpAnalyticsTracker.swift InspireCreativityApp/Analytics/ConsoleAnalyticsTracker.swift`

Then add the Spy to the test target:

```bash
ruby -e 'require "xcodeproj"; p=Xcodeproj::Project.open("InspireCreativityApp.xcodeproj"); t=p.targets.find{|x| x.name=="InspireCreativityAppTests"}; g=p.main_group.find_subpath("InspireCreativityAppTests/Support",true); g.set_source_tree("SOURCE_ROOT"); f=g.new_reference(File.expand_path("InspireCreativityAppTests/Support/SpyAnalyticsTracker.swift")); t.source_build_phase.add_file_reference(f,true); p.save'
```

- [ ] **Step 5: Build, verify green**

Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add InspireCreativityApp/Analytics InspireCreativityAppTests/Support InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): NoOp + Console trackers and test SpyAnalyticsTracker"
```

---

## Task 3: Inject analytics from AppContainer (no Firebase yet)

**Files:**
- Modify: `InspireCreativityApp/App/AppContainer.swift` (init ~31–48; factories ~86–120; `AuthStore` class ~725+)

- [ ] **Step 1: Add the stored property + creation in `AppContainer`**

In `AppContainer` (after `let authStore: AuthStore`, ~line 22) add:

```swift
    let analytics: AnalyticsTracking
```

In `init`, after `self.authStore = AuthStore()` becomes (replace that line):

```swift
        let analytics: AnalyticsTracking = {
            #if DEBUG
            return ConsoleAnalyticsTracker()
            #else
            return NoOpAnalyticsTracker()   // replaced by Firebase in Task 6
            #endif
        }()
        self.analytics = analytics
        self.authStore = AuthStore(analytics: analytics)
```

- [ ] **Step 2: Thread `analytics` into the VM factories** (lines ~86–120)

Replace the six factories with:

```swift
    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: animationRepository)
    }
    func makeBrowseViewModel() -> BrowseViewModel {
        BrowseViewModel(repository: animationRepository, analytics: analytics)
    }
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(repository: animationRepository)
    }
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(repository: animationRepository,
                         favoritesRepo: favoritesRepository,
                         purchases: purchaseRepository)
    }
    func makeDetailViewModel(animationId: String) -> DetailViewModel {
        DetailViewModel(animationId: animationId,
                        repository: animationRepository,
                        favorites: favoritesRepository,
                        purchases: purchaseRepository,
                        analytics: analytics)
    }
    func makePaywallViewModel() -> PaywallViewModel {
        PaywallViewModel(store: store)
    }
```

(`DiscoverViewModel`, `SearchViewModel`, `LibraryViewModel`, `PaywallViewModel` are not instrumented via their VM in this plan — Discover/Paywall screen + promo events are fired from the views/router in Task 5. Only `BrowseViewModel` and `DetailViewModel` gain the dependency.)

- [ ] **Step 3: Give `AuthStore` an analytics dependency** (class at ~line 725 in AppContainer.swift)

Add a stored property and initializer parameter. Near the top of `AuthStore`:

```swift
    private let analytics: AnalyticsTracking

    init(analytics: AnalyticsTracking) {
        self.analytics = analytics
    }
```

(If `AuthStore` already has an `init`, merge the parameter into it. If it relied on a default memberwise/empty init, this replaces it — update the single call site in `AppContainer.init` done in Step 1.)

- [ ] **Step 4: Build, verify green** (`DetailViewModel`/`BrowseViewModel`/`AuthStore` inits don't yet accept `analytics` — this step will FAIL to compile; that's expected and fixed in Task 4. To keep this task self-contained, temporarily accept the dependency in those three inits as unused stored properties now.)

Add to `BrowseViewModel`, `DetailViewModel` (and confirm `AuthStore`): an `analytics` stored property + init param (unused for now). Minimal edit to `BrowseViewModel.swift` init (line 28):

```swift
    private let analytics: AnalyticsTracking
    init(repository: AnalyticsRepoPlaceholder ...) { ... }   // see exact edits in Task 4
```

> NOTE: Steps 2–4 introduce the dependency and Task 4 immediately consumes it. If executing strictly task-by-task with a green build between tasks, fold Task 3 Step 2–4 and Task 4 together into one commit. Recommended: implement Task 3 + Task 4 as a unit, commit once at the end of Task 4.

- [ ] **Step 5: Commit** (combined with Task 4 — see note).

---

## Task 4: Instrument the curated events

**Files:**
- Modify: `InspireCreativityApp/Features/Detail/DetailViewModel.swift` (init ~42–59; `toggleFavorite` ~80–82)
- Modify: `InspireCreativityApp/Features/Detail/CodeSheet.swift` (`copy()` ~161–168) — needs the item id passed in
- Modify: `InspireCreativityApp/Features/Browse/BrowseViewModel.swift` (init ~28; `bind()` ~35–56)
- Modify: `InspireCreativityApp/Store/StoreManager.swift` (`purchase` success ~104)
- Modify: `InspireCreativityApp/App/AppContainer.swift` (`AuthStore.signIn*` ~825/846/867)
- Test: `InspireCreativityAppTests/AnalyticsInstrumentationTests.swift`

- [ ] **Step 1: Write failing instrumentation tests**

```swift
import XCTest
@testable import InspireCreativityApp

@MainActor
final class AnalyticsInstrumentationTests: XCTestCase {

    func testDetailLogsAnimationViewOnOpen() {
        let spy = SpyAnalyticsTracker()
        let vm = DetailViewModel(animationId: AnimationCatalogSeed.items[0].id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        _ = vm
        XCTAssertTrue(spy.events.contains { if case .animationView = $0 { return true } else { return false } },
                      "opening Detail must log animation_view")
    }

    func testToggleFavoriteLogsEvent() {
        let spy = SpyAnalyticsTracker()
        let item = AnimationCatalogSeed.items[0]
        let vm = DetailViewModel(animationId: item.id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        vm.toggleFavorite()
        XCTAssertTrue(spy.events.contains(.favoriteToggled(id: item.id, on: vm.isFavorited)),
                      "toggleFavorite must log favorite_toggled with the resulting state")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail** — `DetailViewModel` init has no `analytics:` param. Expected: FAIL to compile.

- [ ] **Step 3: Instrument `DetailViewModel`**

Add the dependency to the init and log on resolve + on favorite. Edit init (42–59) — add the parameter and, after `self.item = resolved` (line 51):

```swift
    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        analytics: AnalyticsTracking
    ) {
        self.analytics = analytics
        let resolved = repository.find(id: animationId) ?? repository.featured()
        self.item = resolved
        // … existing assignments / bindings unchanged …
        analytics.log(.animationView(id: resolved.id,
                                     category: resolved.category.rawValue,
                                     isPro: resolved.isPro))
    }
```

Add the stored property near the other lets:

```swift
    private let analytics: AnalyticsTracking
```

Edit `toggleFavorite` (80–82):

```swift
    func toggleFavorite() {
        favorites.toggle(item.id)
        analytics.log(.favoriteToggled(id: item.id, on: isFavorited))
    }
```

(`isFavorited` is the VM's published favorite state, refreshed by the favorites binding.)

- [ ] **Step 4: Instrument `CodeSheet` copy**

`CodeSheet` needs the animation id + analytics to log a copy. Add two parameters to the `CodeSheet` initializer (it's a `View` struct) — `animationID: String` and `analytics: AnalyticsTracking` — and pass them from `DetailView` where `CodeSheet(...)` is constructed (DetailView already holds `viewModel.item.id` and can read analytics from the environment or have it injected). Then edit `copy()` (161–168):

```swift
    private func copy() {
        UIPasteboard.general.string = source
        analytics.log(.codeCopied(id: animationID))
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copied = false
        }
    }
```

To avoid plumbing analytics into a leaf `View`, expose `logCopy: () -> Void` on `CodeSheet` instead and have `DetailView` pass `{ analytics.log(.codeCopied(id: viewModel.item.id)) }`. Use whichever matches the surrounding style; the closure approach keeps `CodeSheet` Firebase-free and id-free.

- [ ] **Step 5: Instrument `BrowseViewModel`** (search + category)

Edit init (28) to accept analytics; track previous values to fire only on change inside the existing `bind()` sink (35–56):

```swift
    private let analytics: AnalyticsTracking
    private var lastLoggedCategory: Category??  = nil
    private var lastLoggedQueryLen: Int = -1

    init(repository: AnimationRepositoryProtocol, analytics: AnalyticsTracking) {
        self.repository = repository
        self.analytics = analytics
        self.categories = repository.categories()
        self.totalCount = repository.all().count
        bind()
    }
```

Inside the CombineLatest3 sink, before/after `self?.refresh(...)`:

```swift
            .sink { [weak self] cat, sort, query in
                guard let self else { return }
                self.refresh(category: cat, sort: sort, query: query)
                if self.lastLoggedCategory != .some(cat) {
                    self.lastLoggedCategory = .some(cat)
                    self.analytics.log(.categorySelected(cat?.rawValue ?? "all"))
                }
                let len = query.trimmingCharacters(in: .whitespacesAndNewlines).count
                if len > 0 && len != self.lastLoggedQueryLen {
                    self.lastLoggedQueryLen = len
                    self.analytics.log(.search(termLength: len))
                }
            }
```

- [ ] **Step 6: Instrument `StoreManager` purchase** (success ~104)

`StoreManager` is created without analytics in `AppContainer`. Give it an optional analytics setter to avoid changing its many call sites:

```swift
    var analytics: AnalyticsTracking = NoOpAnalyticsTracker()
```

In `AppContainer.init` after creating `store`: `store.analytics = analytics`. Then in `purchase(_:)` after `justPurchased = true` (line 104):

```swift
            justPurchased = true
            analytics.log(.purchaseCompleted(productID: product.id))
            return .success
```

- [ ] **Step 7: Instrument `AuthStore` sign-in** (825 / 846 / 867)

After each `justSignedIn = true`:
- email path: `analytics.log(.signIn(method: "email"))`
- apple path: `analytics.log(.signIn(method: "apple"))`
- google path: `analytics.log(.signIn(method: "google"))`

- [ ] **Step 8: Run tests, verify pass**

Run the Test command. Expected: PASS (`AnalyticsInstrumentationTests` + existing suite).

- [ ] **Step 9: Commit**

```bash
git add InspireCreativityApp InspireCreativityAppTests InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): inject tracker via AppContainer + instrument 8 product events"
```

---

## Task 5: Screen tracking + paywall/promo events

**Files:**
- Modify: `InspireCreativityApp/App/RootView.swift` (tab ZStack ~56–65)
- Modify: `InspireCreativityApp/App/AppRouter.swift` (`push` ~77–84; add screen mapping)
- Modify: `InspireCreativityApp/Features/Paywall/PaywallView.swift` (body ~17–32)
- Modify: `InspireCreativityApp/Features/Discover/DiscoverView.swift` (AuroraPackPromoCard call site)

- [ ] **Step 1: Make `AppRouter` analytics-aware**

`AppRouter` is an `ObservableObject` owned by the container. Add:

```swift
    var analytics: AnalyticsTracking = NoOpAnalyticsTracker()

    private func screen(for route: AppRoute) -> AnalyticsScreen? {
        switch route {
        case .detail: return .detail
        case .paywall: return .paywall
        default: return nil
        }
    }
```

In `push(_:)` after the `switch` that appends the route:

```swift
        if let screen = screen(for: route) { analytics.track(screen: screen) }
```

Wire it in `AppContainer.init`: after building `analytics`, set `router`'s analytics if the container owns the router; otherwise set it where `AppRouter` is created (search for `AppRouter()`), e.g. in `RootView`'s `@StateObject`. If `AppRouter` is created in `RootView`, instead pass analytics via `.environmentObject` and set `router.analytics = container.analytics` in `RootView.onAppear`.

- [ ] **Step 2: Track tab changes in `RootView`** (after the tab ZStack, ~line 65)

```swift
        .onChange(of: router.selectedTab) { _, tab in
            analytics.track(screen: AnalyticsScreen(rawValue: tab.id) ?? .discover)
        }
        .onAppear { analytics.track(screen: .discover) }   // initial screen
```

`RootView` reads `analytics` from `@EnvironmentObject private var container: AppContainer` → `container.analytics`. (`AppTab.id` raw values are `discover`/`browse`/`samples`/`library`, matching `AnalyticsScreen`.)

- [ ] **Step 3: Paywall viewed** — `PaywallView` body (~31), append:

```swift
        .onAppear { container.analytics.log(.paywallViewed(source: router.selectedTab.id)) }
```

(`PaywallView` already has `router`; add `@EnvironmentObject private var container: AppContainer` if not present.)

- [ ] **Step 4: Aurora promo tap** — in `DiscoverView` where `AuroraPackPromoCard(action:)` is built, wrap the action:

```swift
        AuroraPackPromoCard {
            container.analytics.log(.auroraPromoTap)
            router.push(.paywall)
        }
```

- [ ] **Step 5: Build, verify green.** Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add InspireCreativityApp InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): screen_view on tab/push + paywall_viewed + aurora_promo_tap"
```

---

## Task 6: Add Firebase SDK + real backend

**Files:**
- Modify: `InspireCreativityApp.xcodeproj` (SPM package `firebase-ios-sdk`, product `FirebaseAnalytics`)
- Create: `InspireCreativityApp/Analytics/FirebaseAnalyticsTracker.swift`
- Modify: `InspireCreativityApp/App/InspireCreativityApp.swift` (guarded configure)
- Modify: `InspireCreativityApp/App/AppContainer.swift` (use Firebase tracker when available)

- [ ] **Step 1: Add the Firebase SPM dependency**

```bash
ruby -e 'require "xcodeproj"; p=Xcodeproj::Project.open("InspireCreativityApp.xcodeproj"); \
ref=p.root_object.package_references.find{|r| r.respond_to?(:repositoryURL) && r.repositoryURL&.include?("firebase-ios-sdk")}; \
unless ref; ref=p.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference); ref.repositoryURL="https://github.com/firebase/firebase-ios-sdk.git"; ref.requirement={"kind"=>"upToNextMajorVersion","minimumVersion"=>"11.0.0"}; p.root_object.package_references<<ref; end; \
t=p.targets.find{|x| x.name=="InspireCreativityApp"}; \
dep=p.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency); dep.package=ref; dep.product_name="FirebaseAnalytics"; \
t.package_product_dependencies<<dep; \
bf=t.frameworks_build_phase.add_file_reference(p.new(Xcodeproj::Project::Object::PBXBuildFile)) rescue nil; \
p.save'
```

(If the gem-driven package edit is unreliable on this Xcode version, add it via Xcode UI: File ▸ Add Package Dependencies ▸ `https://github.com/firebase/firebase-ios-sdk` ▸ add **FirebaseAnalytics** to the app target. Resolve packages, then build.)

Run the Build command to resolve packages. Expected: package graph resolves; `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Create `FirebaseAnalyticsTracker.swift`**

```swift
//
//  FirebaseAnalyticsTracker.swift
//  InspireCreativityApp
//
//  The only file that imports Firebase. Compiles to nothing until the
//  FirebaseAnalytics product is linked.
//

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics

struct FirebaseAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
    func track(screen: AnalyticsScreen) {
        Analytics.logEvent(AnalyticsEventScreenView,
                           parameters: [AnalyticsParameterScreenName: screen.rawValue])
    }
    func setCollectionEnabled(_ on: Bool) {
        Analytics.setAnalyticsCollectionEnabled(on)
    }
}
#endif
```

Register: `ruby Tools/add_sources.rb InspireCreativityApp/Analytics/FirebaseAnalyticsTracker.swift`

- [ ] **Step 3: Guarded `configure()` + tracker factory**

In `InspireCreativityApp.swift`, add an `init()`:

```swift
import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct InspireCreativityApp: App {
    @StateObject private var container = AppContainer()

    init() {
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
    }
    // … body unchanged …
}
```

In `AppContainer`, replace the Task-3 tracker block with a factory that prefers Firebase when configured:

```swift
        let analytics: AnalyticsTracking = AppContainer.makeAnalyticsTracker()
        self.analytics = analytics
        self.authStore = AuthStore(analytics: analytics)

    // …

    private static func makeAnalyticsTracker() -> AnalyticsTracking {
        #if canImport(FirebaseAnalytics)
        if FirebaseApp.app() != nil { return FirebaseAnalyticsTracker() }
        #endif
        #if DEBUG
        return ConsoleAnalyticsTracker()
        #else
        return NoOpAnalyticsTracker()
        #endif
    }
```

(Add `#if canImport(FirebaseCore) import FirebaseCore #endif` at the top of `AppContainer.swift` for `FirebaseApp.app()`.)

- [ ] **Step 4: Build with and without the plist**

Without `GoogleService-Info.plist`: run Build. Expected: `** BUILD SUCCEEDED **`, app uses Console/NoOp. Run the Test command — existing + analytics tests green.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): Firebase backend + guarded FirebaseApp.configure()"
```

---

## Task 7: Settings opt-out toggle

**Files:**
- Modify: `InspireCreativityApp/Features/Settings/SettingsView.swift` (`aboutSection` ~139–149; state ~15)
- Modify: `InspireCreativityApp/App/AppContainer.swift` (apply persisted preference at startup)

- [ ] **Step 1: Apply the persisted preference at startup**

In `AppContainer.init`, right after `self.analytics = analytics`:

```swift
        let enabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        analytics.setCollectionEnabled(enabled)
```

- [ ] **Step 2: Add the toggle to Settings**

Add state near line 15:

```swift
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @EnvironmentObject private var container: AppContainer
```

In `aboutSection`, after the "Contact support" `actionRow` (line 148), add:

```swift
            Divider().overlay(Theme.Palette.hairline)
            Toggle(isOn: $analyticsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.white.opacity(0.8)).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share usage analytics")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("Anonymous — helps improve the app")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .toggleStyle(.switch)
            .tint(Theme.Palette.accent)
            .onChange(of: analyticsEnabled) { _, on in
                container.analytics.setCollectionEnabled(on)
            }
```

- [ ] **Step 3: Build, verify green; launch sim and confirm the toggle flips collection** (Console tracker prints `collection_enabled=false/true`). Run the Build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add InspireCreativityApp InspireCreativityApp.xcodeproj/project.pbxproj
git commit -m "feat(analytics): Settings opt-out toggle (setAnalyticsCollectionEnabled)"
```

---

## Task 8: Privacy manifest + handoff docs

**Files:**
- Modify: `InspireCreativityApp/PrivacyInfo.xcprivacy`
- Create: `docs/analytics-setup.md`

- [ ] **Step 1: Add the analytics data type to `PrivacyInfo.xcprivacy`**

Inside `NSPrivacyCollectedDataTypes`, add (alongside the existing Email/UserID entries):

```xml
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeProductInteraction</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
```

Keep `NSPrivacyTracking` `false` (no ATT). Firebase ships its own SDK-side privacy manifest in the package, so no per-API additions are needed for the SDK itself.

- [ ] **Step 2: Write the handoff doc** — `docs/analytics-setup.md`

Contents: (1) create a Firebase project, add an iOS app with bundle id `com.inspirecreativity`; (2) download `GoogleService-Info.plist` and add it to the `InspireCreativityApp` target (do **not** commit if the repo is public — add to `.gitignore`); (3) link a GA4 property; (4) App Store Connect → App Privacy → declare **Product Interaction / Identifiers / Usage Data / Diagnostics**, "not used for tracking", "not linked to identity"; (5) verify events in GA4 DebugView (`-FIRAnalyticsDebugEnabled` launch arg) or the Console tracker logs in DEBUG.

- [ ] **Step 3: Build, verify green; commit**

```bash
git add InspireCreativityApp/PrivacyInfo.xcprivacy docs/analytics-setup.md
git commit -m "chore(analytics): privacy manifest analytics data types + setup/handoff doc"
```

- [ ] **Step 4: Final compliance pass** — run the `appstore-submission-expert` agent over the diff to confirm the privacy manifest + nutrition-label plan are submission-safe before shipping a build.

---

## Self-review notes (coverage vs spec)

- §2 dependency/init → Task 6. §3 abstraction → Tasks 1–2. §4 screen nuance → Task 5. §5 opt-out → Task 7. §6 privacy → Task 8. §7 instrumentation map → Tasks 4–5. §8 testing → Tasks 1, 4. §9 prerequisite → Task 8 handoff doc.
- Type consistency: `AnalyticsTracking.log(_:)/track(screen:)/setCollectionEnabled(_:)`, `AnalyticsEvent` cases, and `AnalyticsScreen` raw values are used identically across tasks.
- Known sequencing risk: Task 3 introduces the `analytics` dependency that Task 4 consumes; implement/commit them together (noted in Task 3 Step 4) so each commit builds green.
