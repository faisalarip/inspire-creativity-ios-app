#!/bin/sh
# ci_pre_xcodebuild.sh — Xcode Cloud pre-build hook.
#
# Stamps every build with a unique, increasing build number taken from Xcode
# Cloud's own counter ($CI_BUILD_NUMBER), so each TestFlight upload has a
# distinct CFBundleVersion (App Store Connect rejects duplicate build numbers).
#
# How it works in this project (verified locally):
#   * `agvtool new-version -all "$CI_BUILD_NUMBER"` updates CURRENT_PROJECT_VERSION
#     in the project AND writes the number directly into Info.plist's
#     CFBundleVersion — replacing the $(CURRENT_PROJECT_VERSION) reference with a
#     literal. This happens in Xcode Cloud's ephemeral checkout, so the archived
#     build ends up with CFBundleVersion = $CI_BUILD_NUMBER. (The result does not
#     merely rely on build-setting resolution; agvtool also rewrites the plist.)
#   * The app target has Apple Generic Versioning enabled
#     (VERSIONING_SYSTEM = "apple-generic"), kept per Apple's convention for use
#     with agvtool.
#   * `agvtool` prints harmless "Cannot find .../NO|YES" warnings (it misreads
#     boolean build settings as Info.plist paths) but exits 0 and sets the
#     version correctly.
#
# The marketing version (CFBundleShortVersionString) is owned by
# Tools/bump_version.sh and is NOT touched here.
#
# Guarded on $CI_BUILD_NUMBER so it is a harmless no-op if run outside Xcode Cloud.
set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "ci_pre_xcodebuild: \$CI_BUILD_NUMBER unset — not in Xcode Cloud, skipping build-number stamp."
  exit 0
fi

: "${CI_PRIMARY_REPOSITORY_PATH:?ci_pre_xcodebuild: CI_PRIMARY_REPOSITORY_PATH is unset}"
cd "$CI_PRIMARY_REPOSITORY_PATH"
echo "ci_pre_xcodebuild: setting build number to $CI_BUILD_NUMBER via agvtool."
agvtool new-version -all "$CI_BUILD_NUMBER"
echo "ci_pre_xcodebuild: build number is now $CI_BUILD_NUMBER."
