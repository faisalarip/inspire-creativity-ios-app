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
- [x] **Delete dead code left by the v2 redesigns** — 3 Discover v1 views +
      pbxproj refs deleted, Mac dead auth sheet + unused authStore removed;
      188/188 iOS tests, macOS build clean.
- [x] **Release-configuration build check** — iOS Simulator + macOS Release
      builds clean (0 errors), 2026-07-19.
- [x] **Device smoke install** — installed + launched on the iPhone 16 Pro
      repeatedly through 2026-07-19 (latest: growth commit a7ffb0a).
- [x] **App Store metadata draft for 2.0** — appstore/listing.md updated:
      subtitle/keywords ("animation" was missing!), 300+ count, honest
      account/analytics copy, v2.0 what's-new, ⚠️ privacy-label correction
      (Firebase Analytics must be declared in ASC — previous label said
      "no analytics SDKs"). ASC entry is Faisal's action.
- [x] **Fresh product-page screenshots** — 10 shots at 1206×2622 (ASC 6.3")
      in appstore/screenshots-2.0/: discover, meter unlock, browse, samples,
      search, library, onboarding, contextual paywall, activity, notif prefs.
- [x] **Post-release analytics watch note** — see "Data review, ~2 weeks
      after release" below.

## Data review, ~2 weeks after 2.0 ships

One-glance validation targets (baseline: 28d window Jun 21–Jul 18 2026):
| Metric | Baseline | Expect | Meaning |
|---|---|---|---|
| code_copied users | ~0 (<12 events) | >40% of actives | free-gate removal worked |
| meter_copy_used / user | n/a | 1–3/wk | metering engages |
| paywall_viewed source=meter → purchase | n/a | ≥3× detail-source | metered trigger converts |
| purchase_completed / mo | ~2 | 4+ | headline CVR |
| D1 retention | ~0% | 15%+ | engagement layer + notifications |
| onboarding_completed categories>0 | n/a | >60% | quest resonates |
| restore_failed, pricing_unavailable | n/a | ≈0 | StoreKit health |
| Screens report | mangled | readable names | screen_class fix |

Zero-code ASC actions still open for Faisal: regional price tiers (ID/IN),
privacy-label analytics declaration, paste listing.md 2.0 copy + upload
appstore/screenshots-2.0/.

## Completion summary (2026-07-19)
All checklist items done or handed to ASC. Shipped on origin/release through
this work: v2.0 engagement update, conversion pass (free code, contextual
paywall, purchase recovery), v2.1 growth set (Pro-copy meter, onboarding
quest, share links, Mac meter parity). 203/203 tests green; Debug + Release
builds clean on iOS and macOS; device-verified on iPhone 16 Pro.

## Loop rules
- One item per wake-up, fully verified and committed before checking it off.
- If blocked (e.g. TCC permission loss, missing credentials), note the blocker
  under the item, skip to the next unblocked item, and continue.
- Never submit anything to App Review; TestFlight-only automation.
- When ALL items are checked (or only blocked items remain): run the full
  test suite one final time, write a summary at the bottom of this file, and
  STOP the loop (ScheduleWakeup stop).
