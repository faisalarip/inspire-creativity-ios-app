# The autonomous dev loop

A supervised, recurring loop where the agent proposes one enhancement,
implements it on your approval (TDD + review gates), versions it, and ships it
to TestFlight via Xcode Cloud — then reports the build result. Design:
`docs/superpowers/specs/2026-06-22-autonomous-loop-xcode-cloud-design.md`.

**Contract: propose & approve.** Nothing is implemented or shipped without your
go-ahead. The loop proposes; you approve, redirect, or reject.

## Prerequisites

- Phase 1 proven: a push to `release` produces a green Xcode Cloud run that
  lands a TestFlight build (see `docs/ci/xcode-cloud-setup.md`).
- ASC API env vars set + `pip3 install pyjwt cryptography` (for the poller).
- A `release` branch exists and tracks `origin/release`. Create it once from a
  green `main`: `git switch main && git switch -c release && git push -u origin release`.

## Kick it off

Run the `/loop` skill self-paced (manual kick-off; tighten to a schedule later):

```
/loop  Run one iteration of the autonomous dev loop in docs/loop/README.md.
```

## One iteration

1. **Propose.** Pick the next enhancement — from `docs/backlog.md` or generated
   — as one concrete, scoped change. State the user value, the files it touches,
   and the test that will prove it. *Wait.*
2. **Approve gate.** Proceed only on explicit approval. On reject, propose an
   alternative; don't implement anything in the meantime.
3. **Implement** via subagent-driven TDD:
   - Write the failing test first, then the implementation.
   - Spec/quality review pass (a reviewing subagent) before declaring done.
   - Local build + tests **green** — no exceptions (use an installed simulator;
     list them with `xcrun simctl list devices available`):
     `xcodebuild test -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17'`
4. **Version.** If the change is release-worthy, bump the marketing version:
   `Tools/bump_version.sh --minor` (or `--patch` / an explicit version). The
   build **number** is owned by Xcode Cloud — never hand-bump it.
5. **Ship.**
   ```sh
   git switch -c feat/<slug>            # implement here, commit
   git switch release && git pull --ff-only
   git merge --ff-only feat/<slug>
   git push origin release              # ← triggers Xcode Cloud
   ```
6. **Monitor.** Poll until the run is terminal, then report:
   ```sh
   Tools/xcode_cloud_status.py --product InspireCreativityApp --workflow Release --watch
   ```
   Report "build #N: test passed · uploaded to TestFlight" (or the failure +
   the run's logs link). Exit code: `0` succeeded · `1` failed · `2` not yet
   terminal / timed out.
7. **Repeat** from step 1.

## Safety gates (because runs auto-submit toward review)

- Local `xcodebuild test` must be **green** before any push to `release`.
- Xcode Cloud's **Test action gates** Archive/distribution — a failing test
  never reaches TestFlight.
- **Submit-to-review ≠ release.** Apple reviews; *you* press Release. Use
  phased release.
- **First N cycles: TestFlight only** (App Store post-action disabled). Enable
  auto-submit-to-review only once the loop is trusted.
- The loop never edits signing, entitlements, or `GoogleService-Info.plist`
  without calling it out explicitly in the proposal.

## Notes

- Everyday work stays on `main` / feature branches and does **not** build.
  Only `release` triggers Xcode Cloud.
- If a run fails, fix forward on a feature branch and re-ship; don't push
  directly to `release`.
