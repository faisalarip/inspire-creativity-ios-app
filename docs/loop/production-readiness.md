# v2.0 production-readiness checklist

Working queue for the autonomous loop. Pick the TOP unchecked item, complete
it with verification (tests / build / screenshot as appropriate), commit,
check it off with a one-line result note, then stop-or-continue per the loop
rules at the bottom.

- [x] **Apply confirmed findings from the conversion-diff review workflow**
      — 1 confirmed finding (stale recoveryHint in restore()) fixed; 188/188
      tests green.
- [x] **Push `release` to origin** — pushed f3509b4 (iOS suite 188/188,
      macOS build clean).
- [ ] **Delete dead code left by the v2 redesigns**: `AuroraPackPromoCard`,
      `CategoryGrid`, `HeroCard` (Discover v1 leftovers, unused on iOS), and
      the never-triggered `showAuth` sheet in `MacDetailPane`. Remove their
      pbxproj references too; suite must stay green.
- [ ] **Release-configuration build check**: `xcodebuild -configuration
      Release build` for iOS Simulator AND macOS destinations. Catches
      DEBUG-only code leaking into release (the QA hooks are `#if DEBUG`).
- [ ] **Device smoke install**: build for the paired iPhone
      (`00008140-000619243430401C`, coredevice
      `AC24745B-9AE8-526E-A5DD-6BD27439B5C2`) and launch `com.inspirecreativity`.
- [ ] **App Store metadata draft for 2.0** in `appstore/`: what's-new text
      leading with the engagement update + free code copy ("Copy free SwiftUI
      animations — no account needed"), subtitle/keyword suggestions aligned
      with the funnel data (organic-only acquisition, 16.3% page CVR). Draft
      only — nothing is submitted.
- [ ] **Fresh product-page screenshots**: capture the v2 screens via the
      headless hooks (`icapp-tab` / `icapp-route` one-shot defaults on the
      booted sim; delete stale keys first) at App Store resolution; store
      under `appstore/` next to the existing preview assets.
- [ ] **Post-release analytics watch note**: document in this file which GA4
      events validate the changes (code_copied should jump from ~0; funnel
      paywall_viewed→purchase_initiated→purchase_completed; restore_failed /
      pricing_unavailable should stay near 0; screen_class rows readable) so
      next week's data review is one glance.

## Loop rules
- One item per wake-up, fully verified and committed before checking it off.
- If blocked (e.g. TCC permission loss, missing credentials), note the blocker
  under the item, skip to the next unblocked item, and continue.
- Never submit anything to App Review; TestFlight-only automation.
- When ALL items are checked (or only blocked items remain): run the full
  test suite one final time, write a summary at the bottom of this file, and
  STOP the loop (ScheduleWakeup stop).
