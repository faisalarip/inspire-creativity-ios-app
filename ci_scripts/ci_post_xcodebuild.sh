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

# TestFlight "What to Test": when this run produced an App Store-signed archive,
# generate TestFlight/WhatToTest.en-US.txt next to ci_scripts (Apple's documented
# location) from recent user-facing commits. Xcode Cloud attaches it to the
# TestFlight build it uploads. Best-effort — never fails the build.
if [ -n "$CI_APP_STORE_SIGNED_APP_PATH" ] && [ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]; then
  TESTFLIGHT_DIR="$CI_PRIMARY_REPOSITORY_PATH/TestFlight"
  mkdir -p "$TESTFLIGHT_DIR"
  cd "$CI_PRIMARY_REPOSITORY_PATH"
  git fetch --deepen 50 2>/dev/null || true
  if [ -x scripts/generate_release_notes.sh ] && scripts/generate_release_notes.sh > "$TESTFLIGHT_DIR/WhatToTest.en-US.txt" 2>/dev/null \
      && [ -s "$TESTFLIGHT_DIR/WhatToTest.en-US.txt" ]; then
    echo "ci_post_xcodebuild: WhatToTest.en-US.txt generated from release notes script."
  else
    git log -5 --no-merges --pretty='format:- %s' -- . > "$TESTFLIGHT_DIR/WhatToTest.en-US.txt" 2>/dev/null \
      || echo "- Internal build for testing." > "$TESTFLIGHT_DIR/WhatToTest.en-US.txt"
    echo "ci_post_xcodebuild: WhatToTest.en-US.txt generated from recent commits (fallback)."
  fi
fi
