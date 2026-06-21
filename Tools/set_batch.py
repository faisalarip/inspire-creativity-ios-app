#!/usr/bin/env python3
"""Set up the next bulk batch: pick the next N un-integrated catalog ids, write
their build spec to batch_current.json, and rewrite the generation workflow's
`const IDS = ...` line so re-invoking the script generates exactly this batch.

Usage:  python3 Tools/set_batch.py --count 32   |   --ids a,b,c
"""
import argparse, json, os, re
import catalog_lib as cl

SCRIPT = "/Users/faisalnurarif/.claude/projects/-Users-faisalnurarif-Documents-PersonalApps-inspire-creativity-ios-app-Tools/a7acecb7-d061-4dff-9a67-27f6de123643/workflows/scripts/animation-batch-generate-wf_34b2f54f-d76.js"
CURRENT = "/private/tmp/claude-502/-Users-faisalnurarif-Documents-PersonalApps-inspire-creativity-ios-app/a7acecb7-d061-4dff-9a67-27f6de123643/scratchpad/batch_current.json"
INTEGRATED = os.path.join(cl.ROOT, "Tools/integrated_ids.json")

ap = argparse.ArgumentParser()
ap.add_argument("--count", type=int, default=32)
ap.add_argument("--ids")
a = ap.parse_args()

catalog = cl.load_catalog()
done = set(json.load(open(INTEGRATED))) if os.path.exists(INTEGRATED) else set()
if a.ids:
    ids = [i.strip() for i in a.ids.split(",") if i.strip()]
else:
    ids = [c["id"] for c in catalog.values() if c["id"] not in done][:a.count]

specs = []
for cid in ids:
    c = catalog[cid]; s = dict(c)
    s["typeName"] = cl.type_name(cid)
    s["folder"] = cl.CATEGORY_FOLDER[c["category"]]
    s["isMetal"] = cl.is_metal(c["category"])
    s["tintHex"] = cl.CATEGORY_TINT[c["category"]]
    s["fileRelPath"] = cl.rel_swift_path(s)
    specs.append(s)
json.dump(specs, open(CURRENT, "w"), ensure_ascii=False, indent=1)

js = open(SCRIPT, encoding="utf-8").read()
js = re.sub(r'(?m)^const IDS = .*$', f'const IDS = {json.dumps(ids)}', js, count=1)
open(SCRIPT, "w", encoding="utf-8").write(js)

remaining = len([c for c in catalog.values() if c["id"] not in done]) - len(ids)
print(f"batch set: {len(ids)} ids -> batch_current.json + workflow IDS. remaining after: {remaining}")
print(",".join(ids))
