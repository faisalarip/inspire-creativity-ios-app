# InspireCreativity — macOS App Design Spec

- **Date:** 2026-06-27
- **Status:** Approved design (pre-implementation). Next step: implementation plan via `writing-plans`.
- **Author:** Brainstormed with Claude Code; grounded in a 5-survey / 33-claim adversarially-verified research workflow over the live repo.

## 1. Goal & thesis

Ship a **macOS version** of InspireCreativity whose single reason to exist is to make copying generated SwiftUI animation code **directly into Xcode frictionless** — on the same Mac where the developer already runs Xcode. The iOS app hides code behind a drag-up sheet sized for a thumb; the Mac app makes code a **first-class, always-visible, selectable, draggable** artifact. The Mac strengthens the existing monetization because code egress (copy / export / drag-out) is exactly where the paid value is realized, and that is the natural Mac gate.

Non-goals for v1: a redesigned catalog, new animation content, sync/accounts beyond what iOS already has, or any web/non-App-Store commerce.

## 2. Confirmed decisions (founder)

| Decision | Choice |
|---|---|
| Mac UI technology | **SwiftUI multiplatform** — single target, add a My Mac destination, branch the shell + ~7 spots with `#if` |
| v1 scope | **MVP + native polish** — split-view shell, preview∥code, copy/Save/.swift, drag-out (Tier 1), menu commands + shortcuts, multi-window, Universal Purchase |
| Pricing on Mac | **Universal Purchase** — existing `pro.lifetime` unlocks Mac free for current owners; no new IAP |
| Rollout | **Dry-run** the platform-add + cross-platform unlock on a non-production ASC record first, then commit on production |

## 3. Verified ground truth (from the research workflow)

- **The codebase is ~99% portable.** Pure SwiftUI `App` lifecycle (no `AppDelegate`/`UIApplicationDelegateAdaptor`). Domain models, repositories, `StoreManager`, `AuthStore`/Supabase REST, `AuroraCodeGen` + `ParametricAuroraPreview` + `AnimationPreviewRegistry`, and all 10 Metal effects (they use SwiftUI `ShaderLibrary` + `.colorEffect`/`.layerEffect`/`.distortionEffect`, **not** raw `MTKView`/`CIFilter`) compile and run on macOS 14 unchanged. `.sensoryFeedback` (101 sites) is a silent no-op on Mac at deployment target ≥ 14.
- **Bundle id is `com.inspirecreativity`** (`project.pbxproj` app target, Debug + Release). The `com.faisalarip.InspireCreativityApp` string is only the StoreKit **product-id namespace** (free-form, harmless) and the **test target** id. Universal Purchase requires the Mac build to ship under the same `com.inspirecreativity` as the live ASC record — to be confirmed in ASC before the platform-add.
- **4 hard compile blockers on native macOS** (must be resolved):
  1. `.toolbar(.hidden, for: .navigationBar)` at **6 sites** — `RootView.swift:102/105/108`, `SettingsView.swift:59`, `DiscoverView.swift:558`, `DetailView.swift:171`. `ToolbarPlacement.navigationBar` is `@available(macOS, unavailable)`. Must `#if os(iOS)`-guard (the Mac shell does not use these).
  2. No macOS destination exists yet (`SDKROOT=iphoneos`, `TARGETED_DEVICE_FAMILY="1,2"`, no `SUPPORTS_MACCATALYST`/`SUPPORTED_PLATFORMS`).
  3. No App Sandbox entitlement — mandatory for the Mac App Store; without `network.client` every network path (Supabase, StoreKit, Firebase, OAuth) fails at runtime.
  4. Bundle-id reconciliation must precede adding the macOS platform to the existing ASC record.
- **2 real UIKit usages to shim:** `UIPasteboard.general.string` (`CodeSheet.swift:165`) → `NSPasteboard`; `UIFont.systemFont(ofSize:weight:)` (`WeightBreatheView.swift:91`) → `NSFont` (renders equivalently, not pixel-identical). `AuthField`'s `UITextContentType`/`UIKeyboardType` + `.keyboardType`/`.textInputAutocapitalization` (`RootView.swift:610-621`, `SearchView.swift:45`) gated behind `#if os(iOS)`.
- **Egress plumbing already exists** on branch `feat/code-export` (`InspireCreativityApp/Animations/CodeExport.swift` + `CodeExportTests.swift`): `SwiftSnippet: Transferable` with `FileRepresentation(exportedContentType: .swiftSource)` + plain-text `ProxyRepresentation` fallback; `SwiftSource.bodyWithoutImports`; a deep-link scheme. Cross-platform via `CoreTransferable`. The Mac app **adopts** this rather than rebuilding it.
- **`SwiftCodeView`** (`Features/Detail/SwiftCodeView.swift`) is pure-SwiftUI, syntax-highlighted, cross-platform — but composed `Text` is **not selectable**; add `.textSelection(.enabled)` for Mac.
- **StoreKit cross-platform caveat:** `StoreManager` calls `refreshEntitlements()` without a preceding `AppStore.sync()`, so a fresh Mac install signed into the buyer's Apple ID may show `isPro = false` on cold launch until a Restore or a `Transaction.updates` delivery.
- **Google OAuth anchor:** supabase-swift auto-supplies an anchor (it will not throw/hang), but it is a bare detached `NSWindow`; supply a real key `NSWindow` via `signInWithOAuth(configure:)` for reliable presentation on sandboxed macOS.
- **Universal Purchase is irreversible** once App Review approves the 2nd platform — a platform version can never be removed.

