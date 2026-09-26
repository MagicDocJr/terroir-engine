# PROTOTYPE — throwaway. Generates every shared asset for the engine demo.
# Run via ../build_assets.sh (calls Windows Blender headless).
#
# Output (glTF convention: Y up, metres). Downslope = +Z (south), east = +X.
#   terrain_near.glb  terrain_far.glb  water.glb
#   vine_0..3.glb  slate_0..4.glb  grass_0..2.glb
#   layout.json (sun, cameras, instances)   heights.bin (near-terrain height grid)
import bpy, bmesh, math, random, json, sys, os, struct
from mathutils import Vector, Matrix, Quaternion, noise

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

# --------------------------------------------------------------------------- terrain function
def ss(a, b, t):
    t = (t - a) / (b - a)
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return t * t * (3 - 2 * t)

BANK_Z, SOUTH_Z = 110.0, 240.0          # north river bank, south river bank

def slope_north(d):                      # rise/run as a function of distance uphill from the bank
    return 0.04 + 0.68 * ss(12, 45, d) - 0.60 * ss(190, 330, d)

STEP = 0.25
PROF = [0.0]
for i in range(1, int(1800 / STEP) + 2):
    PROF.append(PROF[-1] + slope_north((i - 0.5) * STEP) * STEP)

def prof(d):
    if d <= 0: return 0.0
    f = d / STEP; i = int(f)
    if i >= len(PROF) - 1: return PROF[-1] + (d - (len(PROF) - 1) * STEP) * 0.12
    t = f - i
    return PROF[i] * (1 - t) + PROF[i + 1] * t

def fbm(x, z, scale, octaves, seed):
    v, a, f, tot = 0.0, 1.0, 1.0 / scale, 0.0
    for o in range(octaves):
        v += a * noise.noise(Vector((x * f, z * f, seed + o * 7.13)))
        tot += a; a *= 0.5; f *= 2.0
    return v / tot

def H(x, z):
    if z < BANK_Z:
        d = BANK_Z - z
        y = 1.5 + prof(d)
        w = ss(20, 120, d)
        y += w * (9.0 * math.sin(x / 140.0 + 0.4) + 4.0 * fbm(x, z, 80, 3, 1.0))
        y += 0.12 * fbm(x, z, 4, 2, 5.0) * ss(5, 20, d)
        return y
    if z < SOUTH_Z:
        t = min(ss(0, 10, z - BANK_Z), ss(0, 10, SOUTH_Z - z))
        return 1.5 + (-1.2 - 1.5) * t
    e = z - SOUTH_Z
    y = 1.5 + 0.01 * e + 240 * ss(160, 760, e)
    y += ss(150, 500, e) * (35 * math.sin(x / 230 + 1.3) + 25 * fbm(x, z, 200, 3, 3.0))
    y += 2 * fbm(x, z, 40, 2, 4.0) * ss(0, 20, e)
    y += ss(150, 450, e) * 9 * fbm(x, z, 55, 3, 7.0)
    return y

def normal_at(x, z, h=0.25):
    dx = (H(x + h, z) - H(x - h, z)) / (2 * h)
    dz = (H(x, z + h) - H(x, z - h)) / (2 * h)
    return Vector((-dx, 1.0, -dz)).normalized()

# vineyard block (glTF coords)
VX, VZ = 13.8, 14.4

# --------------------------------------------------------------------------- mesh helpers
class Acc:
    """Accumulates geometry in *Blender* coords (Z up) for one material."""
    def __init__(self): self.v, self.f, self.uv, self.col = [], [], [], []
    def add(self, verts, faces, uvs, cols):
        o = len(self.v)
        self.v += verts; self.uv += uvs; self.col += cols
        self.f += [tuple(i + o for i in fc) for fc in faces]

def make_object(name, parts, smooth=True):
    """parts: {material_name: Acc}. Returns one object with one slot per material."""
    me = bpy.data.meshes.new(name)
    verts, faces, uvs, cols, mats = [], [], [], [], []
    for mi, (mname, a) in enumerate(parts.items()):
        o = len(verts)
        verts += a.v; uvs += a.uv; cols += a.col
        faces += [tuple(i + o for i in fc) for fc in a.f]
        mats += [mi] * len(a.f)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
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

