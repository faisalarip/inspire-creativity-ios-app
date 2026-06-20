#!/usr/bin/env python3
"""Build a batch spec (per-animation build data) for a set of catalog ids.

Usage:
  python3 Tools/prepare_batch.py --ids a,b,c --out <path.json>
  python3 Tools/prepare_batch.py --category Gestures --count 18 --out <path.json>
"""
import argparse, json, os, sys
import catalog_lib as cl

INTEGRATED = os.path.join(cl.ROOT, "Tools/integrated_ids.json")

def integrated_set():
    return set(json.load(open(INTEGRATED))) if os.path.exists(INTEGRATED) else set()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids")
    ap.add_argument("--category")
    ap.add_argument("--count", type=int)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    catalog = cl.load_catalog()
    done = integrated_set()

    if args.ids:
        ids = [i.strip() for i in args.ids.split(",") if i.strip()]
    elif args.category:
        ids = [c["id"] for c in catalog.values() if c["category"] == args.category]
        ids = [i for i in ids if i not in done]
        if args.count:
            ids = ids[:args.count]
    else:
        sys.exit("need --ids or --category")

    specs = []
    for cid in ids:
        if cid in done:
            print(f"  skip (already integrated): {cid}"); continue
        c = catalog.get(cid)
        if not c:
            print(f"  WARN unknown id: {cid}"); continue
        spec = dict(c)
        spec["typeName"] = cl.type_name(cid)
        spec["folder"] = cl.CATEGORY_FOLDER[c["category"]]
        spec["isMetal"] = cl.is_metal(c["category"])
        spec["fileRelPath"] = cl.rel_swift_path(spec)
        spec["tintHex"] = cl.CATEGORY_TINT[c["category"]]
        specs.append(spec)

    json.dump(specs, open(args.out, "w"), ensure_ascii=False, indent=1)
    print(f"wrote {args.out}: {len(specs)} specs")
    print("ids:", ",".join(s["id"] for s in specs))

if __name__ == "__main__":
    main()
