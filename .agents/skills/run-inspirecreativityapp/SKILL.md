---
name: run-inspirecreativityapp
description: Build, run, launch, and screenshot the InspireCreativityApp iOS app on a Simulator. Use when asked to run/start/build/test/screenshot the app, see a SwiftUI screen, or drive the app past its login gate headlessly.
---

# Run InspireCreativityApp

A native **iOS 17+ SwiftUI** animation-catalog app. Single Xcode target,
**no third-party deps** (no SPM/CocoaPods). It gates on a Supabase
email/password **auth screen** before showing the main app.

Driven headlessly with `xcrun simctl` + `xcodebuild` via the committed
driver — **no GUI automation, no Accessibility permission needed**.
Screenshots are real `simctl` captures (device-native resolution, ~3× points→px).

> Paths below are relative to the repo root (the `<unit>` dir). The driver is
> at `.Codex/skills/run-inspirecreativityapp/driver.sh`.

## Prerequisites

Xcode + iOS simulators (verified on **Xcode 26.1.1**, sim **iPhone 17 / iOS 26.1**).
No `apt-get` / brew installs are required for the verified path. `cliclick`
(`brew install cliclick`) is only needed if you later add GUI taps — see Gotchas.

## Run (agent path) — use the driver

```bash
# Full flow to the authenticated Discover screen (no credentials needed):
.Codex/skills/run-inspirecreativityapp/driver.sh up
# -> builds, boots iPhone 17, installs, injects a local session,
#    launches, writes /tmp/icapp-shots/discover.png

# Full flow to the signed-out auth gate:
.Codex/skills/run-inspirecreativityapp/driver.sh auth
# -> /tmp/icapp-shots/auth.png
```

Then **look at the screenshot** (Read the PNG). `up` lands on Discover;
`auth` shows the "Welcome back" login screen.

Individual steps (all verified):

```bash
D=.Codex/skills/run-inspirecreativityapp/driver.sh
$D boot          # boot sim + open Simulator.app
$D build         # xcodebuild -> /tmp/icapp-dd  (prints BUILD SUCCEEDED)
$D install       # install the .app onto the booted sim
$D bypass        # inject a local session -> app boots past the auth gate
$D logout        # clear the session -> app shows the auth gate
$D launch        # launch the app
$D shot discover # screenshot -> /tmp/icapp-shots/discover.png
$D terminate     # kill the app
$D help          # commands + resolved UDID/paths
```

Override the device/paths via env, e.g. `DEVICE='iPhone 17' SHOTS=/tmp/x $D up`.

## How the auth bypass works (important)

The app shows the main UI only when `AuthStore.isAuthenticated` is true, which
is driven by a session persisted in `UserDefaults` under key
`enigma.auth.session`. `bypass` writes a fake session blob there:

```bash
# what `bypass` does, in essence:
JSON='{"accessToken":"fake-access","refreshToken":"fake-refresh","expiresAt":"2099-01-01T00:00:00Z","user":{"id":"00000000-0000-0000-0000-000000000000","email":"dev@local.test","emailConfirmedAt":"2024-01-01T00:00:00Z","createdAt":"2024-01-01T00:00:00Z"}}'
HEX=$(printf '%s' "$JSON" | xxd -p | tr -d '\n')
xcrun simctl spawn "$UDID" defaults write com.inspirecreativity enigma.auth.session -data "$HEX"
```

On launch the app boots straight into Discover, then background-validates the
token against `/auth/v1/user`. The fake token is **deliberately not a JWT**: the
server returns `403 bad_jwt`, which `AuthStore` maps to `.unknown` (not
`.invalidCredentials`) — and it only clears the session on `.invalidCredentials`.
So the injected session **persists** and the signed-in state is stable. (A
well-formed-but-fake JWT would get a `401` → cleared → bounced back to the gate.)

## Run (human path)

Open `InspireCreativityApp.xcodeproj` in Xcode, pick an **iOS 18+** iPhone
simulator, `Cmd-R`. You'll land on the login screen — sign in with a real
confirmed Supabase account, or use `driver.sh bypass` first. Useless headless;
prefer the driver.

## Test

There is no XCTest target in the Xcode project at time of writing
(`xcodebuild -list` shows only the `InspireCreativityApp` scheme). The build
itself (`driver.sh build`) is the smoke test for compilation.

## Gotchas

- **Auth gate, no docs.** The README predates auth and says "just `Cmd-R`."
  The app actually opens on a Supabase login screen. Use `bypass`.
- **Email-confirm is ON.** Signing up a new account via the live backend
  returns "confirmation required" (no session) and immediate sign-in fails with
  `email_not_confirmed` — you can't mint a working session by signup. The
  `bypass` (local injection) is the headless way in.
- **GUI taps need Accessibility permission, which is NOT granted here.**
  `cliclick` warns "Accessibility privileges not enabled" and clicks fail;
  AppleScript `activate` + System Events times out (`-1712`). So tapping/typing
  into the simulator window is unavailable in this environment. The driver
  therefore covers **build/launch/screenshot only** — it screenshots whatever
  loads (auth gate, or Discover after `bypass`), not arbitrary navigation. To
  add taps later: grant the terminal app Accessibility in System Settings →
  Privacy & Security → Accessibility, then map device-points → screen-pixels
  off the Simulator window rect (System Events *reads* fine without `activate`).
- **iOS 17 sims clip the layout** (content in the left half) — an Xcode/iOS-17
  host quirk, not an app bug. Use an **iOS 18+** sim (default `iPhone 17`).
- **A sim runtime can go "unavailable" mid-session** (`runtime profile not
  found`) — e.g. iPhone 16 Plus / iOS 18.4 did during authoring. `udid()` then
  returns empty and the build errors with `missing value for key 'id'`. Pick an
  available device: `xcrun simctl list devices available`, then `DEVICE='…'`.
- **`-destination 'name=...'` is ambiguous** — every sim is listed twice
  (arm64 + x86_64). xcodebuild warns and picks the first; harmless. The driver
  resolves a concrete UDID to avoid surprises.
- **Screenshots take a beat.** SwiftUI animations + launch transition mean an
  immediate screenshot can be black. The driver waits `$WAIT` (default 4s).
- **Backend is live & reachable.** `GET /rest/v1/animations` returns 200 with
  the anon key; the app also falls back to a bundled seed catalog if offline.

## Troubleshooting

- **App bounces back to the login screen after `bypass`** → the fake token was
  parseable as a JWT (got a `401`). Keep `accessToken` a non-JWT string like
  `fake-access` so the server returns `403 bad_jwt` instead.
- **`BUILD FAILED` / no `.app`** → `rm -rf /tmp/icapp-dd` and re-run
  `driver.sh build`.
- **Black screenshot** → raise the wait: `WAIT=6 driver.sh shot discover`.
- **No simulator found** → `DEVICE='iPhone 17' driver.sh up`, or list with
  `xcrun simctl list devices available`.
