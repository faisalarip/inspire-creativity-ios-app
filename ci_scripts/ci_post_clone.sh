#!/bin/sh
# ci_post_clone.sh — Xcode Cloud post-clone hook.
#
# Runs immediately after Xcode Cloud clones the repository, before the build.
# Swift Package Manager dependencies are resolved by Xcode Cloud from the
# COMMITTED Package.resolved (Xcode Cloud does not do automatic resolution), and
# GoogleService-Info.plist is committed to the repo, so there is nothing to
# inject or prepare here today.
#
# Kept as an executable placeholder so future environment prep (a secret-
# injection step, a Homebrew tool install, etc.) has an obvious, conventional
# home. Xcode Cloud auto-runs any executable named ci_post_clone.sh in this
# directory; the directory must sit at the repo root (or next to the .xcodeproj).
#
# Docs: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
set -e

echo "ci_post_clone: no environment prep required (deps resolve from committed Package.resolved; GoogleService-Info.plist is committed)."
