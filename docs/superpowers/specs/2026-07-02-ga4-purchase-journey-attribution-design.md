# GA4 Purchase‑Journey Attribution — Design Spec

- **Date:** 2026-07-02
- **Status:** Approved design
- **Branch:** `feat/macos-app`
- **Platforms:** iOS 17+ and macOS 14+ (single multiplatform target — every change lands on both)

## 1. Problem & goal

See **which in‑app journey steps most contribute to in‑app purchase**. Today Firebase GA4 records the purchase and the paywall `source`, but not the *intent* moments preceding a sale, and sets no user properties — so GA4 can neither reconstruct the path to purchase nor compare converters against non‑converters. This feature instruments the missing funnel steps and adds segmentation dimensions, entirely within the existing Firebase/GA4 stack.

## 2. Locked decisions

| Decision | Choice | Consequence |
|---|---|---|
| Attribution scope | **In‑app behavioral journey** | No SKAdNetwork / ATT / AdServices / marketing attribution. No privacy‑prompt friction. |
| Data destination | **Extend GA4 (Firebase) only** | No Supabase event pipeline; analysis in GA4 Explorations (+ optional BigQuery export). |
| Identity | **Device‑scoped + user properties** | Rely on GA4's automatic per‑install app‑instance ID; **no `setUserID`**. iOS and Mac are separate users. |
| JourneyMetrics counter | **Included** | Enables engagement‑depth + time‑to‑purchase attribution signals. |
| v1 thoroughness | **Full design** | All events, enriched purchase, user properties, iOS+Mac parity, GA4 docs, tests. |

## 3. Current state (verified in code)

- **Analytics module** (`InspireCreativityApp/Analytics/`): `AnalyticsTracking` protocol (`log(_:)`, `track(screen:)`, `setCollectionEnabled(_:)`) with three backends — `FirebaseAnalyticsTracker` (GA4, only file importing Firebase, `#if canImport(FirebaseAnalytics)`), `ConsoleAnalyticsTracker` (DEBUG), `NoOpAnalyticsTracker` (release/tests). Composed in `AppContainer`.
- **Events today** (`AnalyticsEvent.swift`, 9): `animation_view`, `code_copied`, `favorite_toggled`, `search` (term *length* only), `category_selected`, `paywall_viewed(source)`, `purchase_completed(product_id, source)`, `sign_in(method)`, `aurora_promo_tap`. GA4 rules enforced: snake_case, name ≤40, string values ≤100, no `ga_`/`firebase_`/`google_` prefix, no PII. `AnalyticsEvent` is `Equatable`.
- **Screens** (`AnalyticsScreen.swift`, 7): `discover, browse, detail, paywall, settings, samples, library`. Tracked in `AppRouter:89` and `RootView:85/88`.
- **Consent** (`AnalyticsConsent.swift`): EEA/UK → collection only when `.granted`; non‑EEA → `analyticsEnabled` toggle. Enforced globally via `Analytics.setAnalyticsCollectionEnabled` (`AppContainer:49`, `AnalyticsConsentPrompt:84`, `SettingsView:178`). Any new event/property auto‑respects consent.
- **IAP** (`Store/StoreManager.swift`): StoreKit 2, single non‑consumable `com.faisalarip.InspireCreativityApp.pro.lifetime`. `enum PurchaseOutcome { success, pending, cancelled }`; `func purchase(_:) async throws -> PurchaseOutcome` maps StoreKit `.success/.pending/.userCancelled`; `enum StoreError { failedVerification, productsUnavailable }`; `@Published justPurchased`; `isProPublisher: AnyPublisher<Bool, Never>`; `ProductID.lifetime`.
- **Purchase gate** (`DetailViewModel.swift` → `CodeAccess.evaluate(itemIsPro:hasProEntitlement:isAuthenticated:)`): Pro entitlement → `.granted` in any auth state; Pro item → `.needsPro`; free item → `.needsSignIn` (signed out) / `.granted` (signed in). **Purchasing never requires an account.**
- **"50 free animations" is catalog composition, not a quota** (`freeCount = allItems.filter(\.isFree).count`). The purchase trigger is the **Pro lock**, not exhausting a free allowance.
- **Paywall entry points (`source`), 5:** `detail`, `library`, `settings`, `promo`, `mac`.

## 4. Target funnel (analyzable in GA4)

```
first_open → session_start                                   (GA4 auto)
  → screen_view (discover / browse)                          [exists]
  → animation_view                                           [exists]
  → code_unlock_attempt (result = needs_pro)   ★ NEW         the missing intent signal
  → paywall_viewed (source)                                  [exists]
  → purchase_initiated (source)                  NEW
  → purchase_completed (enriched)                [exists — Key Event] ✅
     drop‑offs: paywall_dismissed · purchase_cancelled · purchase_failed   NEW
```

