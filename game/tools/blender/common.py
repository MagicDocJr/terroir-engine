# Shared helpers for the headless Blender asset generators (build_vineyard.py, build_winery.py).
# Adapted from the engine demo (branch prototype/engine-demo, prototypes/engine-demo/blender/build_assets.py).
#
# Conventions: geometry is accumulated in *Blender* coords (Z up) and exported as glTF (Y up, metres).
# gl(x, y, z) converts glTF coords to Blender coords. Every mesh carries UV0, UV1 (exported as TEXCOORD_1 →
# Godot UV2) and a per-vertex colour. Godot replaces materials by name (resource_name), so the material
# names below are a contract with game/src/view3d/*.gd.
import bpy, math, os
from mathutils import Vector, Matrix, noise

V = Vector
OUT = os.getcwd()
LOD = 0          # 0 = full detail, 1 = mid, 2 = far (same random sequence, cheaper geometry)


def set_out(path):
    global OUT
    OUT = path
    os.makedirs(OUT, exist_ok=True)


def gl(x, y, z):
    """glTF coords (x, y-up, z) → Blender coords (x, -z, y)."""
    return V((x, -z, y))


def ss(a, b, t):
    t = (t - a) / (b - a)
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return t * t * (3 - 2 * t)


def fbm(x, z, scale, octaves, seed):
    v, a, f, tot = 0.0, 1.0, 1.0 / scale, 0.0
    for o in range(octaves):
        v += a * noise.noise(Vector((x * f, z * f, seed + o * 7.13)))
        tot += a; a *= 0.5; f *= 2.0
    return v / tot


class Acc:
    """Accumulates geometry in Blender coords for one material. uv2 carries per-element data (see vines)."""
    def __init__(self):
        self.v, self.f, self.uv, self.col, self.uv2 = [], [], [], [], []

    def add(self, verts, faces, uvs, cols, uv2=None):
        o = len(self.v)
        self.v += verts; self.uv += uvs; self.col += cols
        self.uv2 += uv2 if uv2 is not None else [(0.0, 0.0)] * len(verts)
        self.f += [tuple(i + o for i in fc) for fc in faces]


MAT = {
    # name: (base colour linear, roughness, double sided)
    "vine_wood":  ((0.30, 0.26, 0.21), 0.85, False),
    "vine_bark":  ((0.20, 0.13, 0.08), 0.90, False),
    "vine_leaf":  ((1.0, 1.0, 1.0), 0.55, True),    # colour from vertex colours
    "vine_berry": ((1.0, 1.0, 1.0), 0.40, False),
    "stone":      ((0.055, 0.062, 0.075), 0.42, False),
    "grass":      ((1.0, 1.0, 1.0), 0.70, True),
    "tree_card":  ((1.0, 1.0, 1.0), 0.90, True),
}


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    col, rough, ds = MAT.get(name, ((0.8, 0.8, 0.8), 0.8, False))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    m.use_backface_culling = not ds
    return m


def make_object(name, parts, smooth=True):
    """parts: {material_name: Acc}. One object, one material slot per non-empty part."""
    parts = {k: a for k, a in parts.items() if a.f}
    me = bpy.data.meshes.new(name)
    verts, faces, uvs, uv2s, cols, mats = [], [], [], [], [], []
    for mi, (mname, a) in enumerate(parts.items()):
        o = len(verts)
        verts += a.v; uvs += a.uv; uv2s += a.uv2; cols += a.col
        faces += [tuple(i + o for i in fc) for fc in a.f]
        mats += [mi] * len(a.f)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    uvl2 = me.uv_layers.new(name="UV2")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = uvs[vi]
            uvl2.data[li].uv = uv2s[vi]
    me.uv_layers.active = uvl
    ca = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    for i, c in enumerate(cols):
        ca.data[i].color = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = ca
    for poly, mi in zip(me.polygons, mats):
        poly.material_index = mi
        poly.use_smooth = smooth
    for mname in parts:
        me.materials.append(material(mname))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


INTERIOR = {"cellar_wall", "hall_floor"}   # rooms seen from inside (the vault, the floor round the stairwell): inward on purpose


