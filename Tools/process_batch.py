#!/usr/bin/env python3
"""Process a finished generation workflow: extract results from the workflow
output wrapper, validate, remove any agent side-written orphans, then integrate.

Usage:  python3 Tools/process_batch.py <workflow_output_file>
Then build with xcodebuild to verify.
"""
import json, os, subprocess, sys
import catalog_lib as cl

SCRATCH = "/private/tmp/claude-502/-Users-faisalnurarif-Documents-PersonalApps-inspire-creativity-ios-app/a7acecb7-d061-4dff-9a67-27f6de123643/scratchpad"
BATCH = os.path.join(SCRATCH, "batch_current.json")
GEN = os.path.join(SCRATCH, "gen_current.json")
INTEGRATED = os.path.join(cl.ROOT, "Tools/integrated_ids.json")

def main():
    out = sys.argv[1]
    data = json.loads(open(out, encoding="utf-8").read())
    results = data.get("result", {}).get("results", data.get("results", []))
    spec = {s["id"]: s for s in json.load(open(BATCH, encoding="utf-8"))}

    clean = []
    for r in results:
        cid = r.get("id"); s = spec.get(cid); vs = r.get("viewSource") or ""
        probs = []
        if not s:
            probs.append("no spec")
        else:
            if "import SwiftUI" not in vs: probs.append("no import")
            # The main view struct is renamed to the (possibly disambiguated) typeName
            # by integrate_batch.normalize; here just require a View struct exists.
            if "struct " not in vs or ": View" not in vs: probs.append("no view struct")
            if "var demo" not in vs: probs.append("no demo")
            if s["isMetal"] and not (r.get("metalSource") or "").strip(): probs.append("no metal")
        if probs:
            print(f"  BAD {cid}: {probs}")
        else:
            clean.append(r)
    print(f"clean {len(clean)}/{len(results)}")
    json.dump(clean, open(GEN, "w"), ensure_ascii=False)

    # orphan scan (agent side-writes)
    done = set(json.load(open(INTEGRATED)))
    expected = set(cl.type_name(i) + ".swift" for i in done) | {
        "BespokeAnimations.swift", "BespokeCodeSamples.swift",
        "RubberBandSheetMorphView.swift", "GlassShatterSettleView.swift",
        "HeatMirageView.swift", "HeatMirage.metal"}
    for dp, _, fs in os.walk(os.path.join(cl.ROOT, "InspireCreativityApp/Animations/Catalog")):
        for f in fs:
            if f.endswith((".swift", ".metal")) and f not in expected:
                os.remove(os.path.join(dp, f)); print("removed orphan", f)

    subprocess.run(["python3", os.path.join(cl.ROOT, "Tools/integrate_batch.py"),
                    "--spec", BATCH, "--gen", GEN], cwd=cl.ROOT, check=True)

if __name__ == "__main__":
    main()
