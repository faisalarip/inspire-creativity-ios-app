#!/usr/bin/env bash
# driver.sh — build, launch, and screenshot InspireCreativityApp on an iOS Simulator.
#
# This is the agent harness for the run-inspirecreativityapp skill. Everything
# here runs headlessly via `xcrun simctl` + `xcodebuild` — no GUI automation,
# no Accessibility permission needed. Screenshots land in $SHOTS.
#
# The app gates on an auth screen (Supabase email/password, email-confirm ON).
# `bypass` injects a local session so you can screenshot the real app (Discover)
# without credentials. See README of this skill (SKILL.md) for why it works.
#
# Usage:  ./driver.sh <command> [args]
# Run     ./driver.sh help   for the command list.
set -euo pipefail

# ---- config (override via env) ----------------------------------------------
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
PROJECT="$PROJECT_DIR/InspireCreativityApp.xcodeproj"
SCHEME="${SCHEME:-InspireCreativityApp}"
BUNDLE_ID="${BUNDLE_ID:-com.inspirecreativity}"
DEVICE="${DEVICE:-iPhone 17}"          # any iOS 18+ sim; iOS 17 has a layout quirk (see SKILL.md)
DD="${DD:-/tmp/icapp-dd}"              # derivedDataPath
SHOTS="${SHOTS:-/tmp/icapp-shots}"
APP="$DD/Build/Products/Debug-iphonesimulator/InspireCreativityApp.app"
DEFAULTS_KEY="enigma.auth.session"     # AuthStore.defaultsKey

mkdir -p "$SHOTS"

# Resolve the UDID of $DEVICE (first available match). `xcrun` output is
# captured into a string first, so the grep|sed pipeline can't SIGPIPE a live
# process and trip pipefail (which silently aborted `set -e`).
udid() {
  local list; list="$(xcrun simctl list devices available 2>/dev/null)"
  printf '%s\n' "$list" \
    | grep -m1 -E "(^|[[:space:]])${DEVICE} \(" \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
}
UDID="${UDID:-$(udid)}"

log() { printf '\033[36m[driver]\033[0m %s\n' "$*"; }

# ---- commands ---------------------------------------------------------------
cmd_build() {
  log "building $SCHEME for '$DEVICE' ($UDID) -> $DD"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -sdk iphonesimulator -destination "id=$UDID" -derivedDataPath "$DD" build \
    | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" || true
  test -d "$APP" && log "app at $APP"
}

cmd_boot() {
  log "booting $UDID"
  xcrun simctl boot "$UDID" 2>/dev/null || log "(already booted)"
  open -a Simulator
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
  log "booted"
}

cmd_install() { log "installing"; xcrun simctl install "$UDID" "$APP"; }
cmd_launch()  { log "launching $BUNDLE_ID"; xcrun simctl launch "$UDID" "$BUNDLE_ID"; }
cmd_terminate() { xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true; }

# Inject a local AuthStore session so the app boots past the auth gate.
# The fake accessToken is intentionally NOT a JWT: /auth/v1/user returns
# 403 bad_jwt (not 401), which AuthStore maps to .unknown and so does NOT
# clear the session. Result: a stable, credential-free signed-in state.
cmd_bypass() {
  local json hex
  json='{"accessToken":"fake-access","refreshToken":"fake-refresh","expiresAt":"2099-01-01T00:00:00Z","user":{"id":"00000000-0000-0000-0000-000000000000","email":"dev@local.test","emailConfirmedAt":"2024-01-01T00:00:00Z","createdAt":"2024-01-01T00:00:00Z"}}'
  hex=$(printf '%s' "$json" | xxd -p | tr -d '\n')
  cmd_terminate
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" "$DEFAULTS_KEY" -data "$hex"
  log "injected fake session (app will boot to Discover)"
}

cmd_logout() {
  xcrun simctl spawn "$UDID" defaults delete "$BUNDLE_ID" "$DEFAULTS_KEY" 2>/dev/null || true
  log "cleared session (app will show auth gate)"
}

# Screenshot. Waits a beat so SwiftUI settles. Usage: shot <name>
cmd_shot() {
  local name="${1:-shot}"
  sleep "${WAIT:-4}"
  xcrun simctl io "$UDID" screenshot "$SHOTS/$name.png" >/dev/null
  log "wrote $SHOTS/$name.png"
}

# Full flow to the authenticated Discover screen.
cmd_up() {
  cmd_boot; cmd_build; cmd_install; cmd_bypass; cmd_launch; cmd_shot "discover"
  log "done -> $SHOTS/discover.png"
}

# Full flow to the signed-out auth screen.
cmd_auth() {
  cmd_boot; cmd_build; cmd_install; cmd_logout; cmd_launch; cmd_shot "auth"
  log "done -> $SHOTS/auth.png"
}

cmd_help() {
  cat <<EOF
driver.sh — InspireCreativityApp iOS simulator harness

  up            boot + build + install + bypass auth + launch + screenshot Discover
  auth          boot + build + install + clear session + launch + screenshot auth gate
  build         xcodebuild the app for the simulator
  boot          boot the simulator + open Simulator.app
  install       install the built .app onto the booted sim
  launch        launch the app
  bypass        inject a local session (boots past the auth gate, no credentials)
  logout        clear the injected/real session (shows the auth gate)
  shot <name>   screenshot to \$SHOTS/<name>.png (honors \$WAIT, default 4s)
  terminate     kill the running app

Env: DEVICE (default 'iPhone 16 Plus'), UDID, DD, SHOTS, WAIT, BUNDLE_ID, SCHEME
Current: UDID=$UDID  SHOTS=$SHOTS  APP=$APP
EOF
}

case "${1:-help}" in
  up) cmd_up ;;
  auth) cmd_auth ;;
  build) cmd_build ;;
  boot) cmd_boot ;;
  install) cmd_install ;;
  launch) cmd_launch ;;
  bypass) cmd_bypass ;;
  logout) cmd_logout ;;
  shot) shift; cmd_shot "$@" ;;
  terminate) cmd_terminate ;;
  help|-h|--help) cmd_help ;;
  *) echo "unknown command: $1"; cmd_help; exit 1 ;;
esac