MAT = {
    # name: (base colour linear, roughness, double sided)
    "vine_wood":  ((0.30, 0.26, 0.21), 0.85, False),
    "vine_bark":  ((0.20, 0.13, 0.08), 0.90, False),
    "vine_leaf":  ((1.0, 1.0, 1.0), 0.55, True),   # colour comes from vertex colours
    "vine_berry": ((1.0, 1.0, 1.0), 0.40, False),
    "slate":      ((0.055, 0.062, 0.075), 0.42, False),
    "grass":      ((1.0, 1.0, 1.0), 0.70, True),
    "terrain_near": ((1.0, 1.0, 1.0), 0.90, False),
    "terrain_far":  ((1.0, 1.0, 1.0), 0.95, False),
    "water":      ((0.02, 0.05, 0.05), 0.05, False),
}
def material(name):
    if name in bpy.data.materials: return bpy.data.materials[name]
    col, rough, ds = MAT[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    m.use_backface_culling = not ds
    return m

def export(ob, filename):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(OUT, filename)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("exported", filename, len(ob.data.polygons), "faces")

def tube(acc, pts, radii, sides, col, v_scale=0.25, cap=False):
    """Swept tube along pts (Blender coords) with parallel-transport frames."""
    if LOD: sides = max(3, sides // 2)
    n = len(pts)
    t0 = (pts[1] - pts[0]).normalized()
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = t0.cross(ref).normalized()
    verts, uvs, faces, cols = [], [], [], []
    length = 0.0
    prev_t = t0
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
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
    acc.add(verts, faces, uvs, cols)

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

# --------------------------------------------------------------------------- grape leaf template
LEAF_N = 30
LOD = 0          # 1 = low-detail far version (same random sequence, cheaper geometry)
def leaf_outline_r(theta):
    """Riesling-like leaf: roundish, shallow lateral sinuses, U-shaped petiolar sinus."""
    lobes = [0.0, math.radians(68), -math.radians(68), math.radians(135), -math.radians(135)]
    bump = max(math.exp(-((theta - c + math.pi) % (2 * math.pi) - math.pi) ** 2 / (2 * 0.26 ** 2)) for c in lobes)
    r = 0.36 + 0.17 * bump
    r *= 1.0 + 0.06 * abs(math.sin(theta * 14.0)) ** 3            # serration
    at = abs(theta)
    if at > math.radians(150):                                 # petiolar sinus reaches attachment point
        r = r + (0.5 - r) * ss(math.radians(150), math.pi, at)
    return r

def leaf_blade(acc, origin, up_dir, normal, size, col):
    """Blade whose petiole attachment is at origin, tip direction up_dir, facing normal."""
    n = normal.normalized()
    u_axis = n.cross(up_dir).normalized()
    v_axis = u_axis.cross(n).normalized()
    c = Vector((0.0, 0.5))
    verts, uvs, cols, faces = [], [], [], []
    def put(p2, k):
        x, v = p2.x, p2.y
        z = 0.10 * abs(x) + 0.12 * ((x * x + (v - 0.5) ** 2) * 1.2)   # midrib V-fold + cupping
        verts.append(origin + size * (x * u_axis + v * v_axis + z * n))
        uvs.append((x + 0.5, v))
        shade = 0.82 + 0.18 * k
        cols.append((col[0] * shade, col[1] * shade, col[2] * shade))
    put(c, 0.0)
    N = 10 if LOD else LEAF_N
    rings = ((2, 1.0),) if LOD else ((1, 0.55), (2, 1.0))
    for ring, fac in rings:
        for i in range(N):
            th = -math.pi + 2 * math.pi * (i + 0.5) / N
            r = leaf_outline_r(th) * fac
            put(c + Vector((math.sin(th), math.cos(th))) * r, fac)
    for i in range(N):
        j = (i + 1) % N
        a, b = 1 + i, 1 + j
        faces.append((0, a, b))
        if not LOD: faces.append((a, a + N, b + N, b))
    acc.add(verts, faces, uvs, cols)

def berry_sphere(acc, center, r, col, seg=5, rings=3):
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
            faces.append((a, b, b + seg, a + seg))
    acc.add(verts, faces, uvs, cols)

# --------------------------------------------------------------------------- vine (Einzelpfahl, Riesling, September)
def build_vine(idx):
    R = random.Random(1000 + idx)
    P = {k: Acc() for k in ("vine_wood", "vine_bark", "vine_leaf", "vine_berry")}
    WHITE = (1, 1, 1)
    # stake
    top = 1.85 + R.uniform(-0.06, 0.06)
    lean = Vector((R.uniform(-0.03, 0.03), R.uniform(-0.03, 0.03), 0))
    stake = [Vector((0, 0, -0.25)) + lean * -0.25, Vector((0, 0, top)) + lean * top]
    stake = [stake[0].lerp(stake[1], t / 6) for t in range(7)]
    tube(P["vine_wood"], stake, [0.028] * 7, 8, WHITE, v_scale=0.4, cap=True)
    # trunk
    head_h = R.uniform(0.55, 0.70)
    phi = R.uniform(0, 2 * math.pi)
    side = Vector((math.cos(phi), math.sin(phi), 0))
    fwd = Vector((-side.y, side.x, 0))
    base = fwd * 0.06
    tr = [base + Vector((R.uniform(-0.03, 0.03), R.uniform(-0.03, 0.03), head_h * k / 5)) for k in range(6)]
    tr[0] = base + Vector((0, 0, -0.1))
    head = tr[-1]
    tube(P["vine_bark"], catmull(tr, 4), [0.038 - 0.012 * k / 21 for k in range(21)], 8, WHITE, v_scale=0.3)
    # two bows (heart shape) tied back to the stake
    bows = []
    for s in (-1, 1):
        sd = side * s
        ctrl = [head,
                head + sd * 0.06 + Vector((0, 0, 0.26)),
                head + sd * 0.24 + Vector((0, 0, 0.36)) + fwd * R.uniform(-0.05, 0.05),
                head + sd * 0.34 + Vector((0, 0, 0.16)) + fwd * R.uniform(-0.05, 0.05),
                head + sd * 0.22 + Vector((0, 0, -0.04)),
                Vector((0, 0, head.z - 0.10)) + sd * 0.035]
        pts = catmull(ctrl, 6)
        tube(P["vine_bark"], pts, [0.012] * len(pts), 6, WHITE, v_scale=0.3)
        bows.append(pts)
    # shoots with leaves and clusters
    total = 0
    counts = [R.randint(6, 8), R.randint(6, 8)]
    ntot = sum(counts)
    for bi, bow in enumerate(bows):
        nshoots = counts[bi]
        for k in range(nshoots):
            pb = bow[int((0.12 + 0.72 * k / max(1, nshoots - 1)) * (len(bow) - 1))]
            az = phi + 2 * math.pi * (total + 0.5 * bi) / ntot + R.uniform(-0.25, 0.25)
            total += 1
            radial = Vector((math.cos(az), math.sin(az), 0))
            L = R.uniform(0.75, 1.25)
            rc = R.uniform(0.18, 0.32)
            r0 = Vector((pb.x, pb.y, 0)).length
            pts = []
            for i in range(9):
                t = i / 8
                h = pb.z + L * t
                h = min(h, top + 0.10 + 0.05 * t)                           # topped
                r = r0 + (rc - r0) * math.sin(t * math.pi * 0.55) + 0.03 * t * t
                tang = Vector((-radial.y, radial.x, 0))
                pts.append(radial * r + tang * (0.04 * math.sin(t * 5 + k)) + Vector((0, 0, h)))
            spts = catmull(pts, 3)
            tube(P["vine_bark"], spts, [0.0065 - 0.003 * i / len(spts) for i in range(len(spts))], 5, WHITE, v_scale=0.3)
            # leaves at nodes
            node = 0
            dist, next_node = 0.0, 0.07
            for i in range(1, len(spts)):
                dist += (spts[i] - spts[i - 1]).length
                if dist < next_node: continue
                next_node += R.uniform(0.062, 0.078)
                node += 1
                p = spts[i]
                t_dir = (spts[min(i + 1, len(spts) - 1)] - spts[i - 1]).normalized()
                alt = 1 if node % 2 else -1
                out = Vector((p.x, p.y, 0)).normalized() if Vector((p.x, p.y, 0)).length > 1e-3 else radial
                perp = t_dir.cross(out).normalized() * alt
                pdir = (out * 0.75 + perp * 0.55 + Vector((0, 0, 0.15))).normalized()
                pet = R.uniform(0.05, 0.08)
                attach = p + pdir * pet
                tube(P["vine_bark"], [p, p + pdir * pet * 0.5 + Vector((0, 0, 0.01)), attach], [0.0025] * 3, 3, WHITE)
                frac = dist / (L + 0.01)
                size = R.uniform(0.13, 0.19) * (1.15 - 0.45 * frac)
                g = R.uniform(-1, 1)
                col = (0.075 + 0.02 * g, 0.20 + 0.05 * g, 0.030)
                if frac > 0.75: col = (0.11 + 0.02 * g, 0.28 + 0.04 * g, 0.045)     # young tip leaves
                if node <= 2 and R.random() < 0.35: col = (0.26, 0.24, 0.05)         # senescing basal leaves
                normal = (pdir * 0.7 + Vector((0, 0, 0.8)) + Vector((R.uniform(-.3, .3), R.uniform(-.3, .3), 0))).normalized()
                tip = (pdir * 0.5 + Vector((0, 0, -0.75))).normalized()
                tip = (tip - normal * tip.dot(normal)).normalized()
                leaf_blade(P["vine_leaf"], attach, tip, normal, size, col)
                if node >= 3 and R.random() < 0.55:                                   # lateral shoot, 2-3 leaves
                    ldir = (out * 0.6 + perp * 0.5 + Vector((0, 0, 0.55))).normalized()
                    for q in range(R.randint(2, 3)):
                        la = p + ldir * (0.05 + 0.06 * q)
                        ln = (ldir * 0.5 + out * 0.5 + Vector((0, 0, 0.7)) + Vector((R.uniform(-.4, .4), R.uniform(-.4, .4), 0))).normalized()
                        lt = (ldir * 0.3 + Vector((0, 0, -0.8))).normalized()
                        lt = (lt - ln * lt.dot(ln)).normalized()
                        g2 = R.uniform(-1, 1)
                        leaf_blade(P["vine_leaf"], la, lt, ln, size * R.uniform(0.55, 0.8), (0.10 + 0.02 * g2, 0.26 + 0.04 * g2, 0.04))
                # clusters in the fruit zone
                if node in (3, 4) and R.random() < (0.85 if node == 3 else 0.35):
                    cdir = -perp
                    ped0 = p + cdir * 0.03
                    ctop = ped0 + cdir * 0.02 + Vector((0, 0, -0.03))
                    tube(P["vine_bark"], [p, ped0, ctop], [0.003] * 3, 3, WHITE)
                    axis = Vector((R.uniform(-.25, .25), R.uniform(-.25, .25), -1)).normalized()
                    lc = R.uniform(0.09, 0.13)
                    a1 = axis.orthogonal().normalized(); a2 = axis.cross(a1)
                    tone = R.random()
                    for b in range(46):
                        tt = R.random() ** 0.8
                        w = 0.030 * (1 - 0.55 * tt) * (1 - 0.3 * tt ** 3)
                        rho = w * (0.45 + 0.55 * math.sqrt(R.random()))
                        an = R.uniform(0, 2 * math.pi)
                        c = ctop + axis * (tt * lc) + (a1 * math.cos(an) + a2 * math.sin(an)) * rho
                        bcol = (0.30 + 0.12 * tone + R.uniform(-.03, .03), 0.36 + 0.05 * tone, 0.07)
                        br = 0.0066 * R.uniform(0.88, 1.08)
                        if not LOD: berry_sphere(P["vine_berry"], c, br, bcol)
                        elif b % 6 == 0: berry_sphere(P["vine_berry"], c, br * 1.9, bcol, seg=4, rings=2)
    return make_object(f"vine_{idx}", P, smooth=True)

def build_vine_lod2(idx):
    R = random.Random(5000 + idx)
    P = {k: Acc() for k in ("vine_wood", "vine_leaf")}
    top = 1.85
    stake = [Vector((0, 0, -0.1)), Vector((0, 0, top))]
    tube(P["vine_wood"], stake, [0.03, 0.03], 4, (1, 1, 1))
    global LOD
    old, LOD = LOD, 1
    for k in range(48):
        h = 0.55 + 1.3 * (k / 48) ** 0.9
        az = R.uniform(0, 2 * math.pi)
        r = 0.14 + 0.14 * math.sin(min(1, (h - 0.5) / 1.4) * math.pi * 0.8)
        out = Vector((math.cos(az), math.sin(az), 0))
        origin = out * r + Vector((0, 0, h))
        normal = (out * 0.8 + Vector((0, 0, 0.6))).normalized()
        tip = Vector((0, 0, -1)); tip = (tip - normal * tip.dot(normal)).normalized()
        g = R.uniform(-1, 1)
        leaf_blade(P["vine_leaf"], origin, tip, normal, R.uniform(0.28, 0.38), (0.075 + 0.02 * g, 0.20 + 0.05 * g, 0.03))
    LOD = old
    return make_object(f"vine_lod2_{idx}", P, smooth=True)

# --------------------------------------------------------------------------- slate chips & grass tufts
def build_slate(idx):
    R = random.Random(2000 + idx)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    w, t = R.uniform(0.35, 0.7), R.uniform(0.05, 0.11)
    for v in bm.verts:
        v.co.x = v.co.x * 1.0 + R.uniform(-0.09, 0.09)
        v.co.y = v.co.y * w + R.uniform(-0.09, 0.09) * w
        v.co.z = v.co.z * t + R.uniform(-0.015, 0.015)
        if v.co.x > 0.3 and R.random() < 0.5: v.co.y *= 0.5          # broken, tapering ends
    acc = Acc()
    bm.verts.index_update()
    acc.add([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces],
            [(v.co.x + 0.5, v.co.y + 0.5) for v in bm.verts],
            [(1, 1, 1)] * len(bm.verts))
    bm.free()
    return make_object(f"slate_{idx}", {"slate": acc}, smooth=False)

def build_grass(idx):
    R = random.Random(3000 + idx)
    acc = Acc()
    for b in range(22):
        ang = R.uniform(0, 2 * math.pi)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        side = Vector((-d.y, d.x, 0))
        base = d * R.uniform(0, 0.12)
        hgt = R.uniform(0.55, 1.0); bend = R.uniform(0.15, 0.5); wid = R.uniform(0.015, 0.03)
        verts, uvs, cols, faces = [], [], [], []
        for s in range(4):
            t = s / 3
            c = base + d * (bend * t * t) + Vector((0, 0, hgt * t))
            ww = wid * (1 - t * 0.9)
            for sgn in (-1, 1):
                verts.append(c + side * ww * sgn); uvs.append(((sgn + 1) / 2, t))
                g = R.uniform(-0.02, 0.02)
                cols.append((0.05 + 0.20 * t + g, 0.09 + 0.20 * t + g, 0.02 + 0.03 * t))
        for s in range(3):
            a = s * 2
            faces.append((a, a + 1, a + 3, a + 2))
        acc.add(verts, faces, uvs, cols)
    return make_object(f"grass_{idx}", {"grass": acc}, smooth=True)

# --------------------------------------------------------------------------- terrain meshes
def neighbour_planted(x, z):
    d = BANK_Z - z
    if d < 18 or d > 200: return False
    if fbm(x, z, 22, 2, 31.0) < -0.25: return False
    return True

def grass_mask(x, z):
    e = max(abs(x) - VX, abs(z) - VZ)
    t = ss(-0.5, 2.5, e)
    if neighbour_planted(x, z) and e > 2.5: t *= 0.25                 # neighbour parcels: mostly slate too
    g_out = 0.6 + 0.4 * fbm(x, z, 6, 2, 9.0)
    g_in = max(0.0, fbm(x, z, 2.5, 2, 13.0)) * 0.35
    return max(0.0, min(1.0, g_in * (1 - t) + g_out * t))

NEAR = dict(x0=-80.0, z0=-80.0, step=0.5, nx=321, nz=321)
def build_near():
    acc = Acc(); heights = []
    n, s, x0, z0 = NEAR["nx"], NEAR["step"], NEAR["x0"], NEAR["z0"]
    for iz in range(NEAR["nz"]):
        z = z0 + iz * s
        for ix in range(n):
            x = x0 + ix * s
            y = H(x, z); heights.append(y)
            acc.v.append(Vector((x, -z, y)))
            acc.uv.append((x / 3.0, z / 3.0))
            m = grass_mask(x, z)
            acc.col.append((m, m, m))
    for iz in range(NEAR["nz"] - 1):
        for ix in range(n - 1):
            a = iz * n + ix
            acc.f.append((a, a + n, a + n + 1, a + 1))
    with open(os.path.join(OUT, "heights.bin"), "wb") as fh:
        fh.write(struct.pack(f"<{len(heights)}f", *heights))
    return make_object("terrain_near", {"terrain_near": acc})

def far_color(x, z, y):
    n = fbm(x, z, 140, 3, 11.0)
    if BANK_Z - 1 < z < SOUTH_Z + 1: return (0.06, 0.055, 0.04)
    if z < BANK_Z:
        d = BANK_Z - z
        if d < 14: return (0.10, 0.12, 0.07)
        if d < 205:
            stripes = 0.5 + 0.5 * math.sin(x * 2.2)
            if n > 0.12: return (0.07 + 0.02 * stripes, 0.13 + 0.03 * stripes, 0.035)   # other vineyards
            if n > -0.28: return (0.035, 0.065, 0.022)                                  # scrub
            return (0.12, 0.115, 0.11)                                                  # slate outcrop
        return (0.022, 0.045, 0.016)                                                    # forest
    e = z - SOUTH_Z
    if e < 160:
        f = fbm(x, z, 60, 2, 21.0)
        return (0.13, 0.17, 0.06) if f > 0 else (0.20, 0.18, 0.09)                      # fields
    return (0.022, 0.045, 0.016)

FAR_X0, FAR_X1, FAR_Z0, FAR_Z1 = -1800.0, 1800.0, -1000.0, 1800.0

def write_far_albedo(w=2048, h=1600):
    """Painted albedo for terrain_far (glTF UV0): forest crowns, crop fields, a riverside village, vineyard parcels."""
    import numpy as np
    rng = np.random.default_rng(7)
    r_idx, c_idx = np.mgrid[0:h, 0:w].astype(np.float32)          # Blender rows run bottom→top
    X = FAR_X0 + (c_idx + 0.5) / w * (FAR_X1 - FAR_X0)
    Z = FAR_Z0 + (1.0 - (r_idx + 0.5) / h) * (FAR_Z1 - FAR_Z0)
    def vnoise(cell, seed):
        g = np.random.default_rng(seed).random((int((FAR_Z1 - FAR_Z0) / cell) + 3, int((FAR_X1 - FAR_X0) / cell) + 3)).astype(np.float32)
        fx, fz = (X - FAR_X0) / cell, (Z - FAR_Z0) / cell
        ix, iz = fx.astype(int), fz.astype(int); tx, tz = fx - ix, fz - iz
        tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
        return (g[iz, ix] * (1 - tx) + g[iz, ix + 1] * tx) * (1 - tz) + (g[iz + 1, ix] * (1 - tx) + g[iz + 1, ix + 1] * tx) * tz
    def cells(cx, cz, seed):                                           # random value per rectangular parcel
        g = np.random.default_rng(seed).random((400, 400)).astype(np.float32)
        return g[((Z - FAR_Z0) / cz).astype(int) % 400, ((X - FAR_X0) / cx).astype(int) % 400]
    crowns = 0.55 * vnoise(4.0, 1) + 0.3 * vnoise(9.0, 2) + 0.15 * vnoise(40.0, 3)
    forest = np.stack([0.030 + 0.02 * vnoise(80, 4), 0.060 + 0.02 * vnoise(60, 5), 0.022 + 0.0 * crowns], -1) * (0.35 + 1.1 * crowns)[..., None]
    col = forest.copy()
    north = Z < BANK_Z; south = Z > SOUTH_Z; river = ~north & ~south
    d = BANK_Z - Z; e = Z - SOUTH_Z
    # north slope: vineyard parcels, scrub, slate outcrops
    parcel = cells(36, 30, 11)
    vine = np.stack([0.075 + 0.0 * parcel, 0.115 + 0.03 * vnoise(6, 12), 0.045 + 0.0 * parcel], -1) * (0.75 + 0.5 * vnoise(3, 13))[..., None]
    scrub = np.stack([0.035, 0.062, 0.022], -1) * (0.5 + 0.9 * crowns)[..., None]
    rock = np.full(X.shape + (3,), 0.11, np.float32) * np.array([1.0, 0.98, 1.05], np.float32) * (0.7 + 0.6 * vnoise(5, 14))[..., None]
    slope_zone = north & (d > 14) & (d < 205)
    kind = np.where(parcel < 0.62, 0, np.where(parcel < 0.85, 1, 2))
    col = np.where((slope_zone & (kind == 0))[..., None], vine, col)
    col = np.where((slope_zone & (kind == 1))[..., None], scrub, col)
    col = np.where((slope_zone & (kind == 2))[..., None], rock, col)
    col = np.where((north & (d <= 14))[..., None], np.array([0.09, 0.10, 0.08], np.float32), col)          # riverside road
    col = np.where(river[..., None], np.array([0.05, 0.05, 0.04], np.float32), col)
    # south: fields on the floodplain, a village by the river, forest above
    fields = cells(70, 45, 21)
    crop = np.where(fields < 0.35, 0, np.where(fields < 0.6, 1, np.where(fields < 0.8, 2, 3)))
    palette = np.array([[0.10, 0.16, 0.05], [0.28, 0.25, 0.12], [0.16, 0.11, 0.07], [0.07, 0.12, 0.04]], np.float32)
    fcol = palette[crop] * (0.85 + 0.3 * vnoise(8, 22))[..., None]
    col = np.where((south & (e < 170))[..., None], fcol, col)
    village = south & (e > 12) & (e < 75) & (X > -420) & (X < -120)
    lots = cells(11, 11, 31)
    roof = np.where(lots < 0.45, 1, 0).astype(bool)
    roofcol = np.where((cells(11, 11, 32) < 0.5)[..., None], np.array([0.30, 0.10, 0.07], np.float32), np.array([0.16, 0.16, 0.17], np.float32))
    col = np.where((village & roof)[..., None], roofcol, np.where(village[..., None], np.array([0.12, 0.13, 0.08], np.float32), col))
    col = np.clip(col, 0, 1) ** (1 / 2.2)                              # store as sRGB
    img = bpy.data.images.new("far_albedo", w, h, alpha=False)
    img.pixels.foreach_set(np.concatenate([col, np.ones(X.shape + (1,), np.float32)], -1).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, "far_albedo.jpg"); img.file_format = "JPEG"; img.save()
    print("exported far_albedo.jpg")

def build_far():
    acc = Acc()
    x0, x1, z0, z1, s = FAR_X0, FAR_X1, FAR_Z0, FAR_Z1, 10.0
    nx, nz = int((x1 - x0) / s) + 1, int((z1 - z0) / s) + 1
    for iz in range(nz):
        z = z0 + iz * s
        for ix in range(nx):
            x = x0 + ix * s
            y = H(x, z)
            if abs(x) < 79 and abs(z) < 79: y -= 1.0                  # tuck under the near mesh
            acc.v.append(Vector((x, -z, y)))
            acc.uv.append(((x - x0) / (x1 - x0), 1.0 - (z - z0) / (z1 - z0)))
            acc.col.append(far_color(x, z, y))
    for iz in range(nz - 1):
        for ix in range(nx - 1):
            a = iz * nx + ix
            acc.f.append((a, a + nx, a + nx + 1, a + 1))
    return make_object("terrain_far", {"terrain_far": acc})

def build_water():
    acc = Acc()
    z0, z1 = BANK_Z - 4, SOUTH_Z + 4
    acc.add([Vector((-1800, -z0, 0)), Vector((1800, -z0, 0)), Vector((1800, -z1, 0)), Vector((-1800, -z1, 0))],
            [(0, 3, 2, 1)], [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    return make_object("water", {"water": acc})

# --------------------------------------------------------------------------- layout
def quat_align(normal, yaw, tilt_axis_angle, tilt):
    n = normal.normalized()
    q_tilt = Quaternion(Vector((math.cos(tilt_axis_angle), 0, math.sin(tilt_axis_angle))), tilt)
    q_yaw = Quaternion(Vector((0, 1, 0)), yaw)
    q_align = Vector((0, 1, 0)).rotation_difference(n)
    q = q_align @ q_tilt @ q_yaw
    return [round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4)]

def build_layout():
    R = random.Random(42)
    L = {"note": "PROTOTYPE layout. glTF coords: Y up, +Z downslope (south), +X east.", "vineyard": {"halfX": VX, "halfZ": VZ}}
    el, az = math.radians(20), math.radians(240)
    horiz = Vector((math.sin(az), -math.cos(az)))  # (east, south)
    L["sun"] = {"elevationDeg": 20, "azimuthDeg": 240,
                "direction": [round(horiz.x * math.cos(el), 4), round(math.sin(el), 4), round(horiz.y * math.cos(el), 4)]}
    vines = []
    for ix in range(22):
        for iz in range(23):
            x = -12.6 + ix * 1.2 + R.uniform(-0.08, 0.08)
            z = -13.2 + iz * 1.2 + R.uniform(-0.08, 0.08)
            vines.append([R.randrange(4), round(x, 3), round(H(x, z), 3), round(z, 3),
                          round(R.uniform(0, 2 * math.pi), 3), round(R.uniform(0.92, 1.08), 3)])
    L["vines"] = {"variants": 4, "fields": "variant,x,y,z,yaw,scale", "items": vines}
    nb = []
    for iz in range(-60, 75):
        for ix in range(-66, 67):
            x, z = ix * 1.2 + R.uniform(-0.1, 0.1), iz * 1.2 + R.uniform(-0.1, 0.1)
            if abs(x) < VX + 2.5 and abs(z) < VZ + 2.5: continue          # our block + a path around it
            if not neighbour_planted(x, z): continue                          # road, forest, fallow parcels
            if abs((x + 7) % 36 - 18) < 1.4 or abs((z + 11) % 30 - 15) < 1.2: continue   # parcel paths
            nb.append([R.randrange(2), round(x, 3), round(H(x, z), 3), round(z, 3),
                       round(R.uniform(0, 2 * math.pi), 3), round(R.uniform(0.9, 1.1), 3)])
    L["neighbours"] = {"variants": 2, "model": "vine_lod2_{variant}.glb", "fields": "variant,x,y,z,yaw,scale", "items": nb}
    slate = []
    while len(slate) < 45000:
        x, z = R.uniform(-45, 45), R.uniform(-45, 45)
        inside = abs(x) < VX + 1 and abs(z) < VZ + 1
        if not inside and R.random() > 0.45: continue
        if grass_mask(x, z) > 0.8 and R.random() < 0.7: continue
        s = 0.035 + 0.17 * R.random() ** 3
        q = quat_align(normal_at(x, z), R.uniform(0, 2 * math.pi), R.uniform(0, math.pi), R.uniform(0, 0.45))
        slate.append([R.randrange(5), round(x, 3), round(H(x, z) + 0.01 - s * 0.06, 3), round(z, 3), *q, round(s, 3)])
    L["slate"] = {"variants": 5, "fields": "variant,x,y,z,qx,qy,qz,qw,scale", "items": slate}
    grass = []
    while len(grass) < 7000:
        x, z = R.uniform(-60, 60), R.uniform(-60, 60)
        if R.random() > grass_mask(x, z) * 0.9 + 0.02: continue
        grass.append([R.randrange(3), round(x, 3), round(H(x, z) - 0.02, 3), round(z, 3),
                      round(R.uniform(0, 2 * math.pi), 3), round(R.uniform(0.18, 0.45), 3)])
    L["grass"] = {"variants": 3, "fields": "variant,x,y,z,yaw,scale", "items": grass}
    def cam(px, pz, eye, tx, tz, t_off):
        return {"position": [px, round(H(px, pz) + eye, 3), pz], "target": [tx, round(H(tx, tz) + t_off, 3), tz]}
    vc = min(vines, key=lambda v: (v[1] - 2.4) ** 2 + (v[3] + 1.2) ** 2)
    L["cameras"] = {
        "row_downhill":   cam(0.0, -10.0, 1.65, 0.0, 30.0, -2.0),
        "uphill":         cam(0.0, 12.5, 1.60, 0.0, -12.0, 1.0),
        "valley_view":    cam(9.0, 15.5, 1.70, -40.0, 400.0, -20.0),
        "drone":          {"position": [-38.0, round(H(-38, 32) + 26, 3), 32.0], "target": [0.0, round(H(0, 0), 3), 0.0]},
        "vine_close":     {"position": [round(vc[1] + 0.85, 3), round(vc[2] + 1.15, 3), round(vc[3] + 0.75, 3)],
                           "target": [vc[1], round(vc[2] + 0.95, 3), vc[3]]},
    }
    L["near"] = NEAR
    L["water"] = {"y": 0.0}
    with open(os.path.join(OUT, "layout.json"), "w") as fh:
        json.dump(L, fh, separators=(",", ":"))
    print("layout:", len(vines), "vines,", len(nb), "neighbours,", len(slate), "slate,", len(grass), "grass")

# --------------------------------------------------------------------------- leaf vein detail texture
def write_leaf_texture(size=512):
    """Albedo multiplier in leaf UV space: petiole at (0.5, 0), blade centre (0.5, 0.5). Light veins, soft mottling."""
    import numpy as np
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    u, v = (xs + 0.5) / size, (ys + 0.5) / size
    val = np.ones((size, size), np.float32)
    def seg(ax, ay, bx, by, width, gain):
        dx, dy = bx - ax, by - ay
        t = np.clip(((u - ax) * dx + (v - ay) * dy) / (dx * dx + dy * dy), 0, 1)
        d = np.hypot(u - (ax + t * dx), v - (ay + t * dy))
        w = width * (1.0 - 0.6 * t)
        return np.clip(1 - d / w, 0, 1) ** 1.5 * gain
    veins = np.zeros_like(val)
    base = (0.5, 0.02)
    for th in (0.0, math.radians(62), -math.radians(62), math.radians(128), -math.radians(128)):
        tipx, tipy = 0.5 + 0.47 * math.sin(th), 0.5 + 0.47 * math.cos(th)
        veins = np.maximum(veins, seg(*base, tipx, tipy, 0.010, 0.30))
        for k in range(1, 6):                       # secondary veins towards the margin
            f = k / 6.0
            px, py = base[0] + (tipx - base[0]) * f, base[1] + (tipy - base[1]) * f
            for side in (-1, 1):
                a = th + side * math.radians(48)
                L = 0.20 * (1 - 0.5 * f)
                veins = np.maximum(veins, seg(px, py, px + L * math.sin(a), py + L * math.cos(a), 0.005, 0.18))
    n = np.zeros_like(val)
    for fr, amp in ((9, 0.05), (23, 0.03), (61, 0.02)):
        n += amp * np.sin(u * fr * 6.28 + np.sin(v * fr * 3.1) * 2) * np.sin(v * fr * 5.9 + np.cos(u * fr * 2.3) * 2)
    val = 0.92 + n
    r = np.clip(val + veins * 1.05, 0, 2) / 1.35
    g = np.clip(val + veins * 1.00, 0, 2) / 1.35
    b = np.clip(val + veins * 0.55, 0, 2) / 1.35
    img = bpy.data.images.new("leaf_detail", size, size, alpha=False)
    px = np.stack([r, g, b, np.ones_like(r)], -1).astype(np.float32).ravel()
    img.pixels.foreach_set(px)
    img.filepath_raw = os.path.join(OUT, "leaf_detail.png"); img.file_format = "PNG"; img.save()
    print("exported leaf_detail.png")

# --------------------------------------------------------------------------- main
bpy.ops.wm.read_factory_settings(use_empty=True)
write_leaf_texture()
write_far_albedo()
for i in range(4): export(build_vine(i), f"vine_{i}.glb")
LOD = 1
for i in range(4):
    ob = build_vine(i); ob.name = f"vine_{i}_lod1"; export(ob, f"vine_{i}_lod1.glb")
LOD = 0
for i in range(2): export(build_vine_lod2(i), f"vine_lod2_{i}.glb")
for i in range(5): export(build_slate(i), f"slate_{i}.glb")
for i in range(3): export(build_grass(i), f"grass_{i}.glb")
export(build_near(), "terrain_near.glb")
export(build_far(), "terrain_far.glb")
export(build_water(), "water.glb")
build_layout()
print("DONE")
