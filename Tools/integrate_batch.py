#!/usr/bin/env python3
"""Integrate a generated batch: write view (+ metal) files and wiring, then run
the pbxproj adder and the code-sample generator.

Inputs:
  --spec   batch spec JSON from prepare_batch.py
  --gen    workflow output JSON: [{id, viewSource, metalSource?}, ...]

After this runs, build with xcodebuild to verify the batch.
"""
import argparse, json, os, re, subprocess, sys
import catalog_lib as cl

REG_FILE = os.path.join(cl.ROOT, "InspireCreativityApp/Animations/Catalog/BespokeAnimations.swift")
SEED_FILE = os.path.join(cl.ROOT, "InspireCreativityApp/Repositories/Seed/BespokeSeed.swift")
REG_MARK = "// BESPOKE-REGISTRATION-INSERT"
SEED_MARK = "// BESPOKE-SEED-INSERT"
INTEGRATED = os.path.join(cl.ROOT, "Tools/integrated_ids.json")

def swift_str(s: str) -> str:
    return json.dumps(" ".join(s.split()), ensure_ascii=False)  # collapse whitespace, escape

_TYPEDECL = re.compile(r'^(?:public |final |private |fileprivate )?(?:struct|class|enum|protocol|actor) ([A-Za-z_][A-Za-z0-9_]*)')
_HELPER = re.compile(r'^private (?:struct|class|enum|actor) ([A-Za-z_][A-Za-z0-9_]*)', re.M)

def reserved_symbols():
    """Top-level type names defined OUTSIDE the bespoke Catalog — a generated
    helper must not collide with these (module-visible) names."""
    res = set()
    base = os.path.join(cl.ROOT, "InspireCreativityApp")
    for dp, _, fs in os.walk(base):
        if "Animations/Catalog" in dp:
            continue
        for f in fs:
            if not f.endswith(".swift"):
                continue
            for line in open(os.path.join(dp, f), encoding="utf-8", errors="replace"):
                m = _TYPEDECL.match(line)
                if m:
                    res.add(m.group(1))
    return res

def _privatize_helpers(src, typename):
    """Mark every top-level declaration `private` EXCEPT the main `<typename>`
    view, so helper structs/funcs/extensions never collide across the 200+ files."""
    out = []
    for line in src.split("\n"):
        m = re.match(r'^(struct|class|enum|actor|func|extension)\b(.*)$', line)
        if m:
            kw = m.group(1)
            name = None
            if kw != "extension":
                nm = re.match(r'\s+([A-Za-z_][A-Za-z0-9_]*)', m.group(2))
                name = nm.group(1) if nm else None
            if not (kw != "extension" and name == typename):
                line = "private " + line
        out.append(line)
    return "\n".join(out)

