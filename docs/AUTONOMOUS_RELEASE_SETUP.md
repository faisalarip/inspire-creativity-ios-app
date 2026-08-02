# Autonomous Release Pipeline

The single source of truth for how a change becomes an App Store release with
Claude driving. Apple-side one-time setup lives in
[`docs/ci/xcode-cloud-setup.md`](ci/xcode-cloud-setup.md); the recurring loop
protocol lives in [`docs/loop/README.md`](loop/README.md). This document ties
the whole pipeline together.

## Architecture

```text
Claude (Claude Code / Chrome)
  → modifies code on a feature branch
  → scripts/validate_release.sh          (build + tests + hygiene, local)
  → commit → merge --ff-only → push origin release
  → Xcode Cloud "Release" workflow       (build → test → archive → TestFlight)
  → App Store Connect                    (build processing)
  → Tools/xcode_cloud_status.py --watch  (run reaches terminal state)
  → Tools/asc_release.py validate        (processing, association, metadata)
  → RELEASE GATE                         (AUTO_SUBMIT / --authorize)
  → Tools/asc_release.py submit          (App Review submission)
  → Apple approves → human presses Release in ASC (always manual)
```

## Project facts

| Thing | Value |
|---|---|
| Project | `InspireCreativityApp.xcodeproj` (no workspace, SPM only, no Pods) |
| Shared scheme | `InspireCreativityApp` |
| Bundle id | `com.inspirecreativity` · team `5VHRN5SF2P` · signing Automatic |
| Trigger branch | `release` (everyday work on `main`/feature branches never builds) |
| Marketing version | `MARKETING_VERSION` in the pbxproj — bumped by `Tools/bump_version.sh` |
| Build number | Managed natively by Xcode Cloud (its run counter overrides CFBundleVersion at archive time) — never hand-set, never scripted |
| Release tags | `v<version>-ios` / `v<version>-macos` after a version ships |

## Prerequisites

- **Local:** macOS + Xcode matching the project's toolchain; an iPhone
  simulator installed; `pip3 install pyjwt cryptography` for the ASC tools.
- **Apple:** Apple Developer Program membership (team `5VHRN5SF2P`); the app
  record exists in App Store Connect; Xcode Cloud enabled for the team.
- **Repo:** `origin` = `github.com/faisalarip/inspire-creativity-ios-app`;
  branches `main` and `release` exist and are protected from force-pushes.

## Git strategy

- `main` — integration branch; default branch on GitHub.
- `release` — the ONLY branch Xcode Cloud builds. Production-bound merges are
  fast-forward only (`git merge --ff-only`), so history is linear and every
  release commit is a tested feature-branch tip.
- Never: force-push, history rewrite, or deletion of `main`/`release`.

## Versioning

- **Marketing version** (human-facing, e.g. `2.2.0`): owned by
  `Tools/bump_version.sh` (`--major | --minor | --patch | <explicit>`). Bump
  once per App Store release, not per bug-fix commit within a release cycle.
