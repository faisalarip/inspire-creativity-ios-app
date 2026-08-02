#!/usr/bin/env python3
"""App Store Connect release gate: inspect, validate, and (when authorized)
submit a release for App Review.

Companion to Tools/xcode_cloud_status.py (which watches the Xcode Cloud RUN);
this tool covers what happens AFTER the run uploads a build:

    build processing → version association → metadata validation
        → release gate → App Review submission

Credentials come from the environment (same names as the status poller —
never hard-coded, never committed):

    ASC_KEY_ID      App Store Connect API key id
    ASC_ISSUER_ID   issuer id (UUID)
    ASC_KEY_PATH    path to the .p8 private key, OUTSIDE the repo

The key needs the App Manager role for create-version / attach-build /
set-notes / submit (Developer is read-only and only enough for `status`).

Subcommands (all idempotent — safe to re-run):

    status                              latest builds + App Store versions
    validate      --version 2.2.0       is this version ready to submit?
    create-version --version 2.2.0      create the ASC version record if absent
    attach-build  --version 2.2.0       attach newest VALID build of that train
    set-notes     --version 2.2.0 --file notes.txt    set en-US "What's New"
    submit        --version 2.2.0       submit for App Review — GATED, see below

The submission gate: `submit` refuses to act unless authorized by ONE of
  * --authorize on the command line, or
  * AUTO_SUBMIT=true in the environment, or
  * AUTO_SUBMIT=true in scripts/release.env (the standing project setting).
It also refuses to double-submit: an existing open review submission for the
app makes `submit` a no-op that reports the existing submission.

Exit codes: 0 = success / already in the desired state; 1 = hard failure or
validation not passed; 2 = blocked awaiting authorization or processing.

Dependency: PyJWT  ->  pip3 install pyjwt cryptography
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xcode_cloud_status import ASC_BASE, AscError, asc_get, token_from_env  # noqa: E402

# Default app; override per-call with --bundle-id — the ASC team key sees the
# whole portfolio (e.g. com.faisalarip.hydrate, com.faisalnurarif.tapescan).
BUNDLE_ID = "com.inspirecreativity"
PLATFORM = "IOS"
RELEASE_ENV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "release.env")

EXIT_OK, EXIT_FAIL, EXIT_BLOCKED = 0, 1, 2

# appStoreVersions.appVersionState values from which a submission can proceed.
SUBMITTABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
# reviewSubmissions.state values that mean "a submission is already in flight".
OPEN_SUBMISSION_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}


def asc_write(method: str, path: str, token: str, body: dict) -> dict:
    """POST/PATCH JSON to the ASC API (asc_get's write-side sibling)."""
    req = urllib.request.Request(
        ASC_BASE + path,
        data=json.dumps(body).encode("utf-8"),
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise AscError(f"ASC API {exc.code} for {method} {path}: {detail[:600]}") from exc
    except urllib.error.URLError as exc:
        raise AscError(f"network error calling ASC API ({method} {path}): {exc.reason}") from exc


# ── lookups ────────────────────────────────────────────────────────────────

def find_app_id(token: str) -> str:
    data = asc_get("/v1/apps", token, {"filter[bundleId]": BUNDLE_ID}).get("data", [])
    if not data:
        raise SystemExit(f"no App Store Connect app found for bundle id {BUNDLE_ID}")
    return data[0]["id"]


def latest_builds(token: str, app_id: str, limit: int = 10) -> list[dict]:
    payload = asc_get("/v1/builds", token, {
        "filter[app]": app_id, "sort": "-uploadedDate", "limit": limit,
        "include": "preReleaseVersion",
    })
    trains = {i["id"]: (i.get("attributes") or {})
              for i in payload.get("included", []) if i.get("type") == "preReleaseVersions"}
    out = []
    for b in payload.get("data", []):
        attrs = b.get("attributes") or {}
        train_ref = ((b.get("relationships") or {}).get("preReleaseVersion") or {}).get("data") or {}
        train = trains.get(train_ref.get("id"), {})
        out.append({
            "id": b["id"],
            "buildNumber": attrs.get("version"),
            "train": train.get("version"),
            "platform": train.get("platform"),
            "processingState": attrs.get("processingState"),
            "uploaded": attrs.get("uploadedDate"),
            "expired": attrs.get("expired"),
            "usesNonExemptEncryption": attrs.get("usesNonExemptEncryption"),
        })
    return out


def app_store_versions(token: str, app_id: str, limit: int = 5) -> list[dict]:
    payload = asc_get(f"/v1/apps/{app_id}/appStoreVersions", token, {
        "limit": limit, "filter[platform]": PLATFORM, "include": "build",
    })
    build_nums = {i["id"]: (i.get("attributes") or {}).get("version")
                  for i in payload.get("included", []) if i.get("type") == "builds"}
    out = []
    for v in payload.get("data", []):
        attrs = v.get("attributes") or {}
        build_ref = ((v.get("relationships") or {}).get("build") or {}).get("data") or {}
        out.append({
            "id": v["id"],
            "versionString": attrs.get("versionString"),
            "state": attrs.get("appVersionState") or attrs.get("appStoreState"),
            "created": attrs.get("createdDate"),
            "buildId": build_ref.get("id"),
            "buildNumber": build_nums.get(build_ref.get("id")),
        })
    return out


def find_version(token: str, app_id: str, version_string: str) -> dict | None:
    return next((v for v in app_store_versions(token, app_id, limit=20)
                 if v["versionString"] == version_string), None)


def open_review_submissions(token: str, app_id: str) -> list[dict]:
    payload = asc_get("/v1/reviewSubmissions", token, {
        "filter[app]": app_id, "limit": 20,
    })
    return [{"id": s["id"], "state": (s.get("attributes") or {}).get("state"),
             "platform": (s.get("attributes") or {}).get("platform")}
            for s in payload.get("data", [])
            if (s.get("attributes") or {}).get("state") in OPEN_SUBMISSION_STATES]


# ── subcommands ────────────────────────────────────────────────────────────

def cmd_status(token: str, app_id: str, _args) -> int:
    print(f"App: {BUNDLE_ID}  (ASC id {app_id})")
    print("\nLatest builds (newest first):")
    builds = latest_builds(token, app_id)
    if not builds:
        print("  (none uploaded)")
    for b in builds:
        flag = "" if b["usesNonExemptEncryption"] is not None else "  ⚠ export compliance missing"
        print(f"  {b['platform'] or '?':>5}  {b['train'] or '?':>8}  build {b['buildNumber']:>5}"
              f"  {b['processingState']:<10}"
              f"  uploaded {b['uploaded']}{'  (expired)' if b['expired'] else ''}{flag}")
    print("\nApp Store versions:")
    for v in app_store_versions(token, app_id):
        build = f"build {v['buildNumber']}" if v["buildNumber"] else "no build attached"
        print(f"  {v['versionString']:>8}  {v['state']:<28}  {build}")
    subs = open_review_submissions(token, app_id)
    print("\nOpen review submissions:")
    print("  (none)" if not subs else "\n".join(f"  {s['id']}  {s['state']}  {s['platform']}" for s in subs))
    return EXIT_OK


def cmd_validate(token: str, app_id: str, args) -> int:
    problems, warnings = [], []
    version = find_version(token, app_id, args.version)
    if version is None:
        print(f"❌ App Store version {args.version} does not exist.")
        print(f"   Create it with: Tools/asc_release.py create-version --version {args.version}")
        return EXIT_FAIL
    if version["state"] not in SUBMITTABLE_STATES:
        problems.append(f"version state is {version['state']} — not submittable "
                        f"(need one of {', '.join(sorted(SUBMITTABLE_STATES))})")
    if not version["buildId"]:
        problems.append("no build attached — run: Tools/asc_release.py attach-build "
                        f"--version {args.version}")
    else:
        build = next((b for b in latest_builds(token, app_id, 50) if b["id"] == version["buildId"]), None)
        if build is None:
            warnings.append("attached build not in the 50 most recent uploads (unusual, verify manually)")
        else:
            if build["processingState"] != "VALID":
                problems.append(f"attached build {build['buildNumber']} processingState is "
                                f"{build['processingState']} (need VALID)")
            if build["usesNonExemptEncryption"] is None:
                problems.append("attached build is missing export compliance "
                                "(ITSAppUsesNonExemptEncryption should carry it — inspect in ASC)")
            if build["expired"]:
                problems.append(f"attached build {build['buildNumber']} is expired")
    locs = asc_get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
                   token, {"limit": 10}).get("data", [])
    for loc in locs:
        attrs = loc.get("attributes") or {}
        if not (attrs.get("whatsNew") or "").strip():
            warnings.append(f"locale {attrs.get('locale')}: 'What's New' is empty — "
                            f"set it with: Tools/asc_release.py set-notes --version {args.version} --file <notes>")

    print(f"Version {args.version}  state={version['state']}  "
          f"build={version['buildNumber'] or '—'}")
    for w in warnings:
        print(f"  ⚠ {w}")
    for p in problems:
        print(f"  ❌ {p}")
    if problems:
        print("❌ NOT READY for submission.")
        return EXIT_FAIL
    print("✅ READY for submission." if not warnings else "✅ READY (with warnings above).")
    return EXIT_OK


def cmd_create_version(token: str, app_id: str, args) -> int:
    if find_version(token, app_id, args.version):
        print(f"App Store version {args.version} already exists — nothing to do.")
        return EXIT_OK
    asc_write("POST", "/v1/appStoreVersions", token, {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": PLATFORM, "versionString": args.version},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})
    print(f"✅ Created App Store version {args.version} ({PLATFORM}).")
    return EXIT_OK


def cmd_attach_build(token: str, app_id: str, args) -> int:
    version = find_version(token, app_id, args.version)
    if version is None:
        print(f"❌ version {args.version} does not exist (create-version first).")
        return EXIT_FAIL
    candidates = [b for b in latest_builds(token, app_id, 50)
                  if b["processingState"] == "VALID" and not b["expired"]
                  and b["platform"] == PLATFORM
                  and (b["train"] == args.version or args.any_train)]
    if not candidates:
        print(f"❌ no VALID, unexpired build found for train {args.version} "
              f"(pass --any-train to consider other trains). Still processing?")
        return EXIT_BLOCKED
    best = max(candidates, key=lambda b: int(b["buildNumber"] or 0))
    if version["buildId"] == best["id"]:
        print(f"Build {best['buildNumber']} already attached to {args.version} — nothing to do.")
        return EXIT_OK
    asc_write("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build", token,
              {"data": {"type": "builds", "id": best["id"]}})
    print(f"✅ Attached build {best['buildNumber']} (train {best['train']}) to version {args.version}.")
    return EXIT_OK


def cmd_set_notes(token: str, app_id: str, args) -> int:
    version = find_version(token, app_id, args.version)
    if version is None:
        print(f"❌ version {args.version} does not exist (create-version first).")
        return EXIT_FAIL
    with open(args.file, "r", encoding="utf-8") as fh:
        notes = fh.read().strip()
    if not notes:
        print(f"❌ {args.file} is empty.")
        return EXIT_FAIL
    locs = asc_get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
                   token, {"limit": 10}).get("data", [])
    target = next((l for l in locs if (l.get("attributes") or {}).get("locale") == args.locale), None)
    if target is None:
        print(f"❌ no {args.locale} localization on version {args.version}.")
        return EXIT_FAIL
    asc_write("PATCH", f"/v1/appStoreVersionLocalizations/{target['id']}", token, {"data": {
        "type": "appStoreVersionLocalizations", "id": target["id"],
        "attributes": {"whatsNew": notes},
    }})
    print(f"✅ 'What's New' ({args.locale}) set on {args.version} ({len(notes)} chars).")
    return EXIT_OK


def _submission_authorized(args) -> bool:
    if args.authorize:
        return True
    env = os.environ.get("AUTO_SUBMIT")
    if env is not None:
        # An explicit env setting (true OR false) overrides the standing file.
        return env.strip().lower() == "true"
    try:
        with open(RELEASE_ENV, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("AUTO_SUBMIT=") and not line.startswith("#"):
                    return line.split("=", 1)[1].strip().lower() == "true"
    except OSError:
        pass
    return False


def cmd_submit(token: str, app_id: str, args) -> int:
    # Idempotency: a submission that is already WITH Apple is never duplicated;
    # a leftover DRAFT (READY_FOR_REVIEW, i.e. created but not yet submitted)
    # is completed and reused instead of abandoned.
    draft = None
    for s in open_review_submissions(token, app_id):
        if s["state"] == "READY_FOR_REVIEW":
            draft = s
        else:
            print(f"A review submission is already with Apple ({s['id']}, state {s['state']}). "
                  "Not creating another.")
            return EXIT_OK

    code = cmd_validate(token, app_id, args)
    if code != EXIT_OK:
        print("Submission aborted: validation did not pass.")
        return code

    if not _submission_authorized(args):
        print("⏸ RELEASE GATE: submission NOT authorized.")
        print("   Authorize with ONE of: --authorize | AUTO_SUBMIT=true env | "
              "AUTO_SUBMIT=true in scripts/release.env")
        return EXIT_BLOCKED

    version = find_version(token, app_id, args.version)
    if draft:
        sub = {"id": draft["id"]}
        print(f"Reusing draft review submission {sub['id']}.")
    else:
        sub = asc_write("POST", "/v1/reviewSubmissions", token, {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": PLATFORM},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})["data"]
    items = asc_get(f"/v1/reviewSubmissions/{sub['id']}/items", token, {"limit": 10}).get("data", [])
    if not items:
        asc_write("POST", "/v1/reviewSubmissionItems", token, {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}},
            },
        }})
    asc_write("PATCH", f"/v1/reviewSubmissions/{sub['id']}", token, {"data": {
        "type": "reviewSubmissions", "id": sub["id"],
        "attributes": {"submitted": True},
    }})
    print(f"🚀 SUBMITTED {args.version} for App Review (submission {sub['id']}).")
    print("   Apple reviews; releasing after approval stays a human action in ASC.")
    return EXIT_OK


def main(argv=None) -> int:
    global BUNDLE_ID
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--bundle-id", default=BUNDLE_ID,
                        help="target app bundle id (default: %(default)s; the team key covers the whole portfolio)")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status", parents=[common])
    for name in ("validate", "create-version", "attach-build", "set-notes", "submit"):
        p = sub.add_parser(name, parents=[common])
        p.add_argument("--version", required=True, help="marketing version, e.g. 2.2.0")
        if name == "attach-build":
            p.add_argument("--any-train", action="store_true",
                           help="allow attaching the newest VALID build even from another train")
        if name == "set-notes":
            p.add_argument("--file", required=True, help="path to the What's New text")
            p.add_argument("--locale", default="en-US")
        if name == "submit":
            p.add_argument("--authorize", action="store_true",
                           help="explicit one-shot authorization (overrides AUTO_SUBMIT=false)")
    args = parser.parse_args(argv)
    BUNDLE_ID = args.bundle_id

    try:
        token = token_from_env()
        app_id = find_app_id(token)
        handler = {
            "status": cmd_status, "validate": cmd_validate,
            "create-version": cmd_create_version, "attach-build": cmd_attach_build,
            "set-notes": cmd_set_notes, "submit": cmd_submit,
        }[args.cmd]
        return handler(token, app_id, args)
    except AscError as exc:
        print(f"asc_release: {exc}", file=sys.stderr)
        return EXIT_FAIL


if __name__ == "__main__":
    sys.exit(main())
