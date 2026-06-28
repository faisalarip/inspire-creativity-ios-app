# macOS App Store — Owner Submission Checklist

The code is production-grade and verified building/testing (macOS + iOS builds green; full XCTest suite green). The items below are **owner-only** — they require App Store Connect access, the Firebase/Google Cloud consoles, signing assets, store metadata, or on-device verification — and cannot be done or proven from the build. Work top-to-bottom.

## 1. App Store Connect — Universal Purchase (⚠️ irreversible)
- [ ] Confirm the live app record's bundle id is **`com.inspirecreativity`** (it is, in the project; verify the ASC record matches).
- [ ] **Dry-run first:** validate the macOS-platform-add + Universal Purchase flow on a **non-production** ASC record. Adding a 2nd platform is **permanent** once App Review approves it.
- [ ] On the production record: **Add platform → macOS** (do NOT create a second app; do NOT recreate the IAP). Confirm the existing non-consumable **`com.faisalarip.InspireCreativityApp.pro.lifetime`** appears for macOS.
- [ ] Verify cross-platform unlock on a **signed, sandboxed Mac build** with a **real sandbox Apple ID** that purchased Pro on iOS: launch the Mac app → `isPro` flips true (the app calls `AppStore.sync()` once on first Mac launch; Restore is in Settings as a fallback). A local `.storekit` file does NOT prove cross-platform sharing.

## 2. Firebase / Google Cloud console (analytics is already live in-app)
- [ ] Confirm a **GA4 property + an iOS data stream** are linked to Firebase project **`inspire-creativity-daabd`** (else the app collects but nothing lands in GA4). Verify with `-FIRAnalyticsDebugEnabled` in GA4 DebugView: automatic events (`first_open`, `session_start`, `screen_view`) + the app's custom events.
- [ ] (For clean per-platform data when macOS ships) Register a **second Apple-platform Firebase app** and ship a per-target `GoogleService-Info.plist`; otherwise macOS sessions attribute under the iOS stream.
- [ ] **Public-repo key hygiene:** enable **Firebase App Check** and add **API-key application restrictions** in Google Cloud (restrict to bundle id `com.inspirecreativity`). The `GoogleService-Info.plist` is committed in a public repo — client keys are not secrets, but restrict the key.

## 3. Signing & capabilities
- [ ] macOS **Distribution** certificate + provisioning profile for `com.inspirecreativity`.
- [ ] Ensure the App ID / profile includes **Keychain Sharing** (the entitlement `keychain-access-groups = $(AppIdentifierPrefix)com.inspirecreativity` is set in-app for Firebase Installations) and **Sign in with Apple**.
- [ ] App Sandbox is enabled (`com.apple.security.app-sandbox` + `network.client` + `files.user-selected.read-write`). MAS performs notarization at review — no separate notarize step.

## 4. Store metadata
- [ ] macOS **screenshots**, description, keywords; app **category** is `public.app-category.developer-tools` (set in Info.plist — adjust if you prefer another).
- [ ] **App Privacy label MUST match `PrivacyInfo.xcprivacy` exactly:** Email + User ID → *App Functionality* (linked, not tracking); Product Interaction + Device ID + Coarse Location + Purchase History → *Analytics* (NOT linked, NOT tracking). No Diagnostics. **NSPrivacyTracking = false → do NOT add ATT / NSUserTrackingUsageDescription** (the app links analytics-only Firebase, no IDFA).
- [ ] `LSRequiresIPhoneOS=true` remains in the shared Info.plist (ignored on native macOS). Only act if **Transporter/validation explicitly flags it** during upload.

## 5. Hosted legal pages
- [ ] **Publish the updated `legal/privacy.md`** to the live hosted page (the separate **`inspirecreativity-legal`** GitHub Pages repo → `https://faisalarip.github.io/inspirecreativity-legal/privacy/`). The in-repo copy now discloses Firebase/GA4; the hosted URL must match before submission.

## 6. On-device verification (cannot be automated headlessly)
- [ ] **Google OAuth** sign-in actually presents and completes on a signed, sandboxed Mac build (the key-window anchor is wired; the live Supabase Google provider + presentation can only be confirmed on a running Mac).
- [ ] **EEA/UK consent**: set the Mac/device region to an EEA country (or GB) → the first-run opt-in prompt appears; "Allow" enables collection, "Don't allow" keeps it off; the **Settings toggle withdraws/re-grants** consent. Non-EEA region → no prompt, collection follows the Settings toggle as before.
- [ ] **Metal shaders** (10 effects) render correctly on Apple Silicon (ideally also Intel).
- [ ] **Gesture/multi-finger catalog items** behave acceptably under a pointer/trackpad; down-rank or add affordances for any that don't.
- [ ] Dark scheme + `.ultraThinMaterial` look correct in **active AND inactive** windows.
- [ ] Copy / Copy-without-imports / Save `.swift` produce compilable output; selecting code works.

## 7. CI
- [ ] Add the **macOS destination** to the Xcode Cloud lane (currently iOS-only).

---
*Generated as part of the macOS production pass. The in-repo code changes for all of the above (auth/paywall/Settings wiring, OAuth anchor, AppStore.sync, Keychain entitlement, app category, consent gate, privacy disclosures) are complete and committed on `feat/macos-app`.*
