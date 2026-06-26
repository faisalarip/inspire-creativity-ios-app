#!/usr/bin/env python3
"""Poll App Store Connect for the latest Xcode Cloud build run and report status.

Part of the autonomous dev loop (see docs/loop/README.md). After the loop pushes
to the `release` branch and Xcode Cloud starts a run, this polls the App Store
Connect API until the run reaches a terminal state, then prints a one-line
summary and exits with a status-coded return value the loop consumes.

Credentials come from the environment (never hard-coded, never committed):

    ASC_KEY_ID     the App Store Connect API key id          (e.g. "2X9R4HXF34")
    ASC_ISSUER_ID  the issuer id, a UUID                       (Users & Access ▸
                                                                Integrations ▸ ASC API)
    ASC_KEY_PATH   filesystem path to the .p8 private key      (kept OUTSIDE the repo)

Usage (run from anywhere; reads only the network + env):

    xcode_cloud_status.py --product InspireCreativityApp
    xcode_cloud_status.py --product InspireCreativityApp --workflow Release
    xcode_cloud_status.py --product InspireCreativityApp --watch          # poll to terminal
    xcode_cloud_status.py --product InspireCreativityApp --watch --interval 30 --timeout 3600

Exit codes:
    0   latest run SUCCEEDED
    1   latest run FAILED / ERRORED / CANCELED / SKIPPED, or an auth/API error
    2   no terminal result yet (one-shot found a run still PENDING/RUNNING, or
        --watch hit --timeout) — i.e. "ask again later", not a failure

Dependency: PyJWT  ->  pip3 install pyjwt cryptography
This is a LOCAL tool; Xcode Cloud itself needs none of this.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ASC_BASE = "https://api.appstoreconnect.apple.com"
ASC_AUDIENCE = "appstoreconnect-v1"
TOKEN_TTL_SECONDS = 20 * 60  # ASC rejects tokens older than 20 minutes.

# App Store Connect ciBuildRun vocabulary.
TERMINAL_PROGRESS = "COMPLETE"          # executionProgress: PENDING | RUNNING | COMPLETE
STATUS_SUCCEEDED = "SUCCEEDED"          # completionStatus: SUCCEEDED | FAILED | ERRORED
                                        #                   | CANCELED | SKIPPED
EXIT_OK = 0
EXIT_FAIL = 1
EXIT_PENDING = 2


# ──────────────────────────────────────────────────────────────────────────
# Pure logic (no network, no JWT) — covered by Tools/test_xcode_cloud_status.py
# ──────────────────────────────────────────────────────────────────────────

def summarize_run(run: dict) -> dict:
    """Flatten a ciBuildRuns resource into the fields we report on."""
    attrs = run.get("attributes", {}) or {}
    return {
        "id": run.get("id"),
        "number": attrs.get("number"),
        "progress": attrs.get("executionProgress"),
        "status": attrs.get("completionStatus"),
        "started": attrs.get("startedDate"),
        "finished": attrs.get("finishedDate"),
        "is_pr": attrs.get("isPullRequestBuild"),
    }


def pick_latest(runs: list) -> dict | None:
    """Return the run with the highest build number (newest), or None."""
    numbered = [r for r in runs if (r.get("attributes") or {}).get("number") is not None]
    if not numbered:
        return runs[0] if runs else None
    return max(numbered, key=lambda r: r["attributes"]["number"])


def workflow_names_by_id(included: list) -> dict:
    """Map ciWorkflows resource id -> workflow name, from an `included` array."""
    out = {}
    for res in included or []:
        if res.get("type") == "ciWorkflows":
            out[res.get("id")] = (res.get("attributes") or {}).get("name")
    return out


def run_workflow_id(run: dict) -> str | None:
    rel = (run.get("relationships") or {}).get("workflow") or {}
    return (rel.get("data") or {}).get("id")


def filter_by_workflow(runs: list, included: list, workflow_name: str) -> list:
    """Keep only runs whose related workflow name matches (case-insensitive)."""
    names = workflow_names_by_id(included)
    want = workflow_name.casefold()
    return [r for r in runs if (names.get(run_workflow_id(r)) or "").casefold() == want]


def is_terminal(summary: dict) -> bool:
    return summary.get("progress") == TERMINAL_PROGRESS


def exit_code_for(summary: dict) -> int:
    if not is_terminal(summary):
        return EXIT_PENDING
    return EXIT_OK if summary.get("status") == STATUS_SUCCEEDED else EXIT_FAIL


def format_summary(summary: dict, product: str) -> str:
    num = summary.get("number")
    label = f"{product} build #{num}" if num is not None else f"{product} build"
    if not is_terminal(summary):
        return f"{label}: {summary.get('progress') or 'UNKNOWN'} (not finished yet)"
    status = summary.get("status") or "UNKNOWN"
    icon = "✅" if status == STATUS_SUCCEEDED else "❌"
    tail = f" · finished {summary['finished']}" if summary.get("finished") else ""
    return f"{icon} {label}: {status}{tail}"


# ──────────────────────────────────────────────────────────────────────────
# Auth + HTTP (network) — validated against the first real run, per spec §9
# ──────────────────────────────────────────────────────────────────────────

def make_jwt(key_id: str, issuer_id: str, private_key_pem: str, now: int | None = None) -> str:
    """Sign a short-lived ES256 JWT for the App Store Connect API."""
    try:
        import jwt  # PyJWT; lazy so the pure logic + tests run without it.
    except ImportError as exc:  # pragma: no cover - environment-dependent
        raise SystemExit(
            "PyJWT is required for the App Store Connect API.\n"
            "  Install it with:  pip3 install pyjwt cryptography"
        ) from exc
    issued = int(time.time()) if now is None else now
    payload = {
        "iss": issuer_id,
        "iat": issued,
        "exp": issued + TOKEN_TTL_SECONDS,
        "aud": ASC_AUDIENCE,
    }
    return jwt.encode(
        payload, private_key_pem, algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def token_from_env() -> str:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    missing = [n for n, v in (
        ("ASC_KEY_ID", key_id), ("ASC_ISSUER_ID", issuer_id), ("ASC_KEY_PATH", key_path),
    ) if not v]
    if missing:
        raise SystemExit(
            "missing required env var(s): " + ", ".join(missing) +
            "\nSee docs/ci/xcode-cloud-setup.md for how to create the ASC API key."
        )
    try:
        with open(os.path.expanduser(key_path), "r", encoding="utf-8") as fh:
            private_key_pem = fh.read()
    except OSError as exc:
        raise SystemExit(f"cannot read ASC_KEY_PATH ({key_path}): {exc}") from exc
    return make_jwt(key_id, issuer_id, private_key_pem)


class AscError(Exception):
    """A recoverable App Store Connect API / transport error (possibly transient)."""


def asc_get(path: str, token: str, params: dict | None = None) -> dict:
    url = ASC_BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    req = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise AscError(f"ASC API {exc.code} for {path}: {body[:500]}") from exc
    except urllib.error.URLError as exc:
        raise AscError(f"network error calling ASC API ({path}): {exc.reason}") from exc


def find_product_id(token: str, product_name: str) -> str:
    data = asc_get("/v1/ciProducts", token, {"limit": 200}).get("data", [])
    want = product_name.casefold()
    for product in data:
        if ((product.get("attributes") or {}).get("name") or "").casefold() == want:
            return product["id"]
    names = ", ".join(sorted((p.get("attributes") or {}).get("name") or "?" for p in data)) or "(none)"
    raise SystemExit(f"no Xcode Cloud product named '{product_name}'. Found: {names}")


def fetch_latest_run(token: str, product_id: str, workflow_name: str | None) -> dict | None:
    payload = asc_get(
        f"/v1/ciProducts/{product_id}/buildRuns", token,
        {"limit": 200, "sort": "-number", "include": "workflow"},
    )
    runs = payload.get("data", [])
    if workflow_name:
        runs = filter_by_workflow(runs, payload.get("included", []), workflow_name)
    return pick_latest(runs)


# ──────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────

def check_once(token: str, product_id: str, args) -> tuple[dict | None, int]:
    run = fetch_latest_run(token, product_id, args.workflow)
    if run is None:
        scope = f" for workflow '{args.workflow}'" if args.workflow else ""
        print(f"{args.product}: no build runs found{scope}.")
        return None, EXIT_PENDING
    summary = summarize_run(run)
    print(format_summary(summary, args.product))
    return summary, exit_code_for(summary)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Report the latest Xcode Cloud build run status.")
    parser.add_argument("--product", required=True,
                        help="Xcode Cloud product name (usually the app name, e.g. InspireCreativityApp).")
    parser.add_argument("--workflow", default=None,
                        help="Only consider runs of this workflow (e.g. Release).")
    parser.add_argument("--watch", action="store_true",
                        help="Poll until the latest run reaches a terminal state.")
    parser.add_argument("--interval", type=int, default=30, help="Seconds between polls with --watch.")
    parser.add_argument("--timeout", type=int, default=3600, help="Give up after this many seconds with --watch.")
    args = parser.parse_args(argv)

    # Mint a fresh JWT per request. Signing is cheap and local, and it keeps us
    # well under the ASC 20-minute token lifetime even during a long --watch
    # (a single reused token would expire mid-watch and 401 -> false failure).
    try:
        product_id = find_product_id(token_from_env(), args.product)
    except AscError as exc:
        print(f"{args.product}: {exc}", file=sys.stderr)
        return EXIT_FAIL

    if not args.watch:
        try:
            _, code = check_once(token_from_env(), product_id, args)
        except AscError as exc:
            print(f"{args.product}: {exc}", file=sys.stderr)
            return EXIT_FAIL
        return code

    deadline = time.time() + args.timeout
    while True:
        try:
            summary, code = check_once(token_from_env(), product_id, args)
            if summary is not None and is_terminal(summary):
                return code
        except AscError as exc:
            # Transient (network blip, 5xx, brief 401) — keep polling until --timeout.
            print(f"{args.product}: transient API error, will retry — {exc}", file=sys.stderr)
        if time.time() >= deadline:
            print(f"{args.product}: timed out after {args.timeout}s without a terminal result.", file=sys.stderr)
            return EXIT_PENDING
        time.sleep(max(1, args.interval))


if __name__ == "__main__":
    sys.exit(main())