def inward_parts(ob):
    """Loose parts of a mesh whose faces point inward (signed volume < 0). Open parts (tubes without caps) are judged
    the same way; flat ones (leaf cards, planes) enclose no volume and are skipped. Returns [(material, faces)]."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        part, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            part.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); stack.append(g)
        if len(part) < 4:
            continue
        c = sum((f.calc_center_median() for f in part), Vector()) / len(part)
        vol = sum((f.calc_center_median() - c).dot(f.normal) * f.calc_area() for f in part) / 3.0
        lo = Vector([min(v.co[i] for f in part for v in f.verts) for i in range(3)])
        hi = Vector([max(v.co[i] for f in part for v in f.verts) for i in range(3)])
        d = hi - lo
        box = d.x * d.y * d.z
        mi = part[0].material_index
        if mi < len(ob.data.materials) and ob.data.materials[mi] and ob.data.materials[mi].name.split(".")[0] in INTERIOR:
            continue
        if box > 1e-12 and vol < -0.05 * box:
            out.append((ob.data.materials[mi].name if mi < len(ob.data.materials) and ob.data.materials[mi] else "?", len(part)))
    bm.free()
    return out


def export(obs, filename, check=True):
    """Export one object or a list of objects (each becomes a named glTF node) into OUT/filename. Warns about parts
    wound inside out (they render lit from the wrong side, and back-face culling hides their near side)."""
    if not isinstance(obs, (list, tuple)):
        obs = [obs]
    for ob in obs:
        if check and ob.type == "MESH":
            bad = inward_parts(ob)
            if bad:
                mats = {}
                for m, n in bad: mats[m] = mats.get(m, 0) + 1
                print("INWARD faces in %s/%s: %s" % (filename, ob.name, ", ".join("%s ×%d" % kv for kv in mats.items())))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    path = os.path.join(OUT, filename)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("exported", filename, sum(len(o.data.polygons) for o in obs), "faces")


def clear_scene():
    for o in list(bpy.context.scene.collection.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def tube(acc, pts, radii, sides, col, v_scale=0.25, cap=False, uv2=(0.0, 0.0)):
    """Swept tube along pts (Blender coords) with parallel-transport frames."""
    if LOD == 1: sides = max(3, sides // 2)
    elif LOD >= 2: sides = 3
    if LOD >= 1 and len(pts) > 3:                    # fewer rings along the curve for the far LODs
        step = 2 if LOD == 1 else (3 if LOD == 2 else 5)
        idx = list(range(0, len(pts), step))
        if idx[-1] != len(pts) - 1:
            idx.append(len(pts) - 1)
        pts = [pts[i] for i in idx]
        radii = [radii[i] for i in idx]
    n = len(pts)
    if n < 2:
        return
    t0 = (pts[1] - pts[0]).normalized()
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = t0.cross(ref).normalized()
    verts, uvs, faces, cols = [], [], [], []
    length = 0.0
    prev_t = t0
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        t = t.normalized() if t.length > 1e-9 else prev_t
        axis = prev_t.cross(t)
        if axis.length > 1e-6:
            ang = prev_t.angle(t)
            nrm = Matrix.Rotation(ang, 3, axis.normalized()) @ nrm
        prev_t = t
        bin_ = t.cross(nrm).normalized()
        if i > 0: length += (p - pts[i - 1]).length
        for s in range(sides + 1):
            a = 2 * math.pi * s / sides
            verts.append(p + radii[i] * (math.cos(a) * nrm + math.sin(a) * bin_))
            uvs.append((s / sides, length / v_scale))
            cols.append(col)
    for i in range(n - 1):
        for s in range(sides):
            a = i * (sides + 1) + s
            b = a + sides + 1
            faces.append((a, a + 1, b + 1, b))
    if cap:
        c = len(verts); verts.append(pts[-1]); uvs.append((0.5, 0.5)); cols.append(col)
        base = (n - 1) * (sides + 1)
        for s in range(sides):
            faces.append((base + s, base + s + 1, c))
    acc.add(verts, faces, uvs, cols, [uv2] * len(verts))


def catmull(ctrl, per_seg=6):
    out = []
    P = [ctrl[0]] + ctrl + [ctrl[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per_seg):
            t = k / per_seg
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(ctrl[-1])
    return out


# --------------------------------------------------------------------------- grape leaf
LEAF_N = 16


def leaf_outline_r(theta):
    """Riesling-like leaf: roundish, shallow lateral sinuses, U-shaped petiolar sinus."""
    lobes = [0.0, math.radians(68), -math.radians(68), math.radians(135), -math.radians(135)]
    bump = max(math.exp(-((theta - c + math.pi) % (2 * math.pi) - math.pi) ** 2 / (2 * 0.26 ** 2)) for c in lobes)
    r = 0.36 + 0.17 * bump
    r *= 1.0 + 0.06 * abs(math.sin(theta * 14.0)) ** 3            # serration
    at = abs(theta)
    if at > math.radians(150):                                    # petiolar sinus reaches the attachment point
        r = r + (0.5 - r) * ss(math.radians(150), math.pi, at)
    return r


LEAF_CARD_V0 = 0.33          # v of the petiole point in the leaf atlas cells (build_leaf_atlas.py PETIOLE_PT)
LEAF_CARD_SCALE = 1.12       # the atlas leaf fills ~0.9 of its cell; the outline blades spanned ~1.06


def leaf_card(acc, origin, up_dir, normal, size, col, uv2=(0.0, 0.0), cup=1.0):
    """Textured leaf card (the Variety's outline comes from the leaf atlas, alpha-tested in leaf.gdshader). The
    petiole point of the atlas leaf sits at origin; tip towards up_dir, facing normal. Same UV layout and cupping as
    leaf_blade: petiole at (0.5, ~0.33), blade centre (0.5, 0.5). 8 triangles near (LOD 0-1), 2 far."""
    n = normal.normalized()
    u_axis = n.cross(up_dir).normalized()
    v_axis = u_axis.cross(n).normalized()
    s = size * LEAF_CARD_SCALE
    k = 3 if LOD < 2 else 2
    verts, uvs, cols, faces = [], [], [], []
    for j in range(k):
        for i in range(k):
            uu, vv = i / (k - 1), j / (k - 1)
            x = uu - 0.5
            z = cup * (0.10 * abs(x) + 0.12 * ((x * x + (vv - 0.5) ** 2) * 1.2)) if k == 3 else 0.0
            verts.append(origin + s * (x * u_axis + (vv - LEAF_CARD_V0) * v_axis + z * n))
            uvs.append((uu, vv))
            shade = 0.9 + 0.1 * min(1.0, 2 * math.hypot(x, vv - 0.5))
            cols.append((col[0] * shade, col[1] * shade, col[2] * shade))
    for j in range(k - 1):
        for i in range(k - 1):
            a, b, c, d = j * k + i, j * k + i + 1, (j + 1) * k + i + 1, (j + 1) * k + i
            faces.append((a, b, c, d))
    acc.add(verts, faces, uvs, cols, [uv2] * len(verts))


def leaf_blade(acc, origin, up_dir, normal, size, col, uv2=(0.0, 0.0), cup=1.0):
    """Blade whose petiole attachment is at origin, tip direction up_dir, facing normal.
    UV: petiole at (0.5, 0), blade centre (0.5, 0.5). uv2 = (per-leaf random, position along the shoot)."""
    n = normal.normalized()
    u_axis = n.cross(up_dir).normalized()
    v_axis = u_axis.cross(n).normalized()
    c = Vector((0.0, 0.5))
    verts, uvs, cols, faces = [], [], [], []

    def put(p2, k):
        x, v = p2.x, p2.y
        z = cup * (0.10 * abs(x) + 0.12 * ((x * x + (v - 0.5) ** 2) * 1.2))   # midrib V-fold + cupping
        verts.append(origin + size * (x * u_axis + v * v_axis + z * n))
        uvs.append((x + 0.5, v))
        shade = 0.82 + 0.18 * k
        cols.append((col[0] * shade, col[1] * shade, col[2] * shade))
    put(c, 0.0)
    N = LEAF_N if LOD == 0 else (12 if LOD == 1 else (7 if LOD == 2 else 5))
    rings = ((1, 0.55), (2, 1.0)) if LOD == 0 else ((2, 1.0),)
    for ring, fac in rings:
        for i in range(N):
            th = -math.pi + 2 * math.pi * (i + 0.5) / N
            r = leaf_outline_r(th) * fac
            put(c + Vector((math.sin(th), math.cos(th))) * r, fac)
    for i in range(N):
        j = (i + 1) % N
        a, b = 1 + i, 1 + j
        faces.append((0, a, b))
        if LOD == 0: faces.append((a, a + N, b + N, b))
    acc.add(verts, faces, uvs, cols, [uv2] * len(verts))


def berry_sphere(acc, center, r, col, uv2=(0.0, 0.0), seg=5, rings=3):
    verts, faces, uvs, cols = [], [], [], []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(seg):
            th = 2 * math.pi * j / seg
            verts.append(center + r * Vector((math.sin(phi) * math.cos(th), math.sin(phi) * math.sin(th), math.cos(phi))))
            uvs.append((j / seg, i / rings)); cols.append(col)
    for i in range(rings):
        for j in range(seg):
            a = i * seg + j; b = i * seg + (j + 1) % seg
            faces.append((a, a + seg, b + seg, b))          # counter-clockwise seen from outside: normals point out
    acc.add(verts, faces, uvs, cols, [uv2] * len(verts))