- **Funnel Exploration** → step‑by‑step conversion/drop‑off.
- **Path Exploration** backward from `purchase_completed` → journeys that converge on a sale.
- **Segment comparison** via user properties → converters vs. non‑converters.

## 5. Components & interfaces

Pure/derivable logic (event mapping, bucketing) is separated from side‑effecting wiring (Firebase, DI observers) so each unit is independently unit‑testable.

### 5.1 `AnalyticsEvent` additions (`Analytics/AnalyticsEvent.swift`)

New cases (associated values → GA4 params via the existing `parameters` computed property). Keep the enum `Equatable`.

- `codeUnlockAttempt(result: String, animationID: String, category: String, isPro: Bool)` — `result` ∈ `needs_pro` | `needs_sign_in`
- `purchaseInitiated(productID: String, source: String)`
- `purchaseCancelled(productID: String, source: String, reason: String)` — `reason` ∈ `user_cancelled` | `pending`
- `purchaseFailed(productID: String, source: String, reason: String)` — `reason` ∈ `verification_failed` | `error`
- `paywallDismissed(source: String, secondsBucket: String)`
- `restoreCompleted(source: String)`
- **Enrich existing** `purchaseCompleted` → `purchaseCompleted(productID: String, source: String, context: PurchaseContext)`, where `PurchaseContext: Equatable { hitProLock: Bool; animationsViewedBucket: String; timeToPurchaseBucket: String; signedIn: Bool }` flattens into params (`hit_pro_lock`, `animations_viewed_bucket`, `time_to_purchase_bucket`, `signed_in`).

### 5.2 `AnalyticsUserProperty` (new) + protocol method

`Analytics/AnalyticsUserProperty.swift` mirrors the `AnalyticsEvent` pattern — `name` (≤24) + `value: String?` (≤36):

- `.isPro(Bool)` → `is_pro`; `.signedIn(Bool)` → `signed_in`; `.platform(String)` → `platform` (`ios`|`macos`); `.engagementLevel(String)` → `engagement_level`; `.animationsViewedBucket(String)` → `animations_viewed_bucket`.

`AnalyticsTracking` gains: `func set(_ property: AnalyticsUserProperty)`.

### 5.3 Backend implementations

- `FirebaseAnalyticsTracker.set(_:)` → `Analytics.setUserProperty(property.value, forName: property.name)` (inside `#if canImport`).
- `ConsoleAnalyticsTracker.set(_:)` → print. `NoOpAnalyticsTracker.set(_:)` → no‑op.
- No `setUserID` anywhere.

### 5.4 `JourneyMetrics` (new, `Analytics/JourneyMetrics.swift`)

Cross‑platform, **device‑local** counters; `ObservableObject`; no network, no PII, no `#if os()`.

- **Injected:** `UserDefaults` (tests inject a suite) + `now: () -> Date` clock.
- **Persisted (`journey.` keys):** `firstOpenDate: Date` (set once), `animationsViewedCount`, `searchesCount`, `favoritesCount`, `codeUnlockAttempts`, `proLocksHit`.
- **Recording API:** `recordAnimationView()`, `recordSearch()`, `recordFavorite()`, `recordCodeUnlockAttempt(result: CodeAccess)` (increments `proLocksHit` on `.needsPro`).
- **Derived (pure):** `animationsViewedBucket` ∈ `0`/`1_3`/`4_10`/`11_30`/`31_plus`; `engagementLevel` ∈ `new`(0)/`browser`(1–3)/`engaged`(4–15)/`power`(16+); `timeToPurchaseBucket(now)` from `now − firstOpenDate` ∈ `lt_1h`/`1_24h`/`1_7d`/`7_30d`/`gt_30d`; `hitProLock = proLocksHit > 0`.
- **`snapshotForPurchase(signedIn:) -> PurchaseContext`**.
- **Consent:** recording is device‑local state (not "collection"), so it always runs; transmission of derived values is gated at the Firebase layer. No extra consent logic here.
- Counters are **lifetime** (not reset on purchase).

### 5.5 User‑property wiring (`App/AppContainer.swift`)

`AppContainer` owns `analytics` (44), `store: StoreManager` (57), `authStore: AuthStore` (62); `store.isProPublisher` (StoreManager:54) and `authStore.$session` (AuthStore:768) are the reactive sources.

