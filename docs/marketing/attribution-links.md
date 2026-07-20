# Tracking installs & purchases from Medium / external sources

The app attributes every user to a source with two signals, and revenue
follows automatically:

| Signal | When it fires | Where it lands in GA4 |
|---|---|---|
| Self-reported ("Where did you find us?") | Onboarding, first launch | user property `acquisition_source`, event `campaign_details` (medium=`self_reported`) |
| Measured UTM | Any `inspirecreativity://…` link that opens the app | same, medium/campaign from the URL (overrides self-report) |
| Purchase stamp | `purchase_completed` | param `acquisition_source` on the purchase event itself |

## Link templates

**In a Medium post (readers who ALREADY have the app):**
```
inspirecreativity://open?utm_source=medium&utm_medium=blog&utm_campaign=<post-slug>
```

**App Store (readers who DON'T have the app yet):** iOS has no install
referrer, so use Apple's campaign link — downloads AND sales per campaign
show up in App Store Connect → Analytics → Sources → Campaigns. The `ct=`
token only registers together with your provider token (`pt=`), so generate
the link in ASC (Analytics → Sources → Campaigns → Generate Campaign Link)
instead of hand-building it:
```
https://apps.apple.com/app/apple-store/id6778075297?pt=<provider>&ct=medium_<post-slug>&mt=8
```
A PLAIN App Store link still yields aggregate web-referrer data in ASC
(medium.com under Sources → Web Referrers) but nothing per-post and nothing
in Firebase. Either way, installers self-report "Medium" at onboarding,
which closes the GA4 loop.

**Smart hand-off page (best of both) — LIVE since 2026-07-20:**
```
https://faisalarip.github.io/inspirecreativity-legal/go.html?src=medium&c=<post-slug>
```
Deployed to the inspirecreativity-legal Pages repo (go.html at root; a copy
lives next to this file). It tries the app scheme first (installed →
measured GA4 attribution) and falls back to the App Store after ~1.2s.
TODO inside the page: paste the ASC provider token (pt=) to add per-post
download/sales attribution on the store fallback.

## Reading the results in GA4
- Revenue by source: Reports → Monetization (or any Exploration) →
  add dimension **acquisition_source** (custom user property) — or filter
  `purchase_completed` by its `acquisition_source` param.
- Register both as custom definitions once (Admin → Custom definitions):
  user property `acquisition_source`, event param `acquisition_source`.
- Campaign touches: event `campaign_details` (source / medium / campaign).

## Limits (by design, no MMP)
- App Store installs can't carry UTM into first launch (Apple gives no
  referrer; Firebase Dynamic Links is discontinued) — that's what the
  self-report + `ct=` token cover. For exact deferred deep-link attribution
  you'd add an MMP (AppsFlyer/Branch/Adjust) later.
