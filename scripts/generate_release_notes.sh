#!/bin/sh
# generate_release_notes.sh — draft user-facing release notes from git history.
#
# Emits one "- ..." bullet per user-facing commit (feat/fix conventional
# commits) since the previous release tag, newest first. Internal-only scopes
# (docs, chore, ci, test, refactor, style, marketing, analytics plumbing) are
# excluded. The output is a DRAFT: the release flow (.claude/commands/release.md)
# reviews and rewrites it for the App Store before it is used as "What's New".
#
# Base ref resolution, first match wins:
#   1. --from <ref>                      explicit base (tag, sha, branch)
#   2. newest tag matching  v*-ios       this repo's iOS release tag pattern
#   3. newest tag matching  v*           any release tag
#   4. (none)                            the last 30 commits
#
# Usage (run from the repo root):
#   scripts/generate_release_notes.sh                # notes since last release
#   scripts/generate_release_notes.sh --from v1.3-ios
#   scripts/generate_release_notes.sh --max 8
#
# Exit codes: 0 success (even if zero bullets — caller decides), 1 usage/git error.
set -eu

FROM=""
MAX=10
while [ "$#" -gt 0 ]; do
  case "$1" in
    --from) [ "$#" -ge 2 ] || { echo "generate_release_notes: --from needs a ref" >&2; exit 1; }
            FROM="$2"; shift 2 ;;
    --max)  [ "$#" -ge 2 ] || { echo "generate_release_notes: --max needs a number" >&2; exit 1; }
            MAX="$2"; shift 2 ;;
    *) echo "generate_release_notes: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "generate_release_notes: not a git repository" >&2; exit 1; }

if [ -z "$FROM" ]; then
  FROM="$(git tag --list 'v*-ios' --sort=-creatordate 2>/dev/null | head -1 || true)"
fi
if [ -z "$FROM" ]; then
  FROM="$(git tag --list 'v*' --sort=-creatordate 2>/dev/null | head -1 || true)"
fi

if [ -n "$FROM" ]; then
  RANGE="${FROM}..HEAD"
else
  RANGE="HEAD~30..HEAD"
  # Shallow/short histories: fall back to whatever exists.
  git rev-parse -q --verify "HEAD~30" >/dev/null 2>&1 || RANGE="HEAD"
fi

# Keep feat/fix subjects; drop internal scopes; strip the conventional prefix;
# capitalize the first letter; de-duplicate while preserving order.
git log --no-merges --pretty='format:%s' "$RANGE" -- . 2>/dev/null \
  | grep -E '^(feat|fix)(\([^)]*\))?!?:' \
  | grep -Ev '^(feat|fix)\((docs|chore|ci|test|tests|refactor|style|build|marketing|superpowers|analytics|infra|tooling)\)' \
  | sed -E 's/^(feat|fix)(\([^)]*\))?!?:[[:space:]]*//' \
  | awk '!seen[$0]++' \
  | head -"$MAX" \
  | awk '{ printf "- %s%s\n", toupper(substr($0, 1, 1)), substr($0, 2) }' \
  || true
