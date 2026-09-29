#!/usr/bin/env python3
"""Downloads the CC0 textures, skies and props the 3D view uses (Poly Haven, polyhaven.com, all CC0).
Usage: fetch_assets3d.py <game/assets3d>. Skips files that already exist, so it is safe to re-run.
Adapted from the engine demo (branch prototype/engine-demo, fetch_assets.sh + fetch_assets_r2.py)."""
import json, os, sys, urllib.request

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets3d"))
API = "https://api.polyhaven.com/files/"
UA = {"User-Agent": "terroir-engine (private hobby project; CC0 assets)"}

# sky name → (asset, resolution). "clear" keeps 4k because it is seen directly as the backdrop.
SKIES = {
    "clear": ("qwantani_afternoon_puresky", "4k"),
    "overcast": ("kloofendal_overcast_puresky", "2k"),
    "misty": ("kloofendal_misty_morning_puresky", "2k"),
    "dusk": ("qwantani_dusk_2_puresky", "2k"),
}
TEXTURES = [
    "rock_ground",              # Mosel: weathered Devonian slate soil (tinted blue-grey)
    "dry_ground_rocks",         # Côte d'Or: pale limestone/marl soil with stones
    "brown_mud_dry",            # Napa: brown loam
    "grass_ground",             # cover crop / verges
    "bark_willow_02",           # vine wood
    "castle_wall_slates",       # cellar vault
    "cobblestone_floor_04",     # cellar floor
    "concrete_floor_worn_001",  # hall floor
    "grey_plaster_02",          # hall walls
    "oak_veneer_01",            # barrels, racks
    "rusty_metal_02",           # barrel hoops
    "painted_plaster_wall",     # winery facade (tinted per Region)
    "grey_roof_tiles_02",       # Mosel: slate roof
    "red_slate_roof_tiles_01",  # Côte d'Or: flat Burgundy tiles
    "clay_roof_tiles_02",       # Napa: barrel (mission) tiles
    # winery look (docs/superpowers/specs/2026-09-29-cozy-winery-design.md): walls, floors and beams
    "white_sandstone_blocks_02",   # limestone blocks (Côte d'Or)
    "whitewashed_brick",
    "brown_planks_07",             # redwood boards (Napa)
    "monastery_stone_floor",       # stone flags
    "slate_floor_03",              # slate flags (Mosel)
    "terracotta_floor_tiles",
    "herringbone_brick",
    "dark_wood",                   # oak beams
]
PROPS = ["hanging_industrial_lamp", "industrial_caged_sconce", "plastic_crate_01", "ladder_sectioned_01",
         # winery look: lights, tasting corner, lounge, plants, outside and cellar details
         "lantern_chandelier_01", "dining_table", "gallinera_chair", "WoodenTable_02", "wine_bottles_01", "wine_barrel_01", "Lantern_01",
         "Sofa_01", "ArmChair_01", "WoodenTable_01", "potted_plant_02", "planter_box_01",
         "painted_wooden_bench", "wooden_lantern_01",
         # a lived-in yard and cellar
         "wicker_basket_01", "wicker_basket_02", "hand_truck", "wooden_display_shelves_01", "planter_pot_clay",
         "garden_hose_wall_mounted_01", "compost_bags"]
# ground-cover scans: sources for blender/build_groundcover.py, which splits them into variants and decimates them
# (the scans are 6k–1.7M triangles) into models/gc_*.glb
GROUNDCOVER = ["dandelion_01", "celandine_01", "fern_02", "dry_branches_medium_01"]
# tree scans (46–85 MB each, ~2–5M triangles): sources for blender/build_trees3d.py (thinned, decimated near-tree models)
TREES = ["island_tree_01", "island_tree_02", "island_tree_03"]


def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req) as r, open(path + ".part", "wb") as f:
        f.write(r.read())
    os.replace(path + ".part", path)
    print("ok", os.path.relpath(path, ROOT))


def files(asset):
    return json.load(urllib.request.urlopen(urllib.request.Request(API + asset, headers=UA)))


def main():
    for name, (asset, res) in SKIES.items():
        dest = f"{ROOT}/hdri/{name}.hdr"
        if not os.path.exists(dest):
            get(files(asset)["hdri"][res]["hdr"]["url"], dest)
    for tex in TEXTURES:
        if all(os.path.exists(f"{ROOT}/textures/{tex}/{n}.jpg") for n in ("diff", "nor_gl", "rough")):
            continue
        d = files(tex)
        for key, name in [("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("Rough", "rough"), ("AO", "ao")]:
            if key in d:
                get(d[key]["2k"]["jpg"]["url"], f"{ROOT}/textures/{tex}/{name}.jpg")
    for model in PROPS + GROUNDCOVER + TREES:
        base = f"{ROOT}/props/{model}"
        if os.path.exists(f"{base}/{model}.gltf"):
            continue
        g = files(model)["gltf"]["1k"]["gltf"]
        get(g["url"], f"{base}/{model}.gltf")
        for rel, inc in g.get("include", {}).items():
            get(inc["url"], f"{base}/{rel}")
    with open(f"{ROOT}/CREDITS.txt", "w") as fh:
        fh.write("All textures, skies and props: Poly Haven (polyhaven.com), CC0.\n"
                 + "\n".join(f"hdri/{k}.hdr: {a}" for k, (a, _) in SKIES.items()) + "\n"
                 + "\n".join(f"textures/{t}" for t in TEXTURES) + "\n" + "\n".join(f"props/{p}" for p in PROPS + GROUNDCOVER + TREES) + "\n")
    print("fetch done:", ROOT)


if __name__ == "__main__":
    main()
