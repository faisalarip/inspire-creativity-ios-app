#!/bin/sh
# ci_pre_xcodebuild.sh — Xcode Cloud pre-build hook.
#
# INTENTIONAL NO-OP. Xcode Cloud manages the build number natively: at archive
# time it overrides CFBundleVersion/CURRENT_PROJECT_VERSION with its own
# monotonically increasing build number, regardless of what the checkout says.
#
# Proven empirically in run #21 (2026-08-02): this script's previous agvtool
# stamp wrote 121 into the checkout (log: "Updated CFBundleVersion … to 121"),
# yet the delivered artifact carried CFBundleVersion 21 — Xcode Cloud's own
# counter. Every TestFlight upload since run 15 carries the run number, so the
# agvtool stamp never had an effect; it only ADDED a failure mode — the Test
# action runs this hook a second time in its test-execution phase, where the
# stamp exited 1 and (now that Test is Required to Pass) would fail the build.
#
# Build-number policy therefore lives in ONE place: Xcode Cloud's native
# counter (unique + increasing, satisfying App Store Connect). The marketing
# version stays owned by Tools/bump_version.sh. If a future numbering change
# is ever needed, adjust it in the Xcode Cloud workflow (next-build-number),
# not here.
set -e

echo "ci_pre_xcodebuild: no-op — Xcode Cloud manages the build number natively (see header)."
