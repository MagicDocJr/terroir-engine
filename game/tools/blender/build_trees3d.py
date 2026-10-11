# Near trees for the Estate (vineyard.gd _build_near_trees). Run headless via ../sync_assets3d.sh:
#   blender -b --factory-startup -P build_trees3d.py -- <models_dir> <props_dir>
# Sources: Poly Haven CC0 tree scans (fetched into <props_dir> by fetch_assets3d.py), each ~1–2M triangles, mostly tiny
# leaf cards. Decimating leaf cards melts them into blobs, so the leaves are THINNED instead: whole cards (loose islands)
# are kept at random and the kept ones grown about their centre so the canopy stays full. Bark (trunk, branches) is
# decimated. Two levels per tree: lod0 (near) and lod1 (mid distance), exported as tree3d_<n>_lod<k>.glb.
import bpy, bmesh, sys, os, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common as C

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.getcwd()
PROPS = args[1] if len(args) > 1 else os.path.join(OUT, "..", "props")
C.set_out(OUT)
TREES = ["island_tree_01", "island_tree_02", "island_tree_03", "tree_small_02"]
# per level: (leaf triangle budget, bark triangle budget); kept cards grow by (1 / share kept) ** GROW_EXP so the
# canopy keeps roughly its look (a first pass growing 1.75x at 3.5 % read too thin)
LODS = [(45000, 9000), (10000, 2000)]
GROW_EXP = 0.27
# tree_small_02's leaf "cards" are clusters joined to long stems: growing them much smears spikes across the canopy
PER_TREE = {"tree_small_02": {"grow_exp": 0.15, "leaf_mul": 1.4}}


def clear_all():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    for im in list(bpy.data.images):
        bpy.data.images.remove(im)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def thin_leaves(ob, keep, grow, seed):
    """Keep a random share of the leaf cards (loose parts) and scale each kept card about its centre."""
    me = ob.data
    n = len(me.vertices)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
    for p in me.polygons:
        vs = p.vertices
        for v in vs[1:]:
            union(vs[0], v)
    # the glTF import splits vertices at UV seams: join vertices at the same position, or one card falls apart into
    # loose triangles (half-cards kept, slivers grown into spikes)
    seen = {}
    for v in me.vertices:
        key = (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
        if key in seen:
            union(seen[key], v.index)
        else:
            seen[key] = v.index
    roots = [find(i) for i in range(n)]
    rng = random.Random(seed)
    islands = sorted(set(roots))
    kept = set(r for r in islands if rng.random() < keep)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    # the card id travels with each vertex in a layer: indices are not reliable once faces are deleted
    isl = bm.verts.layers.int.new("island")
    for v in bm.verts:
        v[isl] = roots[v.index]
    drop = [f for f in bm.faces if f.verts[0][isl] not in kept]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    # grow each kept card about its centre
    groups = {}
    for v in bm.verts:
        groups.setdefault(v[isl], []).append(v)
    for vs in groups.values():
        c = sum((v.co for v in vs), vs[0].co * 0) / len(vs)
        for v in vs:
            v.co = c + (v.co - c) * grow
    bm.to_mesh(me)
    bm.free()
    return len(islands), len(kept)


def decimate(ob, budget):
    n = tris(ob)
    if n > budget:
        select_only(ob)
        mod = ob.modifiers.new("decimate", "DECIMATE")
        mod.ratio = budget / n
        bpy.ops.object.modifier_apply(modifier=mod.name)


for ti, tree in enumerate(TREES):
    for li, (leaf_budget, bark) in enumerate(LODS):
        clear_all()
        src = os.path.join(PROPS, tree, tree + ".gltf")
        if not os.path.exists(src):
            print("Error: missing", src)
            break
        bpy.ops.import_scene.gltf(filepath=src)
        ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
        select_only(ob)
        ob.parent = None
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.mesh.separate(type="MATERIAL")
        parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        out = []
        for p in parts:
            mat = (p.data.materials[0].name if p.data.materials else "").split(".")[0]   # a re-import names it "…_leaves.001"
            before = tris(p)
            if mat.endswith("_leaves"):
                cfg = PER_TREE.get(tree, {})
                keep = min(1.0, leaf_budget * cfg.get("leaf_mul", 1.0) / max(1, before))
                total, kept = thin_leaves(p, keep, (1.0 / keep) ** cfg.get("grow_exp", GROW_EXP), 7 + ti)
                p.name = "%s_leaves" % tree
                print("layout", tree, "lod%d" % li, "leaves", before, "->", tris(p), "tris (%d of %d cards)" % (kept, total))
            else:
                decimate(p, bark if mat.endswith("_branches") else bark // 2)
                p.name = "%s_%s" % (tree, "branches" if mat.endswith("_branches") else "trunk")
                print("layout", tree, "lod%d" % li, p.name, before, "->", tris(p), "tris")
            out.append(p)
        C.export(out, "tree3d_%d_lod%d.glb" % (ti + 1, li), check=False)   # scans: open trunks, cupped leaf cards
print("DONE")
