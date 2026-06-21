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

_TOPTYPE = re.compile(r'(?m)^(?:public |final |private |fileprivate )*(?:struct|class|enum|actor)\s+([A-Za-z_]\w*)')

def normalize(src: str, typename: str) -> str:
    """Make a generated view file collision-proof AND cascade-proof:
    1. Strip `#Preview` blocks (ambiguous SwiftUI.Preview vs UIKit.Preview under UIKit).
    2. Rename a local `Color(hex:)` helper's external label to `hexCode` (app HexColor clash).
    3. De-privatize NESTED types — they're namespaced by their parent so they never
       collide, and privacy there only triggers access-level cascade errors.
    4. Prefix-rename every TOP-LEVEL helper type (!= the main view) to `<typename>_<name>`,
       guaranteeing global uniqueness — no cross-file or app-symbol collision. Access is
       left untouched, so no access-level cascades are introduced.
    """
    out = src
    # 0. Ensure the main View struct is named exactly `typename` (handles disambiguated
    #    typeNames where the generator used the shared base name).
    mm = re.search(r'(?m)^(?:public |final )*struct (\w+)\s*:\s*View\b', out)
    if mm and mm.group(1) != typename:
        out = re.sub(rf'\b{mm.group(1)}\b', typename, out)
    # 1. strip #Preview blocks (balanced braces)
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
    # 2. Color(hex:) label
    if 'extension Color' in out and '(hex:' in out:
        out = out.replace('init(hex:', 'init(hexCode hex:').replace('Color(hex:', 'Color(hexCode:')
    # 3. de-privatize nested (indented) type declarations
    out = re.sub(r'(?m)^([ \t]+)(?:private |fileprivate )(struct|enum|class|actor)\b', r'\1\2', out)
    # 4. prefix-rename top-level helper types for global uniqueness
    names = {m.group(1) for m in _TOPTYPE.finditer(out) if m.group(1) != typename}
    for nm in sorted(names, key=len, reverse=True):
        out = re.sub(rf'\b{nm}\b', f'{typename}_{nm}', out)
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

    new_files, reg_lines, seed_lines, done_ids, skipped = [], [], [], [], []
    for item in gen:
        if not item:
            continue
        cid = item.get("id")
        spec = specs.get(cid)
        if not spec:
            skipped.append(f"{cid} (no spec)"); continue
        src = normalize((item.get("viewSource") or "").strip(), spec["typeName"])
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
