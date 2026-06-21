"""Shared helpers for bespoke-animation batch tooling."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG_JSON = os.path.join(ROOT, "docs/superpowers/specs/2026-06-21-animation-catalog.json")
CATALOG_DIR = os.path.join(ROOT, "InspireCreativityApp/Animations/Catalog")

CATEGORY_FOLDER = {
    "Gestures": "Gestures", "Micro-interactions": "MicroInteractions", "Buttons": "Buttons",
    "Transitions": "Transitions", "Text effects": "TextEffects", "Loaders": "Loaders",
    "Navigation": "Navigation", "Onboarding": "Onboarding", "Backgrounds": "Backgrounds",
    "Metal Shaders": "MetalShaders",
}
CATEGORY_ENUM = {
    "Gestures": ".gestures", "Micro-interactions": ".microInteractions", "Buttons": ".buttons",
    "Transitions": ".transitions", "Text effects": ".textEffects", "Loaders": ".loaders",
    "Navigation": ".navigation", "Onboarding": ".onboarding", "Backgrounds": ".backgrounds",
    "Metal Shaders": ".metalShaders",
}
DIFFICULTY_ENUM = {"beginner": ".beginner", "intermediate": ".intermediate", "advanced": ".advanced"}
# Dark, category-signature tints for the card background behind the preview.
CATEGORY_TINT = {
    "Gestures": "#0d0e16", "Micro-interactions": "#141019", "Buttons": "#16120e",
    "Transitions": "#0d1016", "Text effects": "#04050a", "Loaders": "#0a1014",
    "Navigation": "#101418", "Onboarding": "#120e18", "Backgrounds": "#0a0a0c",
    "Metal Shaders": "#0f0a08",
}
_PREFIXES = {"ges", "mi", "btn", "tr", "tx", "ld", "nav", "ob", "bg", "mtl"}

def load_catalog():
    return {c["id"]: c for c in json.load(open(CATALOG_JSON, encoding="utf-8"))}

def _base_type_name(cid: str) -> str:
    """`ges-magnetic-snap` -> `MagneticSnapView`. Drops the category prefix."""
    parts = cid.split("-")
    if parts and parts[0] in _PREFIXES:
        parts = parts[1:]
    camel = "".join(p[:1].upper() + p[1:] for p in parts if p)
    if not camel:
        camel = "Animation"
    if camel[0].isdigit():
        camel = "A" + camel
    return camel + "View"

_CAT_ORDER = ["Gestures", "Micro-interactions", "Buttons", "Transitions", "Text effects",
              "Loaders", "Navigation", "Onboarding", "Backgrounds", "Metal Shaders"]
_CAT_WORD = {"Gestures": "Gesture", "Micro-interactions": "Micro", "Buttons": "Button",
             "Transitions": "Transition", "Text effects": "Text", "Loaders": "Loader",
             "Navigation": "Nav", "Onboarding": "Onboarding", "Backgrounds": "Background",
             "Metal Shaders": "Metal"}
_UNIQUE = None

def _build_unique():
    import collections
    cat = load_catalog()
    groups = collections.defaultdict(list)
    for cid, c in cat.items():
        groups[_base_type_name(cid)].append((cid, c["category"]))
    m = {}
    for base, members in groups.items():
        if len(members) == 1:
            m[members[0][0]] = base
        else:
            # Canonical-first (by category order then id) keeps the base name —
            # so already-integrated names stay stable; later ones get a category suffix.
            members.sort(key=lambda x: (_CAT_ORDER.index(x[1]) if x[1] in _CAT_ORDER else 99, x[0]))
            for i, (cid, catg) in enumerate(members):
                m[cid] = base if i == 0 else base[:-4] + _CAT_WORD.get(catg, "X") + "View"
    return m

def type_name(cid: str) -> str:
    """Globally-unique view type name; disambiguates cross-category base clashes."""
    global _UNIQUE
    if _UNIQUE is None:
        _UNIQUE = _build_unique()
    return _UNIQUE.get(cid) or _base_type_name(cid)

def is_metal(cat: str) -> bool:
    return cat == "Metal Shaders"

def rel_swift_path(spec: dict) -> str:
    folder = CATEGORY_FOLDER[spec["category"]]
    return f"InspireCreativityApp/Animations/Catalog/{folder}/{spec['typeName']}.swift"

def rel_metal_path(spec: dict) -> str:
    folder = CATEGORY_FOLDER[spec["category"]]
    return f"InspireCreativityApp/Animations/Catalog/{folder}/{spec['typeName']}.metal"
