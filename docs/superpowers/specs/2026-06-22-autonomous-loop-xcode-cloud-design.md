# Spec — Autonomous Dev Loop + Xcode Cloud CI/CD

- **Status:** Draft for review
- **Date:** 2026-06-22
- **Scope:** A supervised, recurring "loop" where the agent proposes an enhancement, implements it on approval (TDD + review gates), bumps the version, and pushes to a `release` branch that triggers **Xcode Cloud** to build → test → archive → TestFlight → submit to App Review. The loop polls Xcode Cloud via the App Store Connect API and reports status proactively.

---

## 1. Decisions (locked in brainstorming)

| Decision | Choice |
|---|---|
| CI/CD | **Xcode Cloud** (Apple-native; managed signing; macOS build/test; built-in TestFlight + App Store distribution) |
| Ship ceiling | **TestFlight + auto-submit to App Review.** Apple still reviews; **human still presses "Release."** |
| Work source | **Propose & approve** — loop proposes each enhancement; human approves before implement/ship |
| Trigger | Push to a dedicated **`release`** branch (everyday commits to `main`/feature branches don't build) |
| Cadence | **Manual kick-off** to start (a supervised `/loop` run), tighten to scheduled later |
| Status reporting | **Both** — loop polls Xcode Cloud via ASC API and reports on completion; dashboard remains available to the human |
| Quality gates | Local TDD + spec/quality review + green build BEFORE push; Xcode Cloud **Test** action gates distribution |

## 2. Architecture

```
LOCAL (your Mac, manual /loop kick-off)
  propose enhancement → [human approves] → implement (subagent-driven TDD + spec/quality review)
  → local xcodebuild test GREEN → bump version → commit on feature branch → merge to `release` → push
        │
        ▼
XCODE CLOUD (Apple cloud, managed signing, triggered by push to `release`)
  Build → Test (GATE) → Archive → TestFlight (auto) → submit to App Review
        │
        ▼
LOOP polls ASC API (ciBuildRuns) → reports "passed/failed · uploaded to TestFlight · submitted"
        │
        ▼
HUMAN presses "Release" in App Store Connect after Apple approves   ← stays manual
```

## 3. What the agent builds (in-repo)

### 3.1 Xcode Cloud build scripts — `ci_scripts/`
Xcode Cloud auto-runs these (must be at repo root, executable). 
- `ci_post_clone.sh` — environment prep. SPM resolves automatically; this is a no-op placeholder unless a dependency needs setup. (`GoogleService-Info.plist` is committed, so no injection needed.)
- `ci_pre_xcodebuild.sh` — **set the build number from Xcode Cloud's monotonic counter** so every TestFlight build is unique:
  ```bash
  #!/bin/sh
  set -e
  if [ -n "$CI_BUILD_NUMBER" ]; then
    cd "$CI_PRIMARY_REPOSITORY_PATH"
    agvtool new-version -all "$CI_BUILD_NUMBER"
  fi
  ```
  Requires the target to use **Apple Generic Versioning** (`VERSIONING_SYSTEM = "apple-generic"`); the project already sets `CURRENT_PROJECT_VERSION`, so confirm/enable AGV. (Alternative if AGV is undesirable: `PlistBuddy` on the generated Info.plist — documented in the plan.)
- `ci_post_xcodebuild.sh` — optional: emit a marker / trigger the auto-submit ASC-API call if Xcode Cloud's built-in App Review submission isn't used (see §6).

### 3.2 Marketing-version bump — `Tools/bump_version.sh`
Bumps `MARKETING_VERSION` (e.g. 1.3 → 1.4) across build configs via `agvtool new-marketing-version` (or `xcconfig`/pbxproj edit), used by the loop when a change is release-worthy. Build number is owned by Xcode Cloud (§3.1), never hand-bumped.

### 3.3 Xcode Cloud status poller — `Tools/xcode_cloud_status.py`
Polls the **App Store Connect API** for the latest CI build run on the `release` workflow and reports status. Auth = ES256 JWT signed with the ASC API key (`.p8`), `ASC_KEY_ID` / `ASC_ISSUER_ID` from env, `.p8` path from a secure env var (never committed). Endpoints: `GET /v1/ciProducts`, `GET /v1/ciBuildRuns?filter[...]`, `GET /v1/ciBuildRuns/{id}` → reads `executionProgress` + `completionStatus` (SUCCEEDED / FAILED / …). Exit code/stdout the loop consumes; loop polls until terminal, then reports (and may fire a local notification).

### 3.4 The loop — `docs/loop/README.md` + `docs/backlog.md`
- `docs/backlog.md` — optional human-seeded queue of enhancement ideas.
- The loop is driven by **`/loop`** (self-paced, manual kick-off). One iteration:
  1. **Propose** the next enhancement (from backlog or generated) — one concrete, scoped change.
  2. **Approve gate** — wait for human approval (this is the "propose & approve" contract). On reject, propose an alternative.
  3. **Implement** via subagent-driven-development (TDD; spec + quality review subagents; build/test green).
  4. **Version** — `bump_version.sh` if release-worthy (else just let CI bump the build number).
  5. **Ship** — commit on a feature branch, `git merge`/fast-forward into `release`, push `release` → triggers Xcode Cloud.
  6. **Monitor** — poll `xcode_cloud_status.py` until terminal; report "build #N: test passed · TestFlight · submitted" (or the failure + logs link).
  7. Loop to step 1.

## 4. What the human provides (Apple-side; agent can't create these)

1. **Xcode Cloud workflow** (Xcode ▸ Integrate ▸ Manage Workflows, or App Store Connect): connect the GitHub repo; **Start condition = Branch Changes on `release`**; **Actions = Build + Test** (Test is the gate); **Archive** with deployment prep; **Post-actions = TestFlight (internal group)** and, when ready, **App Store** distribution; **Managed signing**, team `5VHRN5SF2P`.
2. **ASC API key** — App Store Connect ▸ Users and Access ▸ Integrations ▸ App Store Connect API → generate a key (role: App Manager or Developer). Save the `.p8`, Key ID, Issuer ID **outside the repo**; set `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` env vars for the poller.
3. **ASC app + TestFlight group + App Store listing/metadata** ready (submission to review needs complete metadata + screenshots).
4. **Press "Release"** after Apple approves (phased release recommended).

## 5. Safety gates (given auto-submit-to-review)

- Local **`xcodebuild test` must be green** before any push to `release`.
- Xcode Cloud **Test action gates** Archive/distribution — a failing test never reaches TestFlight.
- **Submit-to-review ≠ release.** Apple reviews; the human releases. Use phased release.
- **Recommendation:** run the first N cycles **TestFlight-only** (omit the App Store post-action); enable auto-submit once the loop is trusted. AI-authored builds entering App Review repeatedly is the main risk.
- The loop never edits signing, entitlements, or `GoogleService-Info.plist` without surfacing it in the proposal.

## 6. Auto-submit-to-App-Review mechanism

Xcode Cloud reliably automates **build → test → archive → TestFlight**. Full hands-off **submit to App Review** is wired one of two ways (decided in the plan):
- (a) Xcode Cloud post-action **App Store distribution** (prepares the App Store version), then a human one-tap "Submit for Review" in ASC — simplest, near-auto.
- (b) `ci_post_xcodebuild.sh` (or the loop after a green run) calls the **ASC API** to create + submit an App Store version programmatically — true hands-off, more moving parts.
Default to (a) for the first cut; (b) is an enhancement.

## 7. Phasing (one spec → two-phase plan)

1. **Phase 1 — CI/CD foundation:** `ci_scripts` (build-number bump) + `bump_version.sh` + the Xcode Cloud workflow setup doc + AGV confirmation. Prove **one green TestFlight build** from a push to `release`.
2. **Phase 2 — the loop:** `xcode_cloud_status.py` poller + the `/loop` propose→approve→implement→ship→monitor protocol + `docs/backlog.md`, layered on the proven Phase-1 pipeline.

## 8. Out of scope

GitHub Actions, fastlane match (Xcode Cloud manages signing), public-store auto-release (human-gated), marketing/listing automation, crash/perf monitoring.

## 9. Verification

- Phase 1: a push to `release` produces a green Xcode Cloud run that lands a build in TestFlight; `agvtool`/build-number increments correctly; `bump_version.sh` changes `MARKETING_VERSION` cleanly + builds.
- Phase 2: `xcode_cloud_status.py` returns correct terminal status for a known run; a full dry-run loop iteration (propose → approve a trivial change → implement → ship → report) completes end-to-end.
