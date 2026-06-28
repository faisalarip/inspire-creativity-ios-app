# macOS Production Pass — Auth, Paywall, Settings, Submission Config & Compliance

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the macOS app functionally complete and submission-grade: real sign-in (Apple/Google/email), a working paywall and Restore, a Settings/account surface, the Mac-specific technical fixes, App Store submission config, and the analytics/privacy compliance corrections (incl. an EEA/UK first-run consent gate).

**Architecture:** Reuse the existing cross-platform views (`AuthGateView`, `PaywallView`, `SettingsView`) by making the two router-coupled ones (`PaywallView`, `SettingsView`) router-free, then present them from the macOS shell as sheets. iOS behavior must remain identical. New macOS-only glue lives in `Features/MacShell/` under `#if os(macOS)`.

**Tech Stack:** Swift, SwiftUI, StoreKit 2, supabase-swift, Firebase Analytics, AuthenticationServices. Project `InspireCreativityApp.xcodeproj`, scheme `InspireCreativityApp`, bundle id `com.inspirecreativity`, branch `feat/macos-app`.

## Global Constraints
- Single app target; bundle id `com.inspirecreativity` unchanged.
- **iOS must not regress** — every task verifies the iOS build is green and that touched iOS flows behave as before. Where a shared view is refactored, the iOS code path must be behavior-preserving.
- macOS builds verified with: `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`.
- iOS builds with: `… -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`. Tests: `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17'`.
- New files registered in `project.pbxproj` with unique UUIDs from `uuidgen | tr -d '-' | cut -c1-24`; app sources → app target, test sources → test target. Stage only each task's files; never `git add -A`; never stage `.claude/`.
- Standard file-header block on new files. Commit trailer (every commit):
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01D25kCDftE6ZXUERnKN8fks
  ```
- **Honesty boundary:** this pass makes the *code* submission-grade and verifies builds/tests. It does NOT perform owner-only steps (ASC Universal Purchase platform-add [irreversible], Firebase GA4 console link, signing/notarization certs, app metadata/screenshots) or on-device verification (Google OAuth presenting, cross-platform Pro unlock with a real sandbox Apple ID). Task 9 produces the owner checklist for those.

---

### Task 1: Make PaywallView & SettingsView router-free (iOS-preserving)

**Files:** Modify `Features/Paywall/PaywallView.swift`, `Features/Settings/SettingsView.swift`, `App/RootView.swift` (the two `navigationDestination` call sites).

**Why:** Both hard-depend on `@EnvironmentObject AppRouter` (`router.pop()`, `router.push(.paywall)`), which the macOS shell doesn't provide. `@Environment(\.dismiss)` works for BOTH a NavigationStack push (iOS) and a sheet (macOS), so it's a safe cross-platform replacement for `pop()`.

**Interfaces produced:**
- `PaywallView(viewModel:)` — no longer reads `AppRouter`; dismisses via `\.dismiss`.
- `SettingsView(store:onGoPro:)` — gains `let onGoPro: () -> Void`; back via `\.dismiss`.

- [ ] **Step 1** — In `PaywallView`: remove `@EnvironmentObject private var router: AppRouter`; add `@Environment(\.dismiss) private var dismiss`. Replace both `router.pop()` (the `onChange(of: viewModel.didComplete)` and the `xmark` button) with `dismiss()`. Leave everything else unchanged.
- [ ] **Step 2** — In `SettingsView`: remove `@EnvironmentObject private var router: AppRouter`; add `@Environment(\.dismiss) private var dismiss`. Replace the back `IconButton` `router.pop()` with `dismiss()`. Add `let onGoPro: () -> Void` and replace `router.push(.paywall(source: "settings"))` with `onGoPro()`.
- [ ] **Step 3** — Update the iOS call sites in `RootView.swift`'s `navigationDestination`:
  - `.paywall(let source)`: unchanged construction (PaywallView no longer needs router from env — it still works pushed).
  - `.settings`: `SettingsView(store: container.store, onGoPro: { router.push(.paywall(source: "settings")) })` — preserves the iOS push behavior exactly.
- [ ] **Step 4** — Verify iOS build green AND iOS tests green (`xcodebuild test …`). Manually reason: pushed PaywallView's `dismiss()` pops it (same as `pop()`); Settings back `dismiss()` pops; Settings Go Pro still pushes the paywall on iOS via the injected closure. No iOS regression.
- [ ] **Step 5** — Commit: `refactor: make Paywall/Settings router-free via \.dismiss + onGoPro (cross-platform)`.

---

### Task 2: macOS account surface — toolbar button → Settings sheet

**Files:** Modify `Features/MacShell/MacRootView.swift`.

**Why:** The Mac shell has no way to reach Settings (sign in/out, Restore, Go Pro, legal, analytics toggle). Add a toolbar account button presenting `SettingsView` as a sheet.

- [ ] **Step 1** — In `MacRootView`, add `@State private var showSettings = false` and `@State private var showPaywall = false`. Add a `.toolbar { ToolbarItem(placement: .primaryAction) { Button { showSettings = true } label: { Image(systemName: "person.crop.circle") } } }` on the `NavigationSplitView`.
- [ ] **Step 2** — Present Settings as a sheet: `.sheet(isPresented: $showSettings) { SettingsView(store: container.store, onGoPro: { showSettings = false; showPaywall = true }).environmentObject(container).environmentObject(container.authStore).environmentObject(container.store).frame(minWidth: 520, minHeight: 600) }`.
- [ ] **Step 3** — Present the paywall sheet (used here and by Task 3): `.sheet(isPresented: $showPaywall) { PaywallView(viewModel: container.makePaywallViewModel(source: "settings")).environmentObject(container).environmentObject(container.store).frame(minWidth: 520, minHeight: 640) }`.
- [ ] **Step 4** — Verify macOS build green; iOS build green (MacRootView is `#if os(macOS)`, so iOS unaffected).
- [ ] **Step 5** — Commit: `feat(macos): account toolbar button → Settings + paywall sheets`.

