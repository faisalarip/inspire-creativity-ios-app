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
referrer, so use Apple's campaign token — installs show up in
App Store Connect → Analytics → Sources:
```
https://apps.apple.com/app/id6778075297?ct=medium_<post-slug>&mt=8
```
In-app, those users self-report "Medium" at onboarding, which closes the loop.

**Smart hand-off page (best of both):** host `go.html` (next to this file) on
the GitHub Pages site, then link Medium posts to:
```
https://faisalarip.github.io/inspirecreativity-legal/go.html?src=medium&c=<post-slug>
```
It tries the app scheme first (installed → measured attribution) and falls
back to the App Store with the campaign token after ~1.2s.

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
