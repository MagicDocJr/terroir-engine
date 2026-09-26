#!/usr/bin/env python3
# PROTOTYPE — round 2 CC0 downloads from Poly Haven (polyhaven.com, CC0): skies, textures, props.
import json, os, urllib.request
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
API = "https://api.polyhaven.com/files/"
def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and os.path.getsize(path) > 0: return
    req = urllib.request.Request(url, headers={"User-Agent": "terroir-engine-prototype"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f: f.write(r.read())
    print("ok", os.path.relpath(path, ROOT))
def files(asset):
    req = urllib.request.Request(API + asset, headers={"User-Agent": "terroir-engine-prototype"})
    return json.load(urllib.request.urlopen(req))
for sky in ["kloofendal_misty_morning_puresky", "kloofendal_overcast_puresky", "qwantani_sunrise_puresky", "qwantani_dusk_2_puresky"]:
    get(files(sky)["hdri"]["2k"]["hdr"]["url"], f"{ROOT}/hdri/{sky}.hdr")
for tex in ["castle_wall_slates", "cobblestone_floor_04", "concrete_floor_worn_001", "grey_plaster_02", "oak_veneer_01", "rusty_metal_02"]:
    d = files(tex)
    for key, name in [("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("Rough", "rough"), ("AO", "ao")]:
        if key in d: get(d[key]["2k"]["jpg"]["url"], f"{ROOT}/textures/{tex}/{name}.jpg")
for model in ["hanging_industrial_lamp", "industrial_caged_sconce", "plastic_crate_01", "ladder_sectioned_01", "modular_industrial_pipes_01"]:
    g = files(model)["gltf"]["1k"]["gltf"]
    base = f"{ROOT}/polyhaven_models/{model}"
    get(g["url"], f"{base}/{model}.gltf")
    for rel, inc in g.get("include", {}).items(): get(inc["url"], f"{base}/{rel}")
