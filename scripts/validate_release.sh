#!/bin/bash
# validate_release.sh — local validation gate, run before every push to `release`.
#
# Verifies, in order:
#   1. git hygiene        — no conflict markers / whitespace errors, no tracked
#                           private keys or .p8 files anywhere in the tree
#   2. device build       — compiles for generic iOS device (catches
#                           device-only issues, e.g. Metal shader compilation;
#                           unsigned, so no provisioning needed locally)
#   3. simulator tests    — full XCTest suite on the first available iPhone sim
#
# Usage (from the repo root):
#   scripts/validate_release.sh          # full validation
#   scripts/validate_release.sh --fast   # skip the device build (tests only)
#
# Exit code 0 = every check passed. Non-zero = the FIRST failing check; the
# failure is printed, nothing is hidden. This script never modifies anything.
set -euo pipefail

SCHEME="InspireCreativityApp"
FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

cd "$(git rev-parse --show-toplevel)"

fail() { printf '❌ FAIL — %s\n' "$*" >&2; exit 1; }
pass() { printf '✅ PASS — %s\n' "$*"; }

# ── 1. Git hygiene ──────────────────────────────────────────────────────────
git diff --check || fail "git diff --check found whitespace/conflict problems"
git diff --cached --check || fail "staged changes contain whitespace/conflict problems"
pass "git hygiene (diff --check)"

if git ls-files '*.p8' | grep -q .; then
  fail "a .p8 private key is tracked by git: $(git ls-files '*.p8' | tr '\n' ' ')"
fi
if git grep -lI -- '-----BEGIN.*PRIVATE KEY-----' -- ':!scripts/validate_release.sh' >/dev/null 2>&1; then
  fail "a private key block is committed: $(git grep -lI -- '-----BEGIN.*PRIVATE KEY-----' -- ':!scripts/validate_release.sh' | tr '\n' ' ')"
fi
pass "no secrets in tracked files"

# ── 2. Device build (unsigned) ──────────────────────────────────────────────
if [ "$FAST" -eq 1 ]; then
  echo "⏭  SKIP — device build (--fast)"
else
  echo "→ building for generic iOS device (unsigned)…"
  xcodebuild build \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    || fail "device build failed (see errors above)"
  pass "device build (generic/platform=iOS)"
fi

# ── 3. Simulator test suite ─────────────────────────────────────────────────
SIM="$(xcrun simctl list devices available | sed -n 's/^[[:space:]]*\(iPhone[^(]*\) (.*/\1/p' | head -1 | sed 's/[[:space:]]*$//')"
[ -n "$SIM" ] || fail "no available iPhone simulator found (xcrun simctl list devices available)"

echo "→ running tests on simulator: $SIM …"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM" \
  -quiet \
  || fail "test suite failed (see failures above)"
pass "simulator test suite ($SIM)"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ VALIDATION PASSED — safe to commit and push to release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
