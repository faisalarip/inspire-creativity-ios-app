#!/usr/bin/env python3
"""App Store Connect screenshot management: inspect and replace a version's
screenshot sets.

Companion to Tools/asc_release.py. That tool's `validate` can tell you a
listing has no screenshots; this one can actually fix it. Written after Apple
rejected Inspire Creativity 2.2.0 under Guideline 2.3.10 ("remove non-iOS
status bar images"), which is a screenshot-only defect that needs no new build
but previously had no path through the pipeline at all.

Credentials come from the environment, same as the sibling tools:

    ASC_KEY_ID      App Store Connect API key id
    ASC_ISSUER_ID   issuer id (UUID)
    ASC_KEY_PATH    path to the .p8 private key, OUTSIDE the repo

Subcommands:

    list     --version 2.2.0
             show every set, its display type, and each screenshot with
             filename, dimensions and asset delivery state

    replace  --version 2.2.0 --display-type APP_IPHONE_65 --dir path/to/pngs
             upload every PNG in --dir to that set, in sorted filename order,
             then delete the screenshots that were there before. Existing ones
             are removed only after the new uploads report COMPLETE, so a
             failure part-way leaves the old listing intact rather than an
             empty one.

Upload is the ASC three-step: reserve (POST, which returns uploadOperations),
PUT each byte range to the returned URL with its prescribed headers, then
commit with uploaded=true plus the file's MD5 as sourceFileChecksum.

Exit codes: 0 = success; 1 = hard failure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xcode_cloud_status import ASC_BASE, AscError, asc_get, token_from_env  # noqa: E402
from asc_release import asc_write, find_app_id, find_version  # noqa: E402
import asc_release  # noqa: E402

EXIT_OK, EXIT_FAIL = 0, 1
POLL_SECONDS, POLL_TRIES = 3, 40


def asc_delete(path: str, token: str) -> None:
    req = urllib.request.Request(ASC_BASE + path, method="DELETE",
                                 headers={"Authorization": f"Bearer {token}"})
    try:
        urllib.request.urlopen(req, timeout=30).read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise AscError(f"ASC API {exc.code} for DELETE {path}: {detail[:400]}") from exc


def screenshot_sets(token: str, version_id: str) -> list[dict]:
    out = []
    locs = asc_get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
                   token, {"limit": 20}).get("data", [])
    for loc in locs:
        payload = asc_get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets",
                          token, {"include": "appScreenshots", "limit": 20})
        shots = {i["id"]: i["attributes"]
                 for i in payload.get("included", []) if i["type"] == "appScreenshots"}
        for s in payload.get("data", []):
            refs = ((s.get("relationships") or {}).get("appScreenshots") or {}).get("data") or []
            out.append({
                "locale": loc["attributes"]["locale"],
                "setId": s["id"],
                "displayType": s["attributes"]["screenshotDisplayType"],
                "shots": [dict(id=r["id"], **shots.get(r["id"], {})) for r in refs],
            })
    return out


def upload_one(token: str, set_id: str, path: str) -> str:
    """Reserve, PUT, commit. Returns the new appScreenshot id."""
    data = open(path, "rb").read()
    name = os.path.basename(path)
    reserved = asc_write("POST", "/v1/appScreenshots", token, {"data": {
        "type": "appScreenshots",
        "attributes": {"fileSize": len(data), "fileName": name},
        "relationships": {"appScreenshotSet": {
            "data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    shot_id = reserved["id"]

    for op in reserved["attributes"].get("uploadOperations") or []:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op.get("requestHeaders") or []:
            req.add_header(h["name"], h["value"])
        try:
            urllib.request.urlopen(req, timeout=180).read()
        except urllib.error.HTTPError as exc:
            raise AscError(f"upload PUT failed for {name}: {exc.code} "
                           f"{exc.read().decode('utf-8', 'replace')[:300]}") from exc

    asc_write("PATCH", f"/v1/appScreenshots/{shot_id}", token, {"data": {
        "type": "appScreenshots", "id": shot_id,
        "attributes": {"uploaded": True,
                       "sourceFileChecksum": hashlib.md5(data).hexdigest()},
    }})
    return shot_id


def await_complete(token: str, shot_ids: list[str]) -> None:
    """Block until every asset reports COMPLETE; raise on FAILED or timeout."""
    pending = set(shot_ids)
    for _ in range(POLL_TRIES):
        for sid in sorted(pending):
            attrs = asc_get(f"/v1/appScreenshots/{sid}", token, {})["data"]["attributes"]
            state = ((attrs.get("assetDeliveryState") or {}).get("state"))
            if state == "COMPLETE":
                pending.discard(sid)
            elif state == "FAILED":
                errs = (attrs.get("assetDeliveryState") or {}).get("errors")
                raise AscError(f"asset delivery FAILED for {attrs.get('fileName')}: {errs}")
        if not pending:
            return
        time.sleep(POLL_SECONDS)
    raise AscError(f"timed out waiting for {len(pending)} screenshot(s) to process")


def cmd_list(token: str, app_id: str, args) -> int:
    version = find_version(token, app_id, args.version)
    if not version:
        print(f"no App Store version {args.version}")
        return EXIT_FAIL
    for s in screenshot_sets(token, version["id"]):
        print(f"{s['locale']}  {s['displayType']}  ({len(s['shots'])})  set={s['setId']}")
        for n, sh in enumerate(s["shots"], 1):
            ia = sh.get("imageAsset") or {}
            state = (sh.get("assetDeliveryState") or {}).get("state")
            print(f"   {n}. {sh.get('fileName'):36} {ia.get('width')}x{ia.get('height')}  {state}")
    return EXIT_OK


def cmd_replace(token: str, app_id: str, args) -> int:
    version = find_version(token, app_id, args.version)
    if not version:
        print(f"no App Store version {args.version}")
        return EXIT_FAIL
    sets = [s for s in screenshot_sets(token, version["id"])
            if s["displayType"] == args.display_type
            and (args.locale is None or s["locale"] == args.locale)]
    if len(sets) != 1:
        print(f"expected exactly 1 matching set, found {len(sets)}")
        return EXIT_FAIL
    target = sets[0]

    files = sorted(f for f in os.listdir(args.dir) if f.lower().endswith(".png"))
    if not files:
        print(f"no PNGs in {args.dir}")
        return EXIT_FAIL
    if len(files) > 10:
        print(f"{len(files)} files; the App Store allows at most 10 per set")
        return EXIT_FAIL

    old_ids = [sh["id"] for sh in target["shots"]]
    print(f"set {target['displayType']} ({target['locale']}): "
          f"{len(old_ids)} existing -> {len(files)} new")

    new_ids = []
    for f in files:
        sid = upload_one(token, target["setId"], os.path.join(args.dir, f))
        new_ids.append(sid)
        print(f"  ↑ {f}")
    await_complete(token, new_ids)
    print("  all new screenshots COMPLETE")

    # Only now is it safe to drop the originals.
    for sid in old_ids:
        asc_delete(f"/v1/appScreenshots/{sid}", token)
    print(f"  removed {len(old_ids)} previous screenshot(s)")

    asc_write("PATCH", f"/v1/appScreenshotSets/{target['setId']}/relationships/appScreenshots",
              token, {"data": [{"type": "appScreenshots", "id": i} for i in new_ids]})
    print("  order set to sorted filename order")
    return EXIT_OK


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--bundle-id", default=asc_release.BUNDLE_ID)
    common.add_argument("--version", required=True)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", parents=[common])
    rep = sub.add_parser("replace", parents=[common])
    rep.add_argument("--display-type", required=True,
                     help="e.g. APP_IPHONE_65, APP_IPAD_PRO_3GEN_129")
    rep.add_argument("--dir", required=True, help="directory of PNGs, uploaded in sorted order")
    rep.add_argument("--locale", default=None, help="restrict to one locale (default: all)")
    args = parser.parse_args(argv)

    asc_release.BUNDLE_ID = args.bundle_id
    try:
        token = token_from_env()
        app_id = find_app_id(token)
        return {"list": cmd_list, "replace": cmd_replace}[args.cmd](token, app_id, args)
    except (AscError, SystemExit) as exc:
        print(f"error: {exc}")
        return EXIT_FAIL


if __name__ == "__main__":
    sys.exit(main())