## 4. Architecture

### 4.1 Target & code sharing
Keep the single app target; add **My Mac (Supported Destinations)**. `MACOSX_DEPLOYMENT_TARGET = 14.0`, bundle id `com.inspirecreativity`. All sources shared; platform differences expressed with `#if os(macOS)` / `#if canImport(UIKit)`. No Swift-package extraction in v1 (the door stays open: cross-platform sources can be lifted into a package later without re-platforming).

### 4.2 Layer map
- **Reused unchanged (no `#if`):** `Models/*`, `Repositories/*`, `Store/StoreManager`, `Auth/*` + `AuthStore`, `Animations/AuroraCodeGen` + `AnimationPreviewRegistry` + `ParametricAuroraPreview`, all Metal effect views, the feature **view models** (`DiscoverViewModel`, `BrowseViewModel`, `LibraryViewModel`, `DetailViewModel`).
- **iOS shell (kept, `#if os(iOS)` where needed):** `RootView` (`FloatingTabBar` + per-tab `NavigationStack`s), `AppRouter`, `CodeSheet` drag-up, `AuthField` keyboard modifiers.
- **New Mac shell (`#if os(macOS)`):** `MacRootView` (NavigationSplitView), a selection-based Mac router, `MacDetailView` (preview∥code split), `.commands` menus, multi-window scene.

### 4.3 Mac navigation shell
A **3-column `NavigationSplitView`**:
- **Sidebar** — Discover, Browse-by-category (from `repository.categories()`), Library (Owned / Favorites / Recent). Selection-driven.
- **Content** — grid/list for the current selection with a **search field pinned at top** (reuses `BrowseViewModel` filtering + the load-more paging already added).
- **Detail** — `MacDetailView` (below).

The Mac router is selection state (`@Published var selectedSection`, `selectedItemID`), not push-paths. iOS `AppRouter` is untouched. Discover's category drill-down maps to selecting the sidebar category.

### 4.4 Detail surface — preview ∥ code (the thesis)
`MacDetailView` is a resizable **`HSplitView`**:
- **Left:** live preview via `AnimationPreviewRegistry.interactiveView(for:)`, resizable (drop the iOS ~42% height clamp at `DetailView.swift:67`). The "Tap & drag to interact" hint (already built) carries over for interactive (bespoke) previews, reworded for pointer.
- **Right:** `SwiftCodeView` with `.textSelection(.enabled)`, line numbers, and an action bar: Copy, Copy without imports, Save .swift, drag handle.
- **Gate:** code reveal uses the existing `CodeAccess.evaluate(itemIsPro:hasProEntitlement:isAuthenticated:)` — unchanged. Locked state shows the same Pro/sign-in CTAs, routed to the Mac paywall/auth.