- **Build number**: owned by Xcode Cloud's **native automatic numbering** —
  at archive time it overrides CFBundleVersion with its run counter (verified
  in run #21: an agvtool stamp of 121 in the checkout still shipped as 21).
  Unique and monotonically increasing by construction; every TestFlight build
  since run 15 carries its run number. `ci_pre_xcodebuild.sh` is a documented
  no-op — do not reintroduce scripted stamping (the Test action re-runs the
  hook in its test-execution phase, where an agvtool stamp exits 1 and would
  fail the now-gating Test action).

## Xcode Cloud

One workflow, named **`Release`** — created 2026-06-28, config verified live
2026-08-02. Full click-path in
[`docs/ci/xcode-cloud-setup.md`](ci/xcode-cloud-setup.md):

- **Trigger:** branch changes on `release` only, with auto-cancel of
  superseded runs. (Note: pushing to `release` while a run is in flight
  cancels and replaces that run.)
- **Actions:** `Test - iOS` (**Required to Pass** — the gate; set 2026-08-02,
  it previously didn't block), `Archive - iOS` and `Archive - macOS`
  (Universal Purchase), both with **Distribution Preparation: App Store
  Connect** — builds upload to TestFlight and are App Store-eligible.
- **Post-actions:** Notify (email on success/failure). A failed required
  action stops the run — nothing uploads without green tests.
- **Signing:** managed by Xcode Cloud (Automatic, team `5VHRN5SF2P`).
- **Environment variables:** none — `BUILD_NUMBER_OFFSET` falls back to the
  committed default of 100.
- `ci_scripts/` are auto-detected from the pushed tree; keep them executable
  (`git ls-files -s ci_scripts/` → mode `100755`).

## App Store Connect access (secrets)

The local tools authenticate with an App Store Connect API key:

| Env var | Meaning |
|---|---|
| `ASC_KEY_ID` | API key id |
| `ASC_ISSUER_ID` | issuer id (UUID) |
| `ASC_KEY_PATH` | absolute path to the `.p8` key, stored OUTSIDE the repo |

- Role: **Developer** suffices for read-only status; **App Manager** is
  required for `create-version` / `attach-build` / `set-notes` / `submit`.
- Configure in your shell profile (`~/.zshrc`), never in the repo. The
  `.gitignore` blocks `*.p8`; `scripts/validate_release.sh` fails if a private
  key ever becomes tracked. Secret VALUES never appear in docs or code.

## The release gate

A green Xcode Cloud run means **BUILD SUCCESS**, not **READY FOR APP REVIEW**.
`Tools/asc_release.py` separates the two:

1. `validate --version X` — version record exists and is in a submittable
   state, a VALID (processed, unexpired) build is attached, export compliance
   present, "What's New" filled per locale.
2. `submit --version X` — refuses when an open review submission already
   exists (idempotent), refuses when validation fails, and refuses without
   authorization from ONE of:
   - `--authorize` (one-shot explicit),
   - `AUTO_SUBMIT=true` in the environment,
   - `AUTO_SUBMIT=true` in `scripts/release.env` (standing project setting —
     **currently `true`**, flip to `false` to re-gate every release).

A plain `git push origin release` can only ever end at TestFlight. App Review
submission happens exclusively through `asc_release.py submit`.

## Release process (what `/release` runs)

See `.claude/commands/release.md` for the executable protocol. Summary:

```sh
scripts/validate_release.sh                    # local gate: hygiene+build+tests
Tools/bump_version.sh --patch                  # if this release needs a bump
scripts/generate_release_notes.sh > /tmp/notes # draft; curate before use
git add <specific files> && git commit         # conventional commit
git switch release && git merge --ff-only <feature> && git push origin release
Tools/xcode_cloud_status.py --product InspireCreativityApp --workflow Release --watch
Tools/asc_release.py status                    # build processed?
Tools/asc_release.py create-version --version X   # idempotent
Tools/asc_release.py attach-build   --version X
Tools/asc_release.py set-notes      --version X --file /tmp/notes
Tools/asc_release.py validate       --version X
Tools/asc_release.py submit         --version X   # ← the gate lives here
git tag vX-ios && git push origin vX-ios       # after successful submission
```

## Failure playbook

| Failure | Signature | Action |
|---|---|---|
| **Code** | compile error, locally or in the cloud Build action | Fix on a feature branch → `validate_release.sh` → re-ship. Never bypass. |
| **Test** | XCTest failure | Same as code: investigate, fix, validate, re-ship. Do not delete/skip tests to go green. |
| **CI infrastructure** | Xcode Cloud errored/unavailable, dependency resolution outage | Do NOT change app code. Re-run the workflow once; if it persists, report — check [Apple System Status](https://developer.apple.com/system-status/). |
| **Signing** | archive fails in signing step | Do NOT regenerate certs/profiles blindly. Report the exact error; fix in ASC/Xcode Cloud settings (managed signing usually self-heals on re-run). |
| **ASC processing** | build stuck/`FAILED`/`INVALID` after upload | `asc_release.py status`; INVALID builds usually mean an asset/entitlement problem — read the ASC email, fix, push again (new build number is automatic). Don't spam re-uploads. |
| **Submission rejected** | `DEVELOPER_REJECTED` / review rejection | Address the rejection, `attach-build` a fixed build, `submit` again (states in `SUBMITTABLE_STATES` allow resubmission). |

## Rollback

- **Before push:** `git restore` / drop the feature branch.
- **After push, before submission:** land a revert commit on `release`
  (`git revert <sha>`, never history rewrite); the next cloud build supersedes
  the bad TestFlight build. Expire the bad build in TestFlight if testers
  already have it.
- **After submission, before approval:** remove the version from review in
  ASC (or `asc_release.py` — cancel via ASC UI; the tool never deletes
  versions), fix, resubmit.
- **After release:** ship a `--patch` release through the same pipeline;
  optionally use ASC phased-release pause. App Store versions are never
  deleted.

## Idempotency guarantees

- `create-version` / `attach-build` / `set-notes` / `submit` all no-op (exit 0)
  when the state they would create already exists.
- Build numbers can never repeat (Xcode Cloud counter + fixed offset).
- Re-pushing `release` without new commits does not trigger a new build.
- `submit` never creates a second in-flight review submission.

## What stays human (by design)

- Creating/rotating the ASC API key (`.p8` download is one-time).
- The one-time Xcode Cloud workflow creation/edit (Apple-side UI).
- Pressing **Release** in ASC after Apple approves (use phased release).
- Legal/compliance metadata changes (privacy labels, age rating, encryption
  status) — Claude validates presence, never invents content.