def normalize(src: str, typename: str, reserved: set) -> str:
    """Auto-fix every systemic compile hazard found across Gates 1-3:
    1. Strip `#Preview` blocks (ambiguous SwiftUI.Preview vs UIKit.Preview when UIKit imported).
    2. Rename a local `Color(hex:)` helper's external label to `hexCode` (collides with app HexColor).
    3. Privatize all top-level helpers except the main view (cross-file name collisions).
    4. Rename any private helper type that collides with an app-internal symbol (e.g. Chip, BlobShape).
    """
    out = src
    while True:
        m = re.search(r'\n[ \t]*(//[^\n]*\n[ \t]*)?#Preview\b', out)
        if not m:
            break
        brace = out.find('{', m.end())
        if brace == -1:
            break
        depth, i = 0, brace
        while i < len(out):
            if out[i] == '{':
                depth += 1
            elif out[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        out = out[:m.start()] + out[i + 1:]
    if 'extension Color' in out and '(hex:' in out:
        out = out.replace('init(hex:', 'init(hexCode hex:').replace('Color(hex:', 'Color(hexCode:')
    out = _privatize_helpers(out, typename)
    for name in (set(_HELPER.findall(out)) & reserved):
        out = re.sub(rf'\b{name}\b', f'{typename}_{name}', out)
    return out.rstrip() + '\n'

def insert_before_marker(path, marker, block):
    txt = open(path, encoding="utf-8").read()
    if marker not in txt:
        sys.exit(f"marker {marker} not found in {path}")
    txt = txt.replace(marker, block + marker, 1)
    open(path, "w", encoding="utf-8").write(txt)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--gen", required=True)
    args = ap.parse_args()

    specs = {s["id"]: s for s in json.load(open(args.spec, encoding="utf-8"))}
    gen = json.load(open(args.gen, encoding="utf-8"))
    if isinstance(gen, dict) and "results" in gen:
        gen = gen["results"]

    reserved = reserved_symbols()
    new_files, reg_lines, seed_lines, done_ids, skipped = [], [], [], [], []
    for item in gen:
        if not item:
            continue
        cid = item.get("id")
        spec = specs.get(cid)
        if not spec:
            skipped.append(f"{cid} (no spec)"); continue
        src = normalize((item.get("viewSource") or "").strip(), spec["typeName"], reserved)
        if "struct " not in src or spec["typeName"] not in src:
            skipped.append(f"{cid} (viewSource missing struct {spec['typeName']})"); continue

        folder_abs = os.path.join(cl.CATALOG_DIR, spec["folder"])
        os.makedirs(folder_abs, exist_ok=True)

        # markers
        markers = [f"// catalog-id: {cid}"]
        metal_src = (item.get("metalSource") or "").strip()
        if spec["isMetal"] and metal_src:
            markers.append(f"// catalog-metal: {spec['typeName']}.metal")
        header = "\n".join(markers) + "\n"
        if not src.startswith("//") and "import SwiftUI" in src:
            body = header + src
        else:
            body = header + src
        swift_path = os.path.join(folder_abs, spec["typeName"] + ".swift")
        open(swift_path, "w", encoding="utf-8").write(body if body.endswith("\n") else body + "\n")
        new_files.append(os.path.relpath(swift_path, cl.ROOT))

        if spec["isMetal"] and metal_src:
            metal_path = os.path.join(folder_abs, spec["typeName"] + ".metal")
            open(metal_path, "w", encoding="utf-8").write(metal_src + ("\n" if not metal_src.endswith("\n") else ""))
            new_files.append(os.path.relpath(metal_path, cl.ROOT))

        tn = spec["typeName"]
        reg_lines.append(
            f'        .init(id: "{cid}",\n'
            f'              grid: {{ AnyView({tn}(demo: true)) }},\n'
            f'              interactive: {{ AnyView({tn}(demo: false)) }}),\n')
        seed_lines.append(
            f'        make(id: "{cid}", name: {swift_str(spec["name"])},\n'
            f'             category: {cl.CATEGORY_ENUM[spec["category"]]}, difficulty: {cl.DIFFICULTY_ENUM[spec["difficulty"]]}, iosVersion: "{spec["iosVersion"]}",\n'
            f'             tintHex: "{spec["tintHex"]}",\n'
            f'             description: {swift_str(spec["behavior"])}),\n')
        done_ids.append(cid)

    if not done_ids:
        print("nothing integrated. skipped:", skipped); sys.exit(1)

    insert_before_marker(REG_FILE, REG_MARK, "".join(reg_lines))
    insert_before_marker(SEED_FILE, SEED_MARK, "".join(seed_lines))

    # pbxproj + codesamples
    subprocess.run(["ruby", os.path.join(cl.ROOT, "Tools/add_sources.rb"), *new_files], cwd=cl.ROOT, check=True)
    subprocess.run(["python3", os.path.join(cl.ROOT, "Tools/gen_codesamples.py")], cwd=cl.ROOT, check=True)

    prev = set(json.load(open(INTEGRATED))) if os.path.exists(INTEGRATED) else set()
    prev.update(done_ids)
    json.dump(sorted(prev), open(INTEGRATED, "w"), indent=1)

    print(f"\nINTEGRATED {len(done_ids)}: {', '.join(done_ids)}")
    if skipped:
        print(f"SKIPPED {len(skipped)}: {skipped}")
    print(f"new files: {len(new_files)}")

if __name__ == "__main__":
    main()
