# Ground cover for the vineyard verges (vineyard.gd _build_groundcover). Run headless via ../sync_assets3d.sh:
#   blender -b --factory-startup -P build_groundcover.py -- <models_dir> <props_dir>
# Each source is a Poly Haven CC0 scan (fetched by fetch_assets3d.py into <props_dir>) holding several plant variants
# side by side. For each variant: apply its transform, move the origin to the middle of its base, decimate to at most
# MAX_TRIS triangles, and export all variants of one plant as named nodes into <models_dir>/gc_<plant>.glb
# (textures embedded). A.glb_meshes() then gives the variants by name.
import bpy, sys, os, bmesh
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common as C

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.getcwd()
PROPS = args[1] if len(args) > 1 else os.path.join(OUT, "..", "props")
C.set_out(OUT)
MAX_TRIS = 800                   # per variant: dozens are scattered, each seen small
PLANTS = ["dandelion_01", "celandine_01", "fern_02", "dry_branches_medium_01"]


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def clear_all():
    # common.clear_scene only unlinks the scene collection's objects; imports land in child collections
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


for plant in PLANTS:
    clear_all()
    src = os.path.join(PROPS, plant, plant + ".gltf")
    if not os.path.exists(src):
        print("Error: missing", src)
        continue
    bpy.ops.import_scene.gltf(filepath=src)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    out = []
    for ob in obs:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        ob.parent = None
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # origin at the middle of the base (Blender is Z up here)
        xs = [v.co.x for v in ob.data.vertices]; ys = [v.co.y for v in ob.data.vertices]; zs = [v.co.z for v in ob.data.vertices]
        cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
        for v in ob.data.vertices:
            v.co.x -= cx; v.co.y -= cy; v.co.z -= z0
        ob.location = (0, 0, 0)
        n = tris(ob)
        if n > MAX_TRIS:
            mod = ob.modifiers.new("decimate", "DECIMATE")
            mod.ratio = MAX_TRIS / n
            bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.name = ob.name.replace("_LOD0", "")
        print("layout", plant, ob.name, n, "->", tris(ob), "tris")
        out.append(ob)
    C.export(out, "gc_%s.glb" % plant.replace("_01", "").replace("_02", "").replace("_medium", ""), check=False)   # scans: open, cupped cards
print("DONE")