---

### Task 3: macOS detail locked-panel actions (Sign in / Unlock with Pro)

**Files:** Modify `Features/MacShell/MacDetailView.swift`.

**Why:** The locked panel is static. Wire its CTA to present sign-in (`.needsSignIn`) or the paywall (`.needsPro`).

- [ ] **Step 1** — In `MacDetailView`, add `@State private var showAuth = false` and `@State private var showPaywall = false`. Convert `lockedPanel`'s label into a real `Button`: for `.needsSignIn` → "Sign in to view the code" sets `showAuth = true`; for `.needsPro` → "Unlock with Pro" sets `showPaywall = true`. Keep the lock icon.
- [ ] **Step 2** — Present sheets on the `HSplitView`: `.sheet(isPresented: $showAuth) { AuthGateView().environmentObject(container).environmentObject(container.authStore).environmentObject(container.store).frame(minWidth: 480, minHeight: 620) }` and `.sheet(isPresented: $showPaywall) { PaywallView(viewModel: container.makePaywallViewModel(source: "detail")).environmentObject(container).environmentObject(container.store).frame(minWidth: 520, minHeight: 640) }`. (MacDetailView needs `@EnvironmentObject private var container: AppContainer` — add it.)
- [ ] **Step 3** — Auto-dismiss the auth sheet once signed in: `.onChange(of: authStore.isAuthenticated) { _, isAuth in if isAuth { showAuth = false } }`. The paywall self-dismisses (Task 1). `access`/`canViewCode` recompute from `hasPro`/`isAuthenticated`, so the code appears once unlocked.
- [ ] **Step 4** — Verify macOS build green; iOS build green.
- [ ] **Step 5** — Commit: `feat(macos): wire locked-pane Sign in / Unlock with Pro sheets`.

---

### Task 4: Google OAuth macOS presentation anchor

**Files:** Inspect/modify `Auth/SocialAuthService.swift` (the `signInWithGoogle()` that calls supabase `auth.signInWithOAuth`).

**Why:** On macOS, `ASWebAuthenticationSession` needs a key `NSWindow` anchor; supabase-swift's default anchor is a bare detached window that may not present. Supply a real key window via the `configure:`/presentationContextProvider path.

- [ ] **Step 1** — Read `signInWithGoogle()` and how it calls `client.auth.signInWithOAuth(provider:.google, redirectTo:…)`. Determine the SDK's hook for the presentation context (supabase-swift exposes a `configure:` closure on the web-auth session or a `ASWebAuthenticationPresentationContextProviding`).
- [ ] **Step 2** — Add a macOS presentation-anchor provider (`#if os(macOS)`) returning `NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()`. Wire it into the OAuth call's configure hook so the session presents from the app's key window. Leave iOS behavior unchanged (`#if os(iOS)` keeps the existing path).
- [ ] **Step 3** — Verify macOS build green; iOS build green. (Actual presentation is owner on-device verification — note in report.)
- [ ] **Step 4** — Commit: `fix(macos): supply key-window anchor for Google OAuth web session`.