- On init: `set(.platform(ios|macos))`, `.isPro(store.isPro)`, `.signedIn(authStore.isAuthenticated)`, `.engagementLevel(...)`, `.animationsViewedBucket(...)`.
- Subscribe `store.isProPublisher` → `set(.isPro(...))`.
- Subscribe `authStore.$session` → `set(.signedIn(session != nil))`.
- Subscribe `JourneyMetrics` (objectWillChange / @Published) → refresh `engagement_level` + `animations_viewed_bucket`.
- Inject `journeyMetrics` into `makeDetailViewModel`/`makeBrowseViewModel`/`makePaywallViewModel`; pass a `signedIn: { [authStore] in authStore.isAuthenticated }` closure into the paywall VM.

### 5.6 Call‑site instrumentation (iOS + macOS parity)

| Moment | Site (verified) | Action |
|---|---|---|
| Animation detail opened | `DetailViewModel:75` (`animation_view`) | + `journeyMetrics.recordAnimationView()` |
| Code unlock CTA tapped | `DetailView:137–143` `onUnlock` switch; Mac `MacDetailPane` unlock action (~430–439) | `log(.codeUnlockAttempt(result, animationID, category, isPro))` + `journeyMetrics.recordCodeUnlockAttempt(access)` for `.needsPro`/`.needsSignIn` |
| Buy tapped | `PaywallViewModel.purchaseSelected()` after product guard (~102) | `log(.purchaseInitiated(product.id, source))` before `store.purchase` |
| Purchase success | `PaywallViewModel:106 .success` | `log(.purchaseCompleted(product.id, source, context: journeyMetrics.snapshotForPurchase(signedIn:)))` |
| Purchase not completed | `PaywallViewModel:109 .pending` / `:111 .cancelled` | `.pending` → `log(.purchaseCancelled(_, source, "pending"))`; `.cancelled` → `log(.purchaseCancelled(_, source, "user_cancelled"))` |
| Purchase error | `PaywallViewModel:114 catch` | `log(.purchaseFailed(_, source, reason))` — `StoreError.failedVerification` → `verification_failed`, else `error` |
| Paywall dismissed w/o purchase | `PaywallView` dismiss + guard `!didComplete` | `log(.paywallDismissed(source, secondsBucket))` (VM stamps appear time) |
| Restore success | `PaywallViewModel:125` (`store.isPro`) | `log(.restoreCompleted(source))` |
| Search performed | `BrowseViewModel:72` | + `journeyMetrics.recordSearch()` |
| Favorite turned on | `DetailViewModel:104` | + `journeyMetrics.recordFavorite()` when `on == true` |
| Screen shown on Mac | `MacShellV2` views | add `track(screen:)` parity if missing |

`secondsBucket` (paywall dwell): `lt_5s` / `5_15s` / `15_60s` / `gt_60s`.

## 6. Event & parameter reference

| Event (GA4) | Params |
|---|---|
| `code_unlock_attempt` | `result` (needs_pro/needs_sign_in), `animation_id`, `category`, `is_pro` |
| `purchase_initiated` | `product_id`, `source` |
| `purchase_cancelled` | `product_id`, `source`, `reason` (user_cancelled/pending) |
| `purchase_failed` | `product_id`, `source`, `reason` (verification_failed/error) |
| `paywall_dismissed` | `source`, `seconds_bucket` |
| `restore_completed` | `source` |
| `purchase_completed` (enriched) | `product_id`, `source`, `hit_pro_lock`, `animations_viewed_bucket`, `time_to_purchase_bucket`, `signed_in` — Key Event |

Names ≤40, snake_case, no reserved prefix; string values ≤100; no PII (`animation_id`/`category` are content ids).

## 7. User‑property reference

| Property | Values |
|---|---|
| `is_pro` | `true`/`false` |
| `signed_in` | `true`/`false` |
| `platform` | `ios`/`macos` |
| `engagement_level` | `new`/`browser`/`engaged`/`power` |
| `animations_viewed_bucket` | `0`/`1_3`/`4_10`/`11_30`/`31_plus` |

Names ≤24, values ≤36, no PII. 5 of GA4's 25‑property budget.

## 8. Privacy & consent

- New events/properties carry no PII (continues the existing rule).
- All transmission gated by `setAnalyticsCollectionEnabled`; denied → nothing sends.
- `JourneyMetrics` stores only aggregate device‑local counters (not shared).
- **Confirm:** existing `PrivacyInfo.xcprivacy` "Product Interaction" declaration still covers the new params (no new data *category* is introduced — expected: yes).

