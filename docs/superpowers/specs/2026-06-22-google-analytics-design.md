# Spec — Google Analytics (Firebase) for InspireCreativity

- **Status:** Draft for review
- **Date:** 2026-06-22
- **Scope:** Add Google Analytics (Firebase Analytics / GA4) to the iOS app, behind a swappable abstraction, on-by-default with a Settings opt-out, instrumenting auto events + ~10 curated product events. Plan only → implementation plan follows.

---

## 1. Goal & decisions (locked in brainstorming)

| Decision | Choice |
|---|---|
| Provider | **Firebase Analytics SDK** (Google Analytics for Firebase / GA4) — the iOS-native "Google Analytics". Wrapped behind our own `AnalyticsTracking` protocol. |
| Privacy posture | **On by default + Settings opt-out.** No IDFA / cross-app tracking → **no ATT prompt.** |
| Event scope | **Auto events + ~10 curated product events.** |
| Out of scope | Crashlytics, Performance Monitoring, Remote Config, web GA/gtag (not applicable to a native app). |

## 2. Dependency & initialization

- Add Firebase iOS SDK via **SPM** (`https://github.com/firebase/firebase-ios-sdk`), pinning a recent stable major. Link **only the `FirebaseAnalytics` product** to keep binary/build footprint minimal.
- Initialize in `InspireCreativityApp.init()`, **guarded** so the project builds/runs without the plist:

```swift
init() {
    if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
        FirebaseApp.configure()
    }
}
```
Without the plist, the app uses the no-op tracker — CI, previews, and contributors are unaffected. (AppDelegate via `UIApplicationDelegateAdaptor` is a viable alternative if we later add push/Crashlytics; App.init is sufficient now.)

## 3. The abstraction (core — keeps Firebase swappable & testable)

`Analytics/` group, SwiftUI/Foundation only at the call sites (Firebase import isolated to the one tracker file).

```swift
protocol AnalyticsTracking {
    func log(_ event: AnalyticsEvent)
    func track(screen: AnalyticsScreen)
    func setCollectionEnabled(_ on: Bool)
}

enum AnalyticsScreen: String {        // GA4 screen_name
    case discover, browse, detail, paywall, settings, samples, library
}

enum AnalyticsEvent {
    case animationView(id: String, category: String, isPro: Bool)
    case codeCopied(id: String)
    case favoriteToggled(id: String, on: Bool)
    case search(termLength: Int)          // length only — never the raw query (no PII)
    case categorySelected(String)
    case paywallViewed(source: String)
    case purchaseCompleted(productID: String)
    case signIn(method: String)           // "apple" | "google"
    case auroraPromoTap

    var name: String { … }                // snake_case, ≤40 chars, no reserved ga_/firebase_/google_ prefix
    var parameters: [String: Any] { … }    // values ≤100 chars; no PII
}
```

**Implementations**
- `FirebaseAnalyticsTracker` — wraps `Analytics.logEvent(_:parameters:)`, screen via `AnalyticsEventScreenView` + `AnalyticsParameterScreenName`, and `Analytics.setAnalyticsCollectionEnabled(_:)`. The **only** file importing `FirebaseAnalytics`.
- `NoOpAnalyticsTracker` — tests, previews, and when the plist is absent.
- `ConsoleAnalyticsTracker` — `#if DEBUG` echo for local verification.

**Injection** — `AppContainer` builds the tracker once (`Firebase…` when configured, else `NoOp…`) and passes it into the existing VM factories, exactly like the repositories. VMs depend on `AnalyticsTracking`, never on Firebase.

## 4. Screen tracking nuance

`RootView` keeps all tabs mounted in an opacity `ZStack`, so `onAppear` fires once at launch, never on tab switch (BrowseView already documents this). Therefore `track(screen:)` is driven by **tab-selection change** (in the tab container / `AppRouter`) and **router pushes** (Detail, Paywall) — not `onAppear`.

## 5. Opt-out (Settings)

- `@AppStorage("analyticsEnabled")` (default `true`), read at startup to set initial collection state.
- A `Toggle` in `SettingsView` ("Share anonymous usage analytics") → `analytics.setCollectionEnabled(newValue)`. Lives in a new lightweight Privacy row within `aboutSection` (or a small `privacySection`).

## 6. Privacy / App Store compliance

- Update the existing `InspireCreativityApp/PrivacyInfo.xcprivacy`:
  - `NSPrivacyCollectedDataTypes`: Product Interaction, Device ID, Usage Data, Diagnostics — each `Linked = false`, `Tracking = false`.
  - `NSPrivacyAccessedAPITypes`: keep current required-reason entries; Firebase ships its own SDK-side manifest (bundled in the package), so app-level entries only cover our own usage (e.g. `UserDefaults` reason `CA92.1`).
- **No ATT** (no IDFA, not used for tracking) → no `NSUserTrackingUsageDescription`, no prompt.
- App Store Connect **nutrition labels** updated at submission to match. Final compliance pass with the `appstore-submission-expert` agent before shipping a build.

## 7. Instrumentation map

| Event | Fires from |
|---|---|
| `screen_view` | tab-selection change + `AppRouter` push (Detail, Paywall) |
| `animationView` | `DetailViewModel` (on open) |
| `codeCopied` | `CodeSheet` copy action |
| `favoriteToggled` | `DetailViewModel.toggleFavorite` (+ Library) |
| `search` | `BrowseViewModel` (debounced; non-empty → term length) |
| `categorySelected` | `BrowseViewModel.selectedCategory` change + Discover category drill |
| `paywallViewed` | `PaywallView` appear (source: detail/settings/promo) |
| `purchaseCompleted` | `StoreManager` purchase success |
| `signIn` | `AuthStore` sign-in success (method) |
| `auroraPromoTap` | `AuroraPackPromoCard` tap |

## 8. Testing

- Unit-test `AnalyticsEvent.name`/`parameters`: GA4-valid names (snake_case, ≤40 chars, no reserved prefix), param values ≤100 chars, and **no PII** (search carries `term_length`, never the query).
- `SpyAnalyticsTracker` (records calls) injected into VMs to assert the right events fire (e.g. toggling a favorite emits `favoriteToggled(on:)`).
- `NoOpAnalyticsTracker` is the default in tests/previews.
- **Build green with AND without `GoogleService-Info.plist`.** Existing test suite stays green.

## 9. Prerequisite (user-provided)

A Firebase project + `GoogleService-Info.plist` for bundle id `com.inspirecreativity`, with a linked GA4 property. Google-side assets can't be created from here. Everything else (SPM wiring, abstraction, instrumentation, privacy manifest, Settings toggle, tests) is implementable now and builds green via the guarded `configure()` (no-op until the plist is added to the target).

## 10. Implementation phases (for the plan)

1. **Scaffold + DI:** add Firebase SPM (FirebaseAnalytics), `AnalyticsTracking` protocol + event/screen enums + NoOp/Console/Firebase trackers, guarded `configure()`, inject via `AppContainer`. Build green (no-op path).
2. **Instrument:** wire the 10 events + screen tracking at the sites in §7.
3. **Opt-out + privacy:** Settings toggle + `PrivacyInfo.xcprivacy` update.
4. **Tests:** event-mapping unit tests + Spy-based VM tests.
5. **Handoff:** document the GoogleService-Info.plist step + nutrition-label checklist; appstore-submission-expert review.
