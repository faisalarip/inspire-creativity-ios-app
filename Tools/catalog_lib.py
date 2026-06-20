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

def type_name(cid: str) -> str:
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

def is_metal(cat: str) -> bool:
    return cat == "Metal Shaders"

def rel_swift_path(spec: dict) -> str:
    folder = CATEGORY_FOLDER[spec["category"]]
    return f"InspireCreativityApp/Animations/Catalog/{folder}/{spec['typeName']}.swift"

def rel_metal_path(spec: dict) -> str:
    folder = CATEGORY_FOLDER[spec["category"]]
    return f"InspireCreativityApp/Animations/Catalog/{folder}/{spec['typeName']}.metal"
