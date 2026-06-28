# Xcode Cloud setup (one-time, Apple-side)

This is the human-only setup for the CI/CD pipeline described in
`docs/superpowers/specs/2026-06-22-autonomous-loop-xcode-cloud-design.md`.
The agent cannot create these for you — they live in Xcode / App Store Connect
and on your Apple account. Once they exist, the in-repo pieces (`ci_scripts/`,
`Tools/bump_version.sh`, `Tools/xcode_cloud_status.py`) drive the rest.

Project facts the steps below rely on:

| Thing | Value |
|---|---|
| Xcode project | `InspireCreativityApp.xcodeproj` (repo root) |
| Shared scheme | `InspireCreativityApp` |
| App target | `InspireCreativityApp` · bundle id `com.inspirecreativity` |
| Test target | `InspireCreativityAppTests` |
| Team | `5VHRN5SF2P` · signing **Automatic** (→ Xcode Cloud managed signing) |
| Trigger branch | `release` |
| Versioning | Apple Generic Versioning is **enabled** (`VERSIONING_SYSTEM = apple-generic`); build number set by `ci_scripts/ci_pre_xcodebuild.sh` from `$CI_BUILD_NUMBER` |

---

## 1. Create the Xcode Cloud workflow

Xcode ▸ **Integrate** ▸ **Manage Workflows** (or App Store Connect ▸ your app ▸
Xcode Cloud). Connect the GitHub repo `faisalarip/inspire-creativity-ios-app`
when prompted, then configure:

- **Name:** **`Release`** — the status poller filters on this exact name
  (`Tools/xcode_cloud_status.py --workflow Release`). If you name it something
  else, pass that name to `--workflow`.
- **Start Condition:** *Branch Changes* — branch **`release`** only. (Everyday
  commits to `main` / feature branches must NOT build.)
- **Environment:** latest released Xcode; macOS as required by the SDK.
- **Actions (in order):**
  1. **Build** — scheme `InspireCreativityApp`.
  2. **Test** — scheme `InspireCreativityApp`, an iOS Simulator destination.
     **This is the gate** — a failing test must block everything after it.
  3. **Archive** — for the iOS app, with "Deployment Preparation: TestFlight
     (and App Store)" as desired.
- **Post-Actions:**
  - **TestFlight (Internal Testing)** → your internal group. *(First N cycles:
    TestFlight only.)*
  - **App Store** distribution → add later, once the loop is trusted (this is
    what makes "submit to App Review" near-automatic; release still manual).
- **Signing:** **Managed by Xcode Cloud**, team `5VHRN5SF2P`. Do not add
  manual profiles.

`ci_scripts/ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, and `ci_post_xcodebuild.sh`
are auto-detected and run — no configuration needed beyond them being present
and executable. Commit them with the executable bit preserved and confirm with
`git ls-files -s ci_scripts/` (each should show mode `100755`). Xcode Cloud runs
the scripts from the pushed git tree, not your local working copy.

> **Also commit `Package.resolved`.** Xcode Cloud does not auto-resolve Swift
> packages — it resolves them from the committed
> `InspireCreativityApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
> It is no longer git-ignored; make sure it is tracked and pushed.

## 1b. macOS Archive action (Universal Purchase)

The same app target is multiplatform (`#if os(macOS)`), so macOS ships as a
**second platform on the same app record** (Universal Purchase) — NOT a separate
app, App ID, or scheme. To make Xcode Cloud produce the Mac build automatically,
add a macOS **Archive** action to the **same `Release` workflow** (App Store
Connect ▸ Xcode Cloud ▸ workflow ▸ Edit ▸ add Action):

- **Archive** — scheme `InspireCreativityApp`, **Platform: macOS**, Deployment
  Preparation: *TestFlight (and App Store)*. This runs alongside the iOS Archive;
  one workflow run then yields both an iOS and a macOS build.
- **Post-Action:** TestFlight (the macOS build appears under the app's macOS
  TestFlight; Universal Purchase shares the single IAP).
- **Signing:** Managed by Xcode Cloud — it provisions the macOS Distribution
  cert/profile automatically against the existing App ID. (Manual signing would
  need a Mac App Distribution cert + Mac App Store profile for `com.inspirecreativity`.)

**No `ci_scripts/` changes were needed for macOS** (verified): `ci_post_clone`
and `ci_post_xcodebuild` are platform-agnostic markers, and `ci_pre_xcodebuild`'s
`agvtool new-version -all "$CI_BUILD_NUMBER"` stamps the shared target identically
for either platform. The macOS target also builds clean in **Release/WMO** (the
config Archive uses) — checked with
`-Xfrontend -warn-long-expression-type-checking=300`, no type-check timeouts.

> The macOS platform add is **permanent once App Review approves it** — dry-run
> the add-platform flow on a non-production record first if unsure
> (see `docs/macos-submission-checklist.md`).

## 2. Generate an App Store Connect API key (for the status poller)

App Store Connect ▸ **Users and Access** ▸ **Integrations** ▸ **App Store
Connect API** ▸ generate a key with the **least-privilege role that can read
Xcode Cloud data — `Developer` is enough**. The poller only issues read-only
`GET` requests; avoid `Admin` / `App Manager` unless you separately need write
access.

- Download the **`.p8`** — you can only download it once.
- Note the **Key ID** and the **Issuer ID** (a UUID at the top of the page).
- Store the `.p8` **outside the repo** (e.g. `~/.appstoreconnect/keys/`).

Then export, for the loop's poller (add to your shell profile, not the repo):

```sh
export ASC_KEY_ID="<Key ID>"
export ASC_ISSUER_ID="<Issuer ID>"
export ASC_KEY_PATH="$HOME/.appstoreconnect/keys/AuthKey_<Key ID>.p8"
```

Install the poller's one dependency: `pip3 install pyjwt cryptography`.

> The repo's `.gitignore` should keep `*.p8` out of version control. Never
> commit the key, the Key ID, or the Issuer ID.

## 3. App Store Connect app + TestFlight + listing

- The app record exists in App Store Connect (bundle id `com.inspirecreativity`).
- A **TestFlight internal testing group** exists for the post-action upload.
- App Store **metadata + screenshots** are complete enough to submit for review
  (required once you enable the App Store post-action).

## 4. You press "Release"

Submit-to-review is automatable; **release is not**. After Apple approves, you
release in App Store Connect (phased release recommended). The loop never does
this step.

---

## Verify Phase 1 (one green TestFlight build)

0. Create the `release` branch once, from a green `main`:
   `git switch main && git switch -c release && git push -u origin release`.
1. Locally, on a feature branch, make a trivial safe change and run the tests
   green. Pick an **installed** simulator — list them with
   `xcrun simctl list devices available`:
   `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17'`.
2. Merge to `release` and push: `git switch release && git merge --ff-only <branch> && git push origin release`.
3. Watch the Xcode Cloud run (Xcode ▸ Integrate, or the dashboard). Expect:
   Build → Test (passes) → Archive → a new build appears in **TestFlight** with
   a `CFBundleVersion` equal to Xcode Cloud's `$CI_BUILD_NUMBER`.
4. Confirm the build number incremented as expected (that proves
   `ci_pre_xcodebuild.sh` + AGV are working).

Once that's green, Phase 2 (the poller + the `/loop` protocol in
`docs/loop/README.md`) layers on top.