---

### Task 5: AppStore.sync() on macOS first launch + prominent Restore

**Files:** Modify `Store/StoreManager.swift` (or `App/InspireCreativityApp.swift`/`AppContainer`), `Features/MacShell/MacRootView.swift` (or Settings already has Restore).

**Why:** On a fresh Mac install, `currentEntitlements` may be empty on cold launch because `refreshEntitlements()` runs without a preceding `AppStore.sync()`; a cross-platform purchase then surfaces only after a Restore. Trigger a one-time `AppStore.sync()` on first Mac launch so existing buyers are recognized.

- [ ] **Step 1** — Add a macOS-gated one-time sync: on first Mac launch (guard with a `UserDefaults` flag e.g. `macDidInitialStoreSync`), call `try? await AppStore.sync()` then `await refreshEntitlements()`. Put it in `StoreManager` behind a `func syncOnFirstMacLaunchIfNeeded()` called from the macOS app/shell `.task`. Do NOT run this on iOS.
- [ ] **Step 2** — Confirm Settings exposes "Restore purchases" (it does); ensure it's reachable on Mac (via Task 2's Settings sheet). No new Restore UI needed if Settings is reachable.
- [ ] **Step 3** — Verify macOS build green; iOS build green.
- [ ] **Step 4** — Commit: `feat(macos): AppStore.sync() on first Mac launch so cross-platform Pro is recognized`.

---

### Task 6: macOS submission config — Info.plist, Keychain entitlement, category

**Files:** Modify `InspireCreativityApp/Info.plist` (or build settings), `InspireCreativityApp/InspireCreativityApp.entitlements`, `project.pbxproj` (build settings).

**Why:** Mac App Store submission needs: `LSRequiresIPhoneOS` must not break the macOS slice; Firebase Installations needs a Keychain-Sharing entitlement on macOS (else a keychain prompt / errSecMissingEntitlement -34018); an app category.

- [ ] **Step 1** — Inspect `Info.plist` for `LSRequiresIPhoneOS`. If present and `true`, ensure it does not apply to the macOS product (the macOS build already launches, but App Store validation may flag it). Prefer a per-platform handling: keep iOS as-is; for macOS ensure the key is absent/ignored (e.g., `INFOPLIST_KEY_LSRequiresIPhoneOS` only for iOS, or strip via a macOS-conditional build setting). Verify both builds still launch/validate.
- [ ] **Step 2** — Add `keychain-access-groups` to the entitlements (e.g. `$(AppIdentifierPrefix)com.inspirecreativity`). On iOS this is harmless; on macOS it lets Firebase Installations persist the FID without a prompt.
- [ ] **Step 3** — Set `INFOPLIST_KEY_LSApplicationCategoryType` (e.g. `public.app-category.developer-tools`) for the app, and ensure `NSHumanReadableCopyright` is present if required.
- [ ] **Step 4** — Verify macOS build green; iOS build green. Back up `project.pbxproj` before editing (`cp` to scratch); if `-showdestinations`/build breaks, restore and report BLOCKED.
- [ ] **Step 5** — Commit: `build(macos): submission config — LSRequiresIPhoneOS handling, Keychain Sharing, app category`.

---

### Task 7: EEA/UK first-run opt-in analytics consent gate

**Files:** Create `Features/Consent/AnalyticsConsent.swift` (logic, cross-platform) + a consent prompt view; modify `App/AppContainer.swift` (gate `setCollectionEnabled` on consent) and the app entry (present the gate on first launch). Test: `InspireCreativityAppTests/AnalyticsConsentTests.swift`.

**Why:** Analytics is opt-out-by-default worldwide; EEA/UK requires prior opt-in. Build a first-run consent gate (region-conditioned) that keeps collection OFF until the user consents.

