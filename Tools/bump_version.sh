#!/bin/sh
# bump_version.sh — bump the app's marketing version (CFBundleShortVersionString).
#
# Edits MARKETING_VERSION directly in the Xcode project (both app build
# configs). We deliberately do NOT use `agvtool new-marketing-version`: this
# project resolves CFBundleShortVersionString from $(MARKETING_VERSION) in
# Info.plist, and agvtool would overwrite that indirection with a literal while
# leaving the build setting stale (verified). A direct pbxproj edit keeps a
# single source of truth.
#
# The build NUMBER is owned by Xcode Cloud (ci_scripts/ci_pre_xcodebuild.sh);
# this script only touches the human-facing marketing version. It does not
# commit — the caller (the loop or you) commits and merges to `release` to ship.
#
# Usage (run from the repo root):
#   Tools/bump_version.sh 1.4       # set an explicit marketing version
#   Tools/bump_version.sh --minor   # 1.3   -> 1.4
#   Tools/bump_version.sh --major   # 1.3   -> 2.0
#   Tools/bump_version.sh --patch   # 1.3   -> 1.3.1 ;  1.3.1 -> 1.3.2
#
set -eu

PBXPROJ="${PBXPROJ:-InspireCreativityApp.xcodeproj/project.pbxproj}"

die() { printf 'bump_version: %s\n' "$*" >&2; exit 1; }

[ -f "$PBXPROJ" ] || die "project file not found at '$PBXPROJ' (run from the repo root, or set \$PBXPROJ)."
[ "$#" -eq 1 ]    || die "usage: bump_version.sh <version|--major|--minor|--patch>"

# Current MARKETING_VERSION — require every occurrence to agree.
current="$(grep -Eo 'MARKETING_VERSION = [^;]+;' "$PBXPROJ" \
  | sed -E 's/.*= (.*);/\1/' | sort -u)"
[ -n "$current" ] || die "no MARKETING_VERSION found in $PBXPROJ."
if [ "$(printf '%s\n' "$current" | grep -c .)" -ne 1 ]; then
  die "found differing MARKETING_VERSION values; resolve by hand:
$current"
fi

# Require a clean dotted-decimal (2 or 3 components, no leading-zero components),
# so the arithmetic below can't hit octal/garbage input (e.g. "1.08", "1.2.3.4").
echo "$current" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$' \
  || die "current MARKETING_VERSION '$current' is not N.N or N.N.N — bump by hand."
case "$current" in
  0[0-9]*|*.0[0-9]*) die "current MARKETING_VERSION '$current' has a leading-zero component — bump by hand." ;;
esac

# Split current into major.minor[.patch] using POSIX parameter expansion.
major="${current%%.*}"
rest="${current#*.}"; [ "$rest" = "$current" ] && rest=0
minor="${rest%%.*}"
patch="${rest#*.}";  [ "$patch" = "$rest" ] && patch=0

case "$1" in
  --major) new="$((major + 1)).0" ;;
  --minor) new="${major}.$((minor + 1))" ;;
  --patch) new="${major}.${minor}.$((patch + 1))" ;;
  -*)      die "unknown flag: $1" ;;
  *)       new="$1" ;;
esac

echo "$new" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$' || die "invalid version '$new' (want N.N or N.N.N)."
[ "$new" != "$current" ] || die "marketing version is already $current; nothing to do."

# Rewrite every MARKETING_VERSION line (app-target only in this project).
# Write through the existing file (cat >) rather than mv, so the pbxproj keeps
# its original permissions/inode — mktemp creates 0600 and mv would change the mode.
tmp="$(mktemp)"
sed -E "s/(MARKETING_VERSION = )[^;]+;/\1${new};/" "$PBXPROJ" > "$tmp"
cat "$tmp" > "$PBXPROJ"
rm -f "$tmp"

# Verify the edit landed and is consistent.
after="$(grep -Eo 'MARKETING_VERSION = [^;]+;' "$PBXPROJ" \
  | sed -E 's/.*= (.*);/\1/' | sort -u)"
[ "$after" = "$new" ] || die "post-edit verification failed (file shows '$after', wanted '$new')."

echo "bump_version: MARKETING_VERSION $current -> $new"
echo "bump_version: build number is set by Xcode Cloud; commit and merge to 'release' to ship."
