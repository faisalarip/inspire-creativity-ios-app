# Analytics Setup & Handoff

This app ships a swappable analytics abstraction (`AnalyticsTracking`). The Firebase
backend (`FirebaseAnalyticsTracker`) is the only file that imports Firebase, and
`FirebaseApp.configure()` is guarded by the presence of `GoogleService-Info.plist`.
**Without that plist the app builds and runs fine** using the DEBUG `ConsoleAnalyticsTracker`
(or `NoOpAnalyticsTracker` in release/tests). The steps below turn on real GA4 reporting.

## 1. Create a Firebase project + iOS app

1. Go to <https://console.firebase.google.com> and create a project (or reuse an existing one).
2. In the project, **Add app → iOS**.
3. Set the **Apple bundle ID** to `com.inspirecreativity` (must match the app's bundle identifier exactly).
4. Register the app.

## 2. Add `GoogleService-Info.plist`

1. Download `GoogleService-Info.plist` from the Firebase console (Project settings → your iOS app).
2. Drag it into the Xcode project and add it to the **`InspireCreativityApp` target**
   (check "Copy items if needed" and confirm target membership).
3. If this repository is public, **do not commit the plist** — it contains project keys.
   Add it to `.gitignore`:

   ```gitignore
   # Firebase
   GoogleService-Info.plist
   ```

   (For a private repo, committing it is acceptable but optional.)

Once the plist is present, `FirebaseApp.configure()` runs at launch and
`AppContainer.makeAnalyticsTracker()` returns `FirebaseAnalyticsTracker`, so events
flow to GA4 automatically.

## 3. Link a GA4 property

1. In the Firebase console, open **Project settings → Integrations → Google Analytics**
   (or the Analytics section) and enable Google Analytics for the project.
2. Link/create a **GA4 property** so events appear in the Google Analytics 4 dashboard.
3. Reporting can take up to 24 hours to populate standard reports (use DebugView for
   immediate verification — see step 5).

## 4. App Store Connect — App Privacy nutrition labels

In **App Store Connect → your app → App Privacy**, declare the data the analytics SDK
collects. These mirror `PrivacyInfo.xcprivacy` (all **not used for tracking**, **not
linked to the user's identity**):

| Data type            | Linked to identity | Used for tracking | Purpose   |
|----------------------|--------------------|-------------------|-----------|
| Product Interaction  | No                 | No                | Analytics |
| Identifiers (Device ID) | No              | No                | Analytics |
| Usage Data           | No                 | No                | Analytics |
| Diagnostics          | No                 | No                | Analytics |

Notes:
- The app does **not** use App Tracking Transparency (ATT). `NSPrivacyTracking` is `false`
  in `PrivacyInfo.xcprivacy`, so do **not** declare any data as "used to track you".
- Email Address and User ID are already declared (linked, app functionality, not tracking)
  for the existing auth flow — keep those.
- Firebase ships its own SDK-side privacy manifest in the SPM package, so no per-API
  `NSPrivacyAccessedAPITypes` additions are needed for the SDK itself.

## 5. Verify events

**Option A — GA4 DebugView (real backend):**
1. Add the launch argument `-FIRAnalyticsDebugEnabled` in Xcode
   (Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch).
2. Run the app on a device/simulator.
3. Open **Google Analytics → Admin → DebugView** — events (`screen_view`,
   `animation_view`, `favorite_toggled`, `search`, `category_selected`, `paywall_viewed`,
   `purchase_completed`, `sign_in`, `code_copied`, `aurora_promo_tap`) appear within seconds.

**Option B — Console tracker logs (no backend needed):**
- In a DEBUG build without `GoogleService-Info.plist`, the `ConsoleAnalyticsTracker` prints
  every event to the Xcode console:

  ```
  [analytics] event=animation_view params=["animation_id": "ges-x", "category": "Gestures", "is_pro": false]
  [analytics] screen_view screen=detail
  [analytics] collection_enabled=false
  ```

- This is the quickest way to confirm instrumentation fires correctly during development.

## Opt-out

Settings → **Share usage analytics** toggles `Analytics.setAnalyticsCollectionEnabled(_:)`
via `AnalyticsTracking.setCollectionEnabled(_:)`. The preference is persisted in
`UserDefaults` (`analyticsEnabled`, default `true`) and re-applied at launch in
`AppContainer.init`.