- [ ] **Step 1 (TDD)** — Write `AnalyticsConsentTests`: a pure `AnalyticsConsent` decision type — `needsPrompt(region:storedDecision:) -> Bool` (true when region ∈ EEA/UK AND no stored decision), and `collectionAllowed(region:storedDecision:analyticsEnabled:) -> Bool` (EEA/UK: only if consented; elsewhere: follows `analyticsEnabled`). Assert the matrix. Run RED.
- [ ] **Step 2** — Implement `AnalyticsConsent` (uses `Locale.Region`/`Locale.current.region` for EEA/UK membership — include the EEA list + GB). Persist the decision in `UserDefaults` (`analyticsConsentDecision`). Run GREEN.
- [ ] **Step 3** — In `AppContainer.init`, replace the unconditional `analytics.setCollectionEnabled(enabled)` with `analytics.setCollectionEnabled(AnalyticsConsent.collectionAllowed(...))` so EEA/UK users start with collection OFF until they consent.
- [ ] **Step 4** — Add a lightweight first-run consent prompt (sheet/overlay) shown when `AnalyticsConsent.needsPrompt(...)`; on choice, store the decision and call `analytics.setCollectionEnabled(...)`. Present from both shells (iOS RootView + macOS MacRootView) via a shared modifier.
- [ ] **Step 5** — Verify: tests pass; macOS + iOS builds green.
- [ ] **Step 6** — Commit: `feat: EEA/UK first-run analytics consent gate (opt-in)`.

---

### Task 8: Compliance & hygiene fixes

**Files:** `PrivacyInfo.xcprivacy`; `Features/Settings/SettingsView.swift` ("Anonymous" copy); stale comments in `Analytics/FirebaseAnalyticsTracker.swift`, `App/AppContainer.swift`, `App/InspireCreativityApp.swift`; `legal/privacy.md` IF present in-repo.

- [ ] **Step 1** — Reconcile `PrivacyInfo.xcprivacy` to the actual collection: Email + UserID (AppFunctionality); ProductInteraction / DeviceID / CoarseLocation / PurchaseHistory (Analytics, not linked, not tracking); drop Diagnostics (no Crashlytics). Keep `NSPrivacyTracking=false`.
- [ ] **Step 2** — Reword the Settings "Anonymous" copy (`SettingsView.swift`) to e.g. "Usage stats only — not linked to you." Update stale "analytics not yet wired / added later" comments in the 3 files to state Firebase is integrated and live.
- [ ] **Step 3** — If `legal/privacy.md` exists in this repo, fix the line claiming "no third-party advertising or analytics SDKs" to disclose Firebase/GA4 + the opt-out. If the privacy policy is only hosted in the separate `inspirecreativity-legal` repo, note it in the owner checklist (Task 9) instead.
- [ ] **Step 4** — Verify macOS + iOS builds green; tests green.
- [ ] **Step 5** — Commit: `chore(compliance): reconcile privacy manifest + copy; refresh stale analytics comments`.

---

### Task 9: Final verification + owner submission checklist

**Files:** Create `docs/macos-submission-checklist.md`.

- [ ] **Step 1** — Run the full suite: macOS build, iOS build, `xcodebuild test` (all green). Record results.
- [ ] **Step 2** — Write `docs/macos-submission-checklist.md` enumerating the OWNER-only steps: (a) ASC — add macOS platform to the existing `com.inspirecreativity` record for Universal Purchase (dry-run on a non-prod record first; irreversible); confirm the existing `pro.lifetime` appears for macOS; (b) Firebase console — confirm GA4 property + (ideally) a macOS Firebase app + per-platform plist, enable App Check + restrict the API key; (c) signing — macOS distribution cert/profile; (d) metadata — macOS screenshots, description, category, privacy label MATCHING `PrivacyInfo.xcprivacy`; (e) hosted privacy policy update (if in the legal repo); (f) on-device verification — Google OAuth presents, cross-platform Pro unlock with a real sandbox Apple ID on a signed sandboxed build, Metal shaders + gesture items under pointer, dark/material in active+inactive windows.
- [ ] **Step 3** — Commit: `docs: macOS submission owner-checklist + final verification`.

## Self-Review
- Spec coverage: Mac auth (T2/T3) · paywall (T1/T2/T3) · Settings/Restore (T1/T2) · Google OAuth anchor (T4) · AppStore.sync (T5) · submission config (T6) · EU consent (T7) · privacy/compliance (T8) · verification + owner checklist (T9). The router-free refactor (T1) is the only shared-iOS-view change and is explicitly iOS-preserving.
- Placeholder scan: tricky parts (router-free via `\.dismiss`, consent decision type, OAuth anchor) have concrete approaches; mechanical wiring gives exact APIs/files for implementers reading the real components.
- Type consistency: `SettingsView(store:onGoPro:)` new signature is updated at its iOS call site (T1) and Mac call site (T2). `MacDetailView` gains `container` env object (T3).
