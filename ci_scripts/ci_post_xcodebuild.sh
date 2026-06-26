#!/bin/sh
# ci_post_xcodebuild.sh — Xcode Cloud post-build hook.
#
# Runs after EACH xcodebuild action (build, test, archive) — Xcode Cloud invokes
# it once per action, so anything added here must be idempotent. Today it only
# emits a marker so the run logs clearly show the hook fired. TestFlight upload
# and (when
# enabled) App Store submission are handled by the workflow's POST-ACTIONS,
# configured in App Store Connect — see docs/ci/xcode-cloud-setup.md.
#
# Future (design doc §6, option b): a fully hands-off "submit to App Review"
# call to the App Store Connect API could live here. Left intentionally inert
# for the first cut — submission stays human-gated, per the safety plan.
set -e

echo "ci_post_xcodebuild: build actions complete. Distribution handled by workflow post-actions (TestFlight)."
if [ -n "$CI_XCODEBUILD_ACTION" ]; then
  echo "ci_post_xcodebuild: xcodebuild action was '$CI_XCODEBUILD_ACTION'."
fi