### 4.5 Code egress
Adopt `CodeExport.swift` from `feat/code-export` (merge/rebase into the work branch). Wire on the code pane:
- **Copy** → `NSPasteboard` via a small cross-platform `Clipboard` helper (or route through `CodeExport`).
- **Copy without imports** → `SwiftSource.bodyWithoutImports`.
- **Save As `.swift`** → `.fileExporter` writing `viewModel.code` to a CamelCased filename (needs `files.user-selected.read-write`).
- **Drag `.swift` out** → `.draggable(SwiftSnippet(displayName:source:))` → Finder/Xcode (**Tier 1**, reliable; a temp-file write in the app's sandbox temp dir is expected and fine).
- **ShareLink** → AirDrop/Mail.

### 4.6 Mac-native chrome
- **`.commands`:** Copy Code (⌘C), Save .swift (⌘S), New Window (⌘N), Open in New Window, Find (⌘F → focus search), Restore Purchases.
- **Keyboard-first:** arrow-key navigation through sidebar/content; ⌘F focuses search.
- **Multi-window:** `WindowGroup(for: AnimationItem.ID)` + `openWindow`; "Open in New Window" command. `DetailViewModel` is already id-driven and self-contained.

### 4.7 Auth & StoreKit on Mac
- **Sign in with Apple:** `SignInWithAppleButton` works (AuthenticationServices, macOS 11+); SwiftUI supplies its own anchor.
- **Google OAuth:** supply a real key `NSWindow` anchor via `signInWithOAuth(configure:)`; requires `network.client`. The custom URL scheme is vestigial for this flow (ASWebAuthenticationSession captures `inspirecreativity://auth-callback` internally) — no `onOpenURL` wiring needed unless deep-linking is added.
- **StoreKit / Universal Purchase:** `StoreManager` logic unchanged. **Add `AppStore.sync()` on Mac first-launch** (or surface a prominent Restore) so the cross-platform entitlement surfaces on cold start. Expose Restore Purchases in the menu and Settings.

### 4.8 Entitlements
Add `com.apple.security.app-sandbox`, `com.apple.security.network.client`, and `com.apple.security.files.user-selected.read-write` (for Save). Keep the existing `applesignin`.

## 5. Monetization rollout
Reuse `pro.lifetime` via Universal Purchase; the gate stays at code egress + the existing `CodeAccess`. Rollout order:
1. Confirm the **live ASC record's bundle id is `com.inspirecreativity`** (reconcile project↔record if not).
2. **Dry-run** the platform-add + cross-platform unlock mechanics on a **non-production** ASC record.
3. Verify `isPro` unlock on a **signed, sandboxed Mac build** with a **true sandbox Apple ID** that bought on iOS (a local `.storekit` file cannot test real cross-platform sharing).
4. Only then add macOS to the production record (irreversible).

## 6. Out of scope for v1 (YAGNI)
- MenuBarExtra quick-access (low value first; lifecycle quirks).
- Drop-into-Xcode-Project-Navigator (**Tier 2**) — version-dependent; ship Tier 1, treat Tier 2 as a later empirical spike.
- Quick Look (the in-app live preview already exceeds a static QL render).
- Elaborate preview frame presets — a simple resizable preview ships; presets are a v1.1 candidate.
- Deep-linking on Mac (`inspirecreativity://animation/<id>`) — plumbing exists in `CodeExport`; defer `onOpenURL` wiring to post-MVP.

## 7. Testing & verification
- **Automated:** reuse existing unit tests; bring in `CodeExportTests`. Keep the test target iOS-scoped initially (it's `com.faisalarip.InspireCreativityAppTests`).
- **On-Mac manual checklist (non-skippable, requires real Mac hardware):**
  - StoreKit cross-platform unlock with a true sandbox Apple ID (buy on iOS → launch Mac → `isPro` flips true, after `AppStore.sync()`/Restore).
  - Google OAuth window actually presents and the callback returns.
  - All 10 Metal shaders render correctly (Apple Silicon; ideally Intel too).
  - Gesture-driven catalog items under a pointer (~13 use Magnify/Rotation needing a trackpad; ~16 read `DragGesture` velocity). Accept trackpad-only, add pointer affordances, or down-rank in the Mac catalog. Check `JellyWobbleView`'s `DragGesture.Value.velocity` compiles against the macOS 14 SDK.
  - Dark scheme + `.ultraThinMaterial` in **active and inactive** windows.
  - All ⌘-shortcuts and keyboard navigation.
- **CI:** add the macOS destination to the existing Xcode Cloud lane (ties into the CI/CD foundation work).

## 8. Phasing (~3–5 focused weeks, solo)
- **P0 — Build green on Mac:** add the My Mac destination + entitlements; `#if os(iOS)` the 6 toolbar sites; shim `UIPasteboard`/`UIFont`; gate `AuthField`. Clean macOS build.
- **P1 — Shell + detail:** `NavigationSplitView` 3-column shell; `MacDetailView` preview∥code split with selectable `SwiftCodeView`; Copy + Save .swift.
- **P2 — Egress + native chrome:** adopt `CodeExport`; drag-out Tier 1; `.commands` + keyboard shortcuts; multi-window.
- **P3 — Auth/Store hardening + monetization:** Google OAuth key-window anchor; `AppStore.sync()` on first launch; monetization dry-run on a test ASC record.
- **P4 — Verify & submit:** full on-Mac verification checklist; add macOS to the production record; submit.

## 9. Risks (highest first)
| Risk | Severity | Mitigation |
|---|---|---|
| ASC record bundle id ≠ `com.inspirecreativity` → Universal Purchase can't attach | High | Confirm in ASC before any porting; reconcile project↔record first |
| Universal Purchase is irreversible | Medium | Dry-run on a non-production record before committing on production |
| Google OAuth window doesn't present on sandboxed Mac | Medium | Supply a real key `NSWindow` via `configure:`; verify on hardware; ensure `network.client` |
| Cross-platform unlock doesn't fire on cold launch | Medium | `AppStore.sync()` / prominent Restore on Mac first launch; verify with sandbox Apple ID |
| Gesture/multi-finger catalog items degrade under pointer | Medium | Verify each on Mac; accept trackpad-only, add affordances, or down-rank |
| Dark + `.ultraThinMaterial` washed-out in inactive windows | Low | Visually verify active+inactive states before declaring the design system reused |
| Metal shaders differ subtly across GPUs | Low | Per-effect visual smoke test on real Mac hardware |
