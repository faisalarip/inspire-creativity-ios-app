---
description: Validate, version, ship to release, watch Xcode Cloud, and submit for App Review (gated by AUTO_SUBMIT).
---

Release the current change set. Follow this protocol exactly; stop and report
at the first unrecoverable failure. Full context: docs/AUTONOMOUS_RELEASE_SETUP.md.

1. **Inspect.** `git status`, `git diff`, `git diff --check`. Confirm every
   modified/untracked file belongs in this release. Never `git add .` without
   that inspection. Confirm: no secrets, no credentials, no debug code, no
   accidental files.
2. **Validate locally.** Run `scripts/validate_release.sh` (hygiene + unsigned
   device build + full simulator test suite). If it fails: read the real
   error, fix it, re-run. Never proceed red; never hide a failure.
3. **Version.** Decide whether this release needs a marketing-version bump
   (`Tools/bump_version.sh --patch|--minor|--major`). Build numbers are owned
   by Xcode Cloud — never hand-edit CURRENT_PROJECT_VERSION.
4. **Release notes.** Draft with `scripts/generate_release_notes.sh`, then
   rewrite them user-facing (no internal jargon, no file names, no analytics
   details). Save to a temp file for step 9.
5. **Commit.** Conventional commit(s) of the specific files. Keep the working
   tree clean afterwards.
6. **Ship.** Fast-forward `release` and push — this is the Xcode Cloud
   trigger:
   `git switch release && git pull --ff-only && git merge --ff-only <branch> && git push origin release`
7. **Watch the cloud run.**
   `Tools/xcode_cloud_status.py --product InspireCreativityApp --workflow Release --watch`
   Exit 0 = succeeded; 1 = failed (get the run's logs, classify per the
   failure playbook — code/test failures come back to step 2, infrastructure
   or signing failures are reported, not code-patched); 2 = still pending.
8. **Verify App Store Connect.** `Tools/asc_release.py status` — wait until
   the uploaded build's processingState is VALID.
9. **Prepare the version.** (all idempotent)
   - `Tools/asc_release.py create-version --version <X>`
   - `Tools/asc_release.py attach-build --version <X>`
   - `Tools/asc_release.py set-notes --version <X> --file <notes>`
10. **Validate release.** `Tools/asc_release.py validate --version <X>` must
    print READY. If information genuinely required for submission is missing
    (screenshots, privacy, compliance), STOP and report exactly what's
    missing — never invent legal/compliance content.
11. **Release gate.** `Tools/asc_release.py submit --version <X>`.
    - If `scripts/release.env` has `AUTO_SUBMIT=true` (current setting) the
      submission proceeds automatically.
    - If the gate blocks (exit 2), report "WAITING FOR AUTHORIZATION" and
      stop; the user authorizes via `--authorize` or by flipping AUTO_SUBMIT.
12. **Tag.** After a successful submission: `git tag v<X>-ios && git push origin v<X>-ios`.
13. **Report** using the standard status block (app, version, build, commit,
    local build/tests, Xcode Cloud, ASC processing, metadata, submission
    state). Report failures with the exact stage, reason, and required action
    — never claim success for anything unverified.