## 9. GA4 console setup (docs) — update `docs/analytics-setup.md`

- Register **event‑scoped custom dimensions**: `result`, `category`, `is_pro`, `reason`, `source`, `seconds_bucket`, `hit_pro_lock`, `animations_viewed_bucket`, `time_to_purchase_bucket`. (Do **not** register `animation_id` — high cardinality; stays a queryable param / BigQuery field.)
- Register **user‑property custom dimensions**: `is_pro`, `signed_in`, `platform`, `engagement_level`, `animations_viewed_bucket`.
- Confirm `purchase_completed` is a **Key Event**.
- Pre‑build **Explorations**: (1) Funnel `animation_view → code_unlock_attempt[needs_pro] → paywall_viewed → purchase_initiated → purchase_completed`; (2) Path backward from `purchase_completed`; (3) Segment overlap buyers × `engagement_level`; (4) conversion rate by paywall `source`.
- **Optional:** enable the free **BigQuery export** for raw SQL path analysis.
- Keep existing DebugView verification steps.

## 10. Testing plan

Follow existing conventions; extend the recorder.

- **`SpyAnalyticsTracker`** (`Tests/Support/`): add `private(set) var userProperties: [(name: String, value: String?)]` + `set(_:)` recording.
- **`AnalyticsEventTests`:** add every new case to the GA4‑validity sweep; assert each `parameters` map; assert `PurchaseContext` flattening; keep `Equatable` coverage.
- **New `AnalyticsUserPropertyTests`:** name ≤24, value ≤36, correct mapping.
- **New `JourneyMetricsTests`:** bucket boundaries (0/1/3/4/10/11/30/31 views; 15/16 engagement), `timeToPurchaseBucket` via injected clock across all boundaries, `snapshotForPurchase`, persistence via `UserDefaults(suiteName:)`, `recordCodeUnlockAttempt(.needsPro)` increments `proLocksHit`.
- **`AnalyticsInstrumentationTests`:** add `code_unlock_attempt` (needs_pro/needs_sign_in), `purchase_initiated`/`cancelled`/`failed`, `paywall_dismissed`, and JourneyMetrics recording on the relevant VMs, using the spy pattern (`StoreManager()` + spy).

## 11. Platform parity

Everything flows through the shared `AnalyticsTracking` DI and shared VMs, so iOS + macOS get identical instrumentation. Platform‑specific work: ensure `MacShellV2` fires `code_unlock_attempt`, animation‑view recording, and `track(screen:)` at parity with the iOS `DetailView`/`RootView` paths. `platform` user property separates them in reports.

## 12. Out of scope (YAGNI)

Marketing/install attribution (SKAdNetwork/ATT/AdServices/deep‑link/UTM); `setUserID`/cross‑device stitching; Supabase analytics pipeline; server‑side receipt validation. All additive later without reworking this design.

## 13. Rollout & verification

1. Unit tests green. 2. Build + run iOS and macOS. 3. GA4 **DebugView**: exercise browse → Pro lock → paywall → (cancel) → (buy); confirm each new event, its params, the 5 user properties, and the enriched `purchase_completed`. 4. Confirm consent OFF suppresses all of it.

## 14. Verified ground truth (call sites)

All confirmed by reading the code (2026-07-02):

- `StoreManager`: `PurchaseOutcome {success,pending,cancelled}`; `purchase() async throws -> PurchaseOutcome`; `StoreError {failedVerification,productsUnavailable}`; `isProPublisher`; `justPurchased`; `ProductID.lifetime`.
- `PaywallViewModel.purchaseSelected()` switch at 105–113; `restore()` checks `store.isPro` at 125; `@Published didComplete`; has `source`; **needs** new `journeyMetrics` + `signedIn` closure deps.
- `DetailView` `onUnlock` switch at 137–143; `DetailViewModel` logs `animation_view:75`, `favorite_toggled:104`; `BrowseViewModel` logs `search:72`.
- `AppContainer`: `analytics:44`, `store:57`, `authStore:62`, factories `makeDetailViewModel:146`, `makeBrowseViewModel:130`, `makePaywallViewModel:156`.
- `AuthStore`: `@Published private(set) var session:768`, `isAuthenticated:791`.
- Tests: `SpyAnalyticsTracker` records `events`/`screens`/`collectionEnabledCalls`; `AnalyticsEventTests` enforces GA4 constraints; `AnalyticsInstrumentationTests` drives VMs with the spy; isolated `UserDefaults(suiteName:)` pattern available.
- **To confirm during build:** exact `MacDetailPane` unlock closure; `PrivacyInfo.xcprivacy` coverage.
