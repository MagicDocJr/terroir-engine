# Vineyard assets for the 3D view (game/src/view3d). Run headless via ../sync_assets3d.sh:
#   blender -b --factory-startup -P build_vineyard.py -- <out_dir>
#
# Output (glTF, Y up, metres) into <out_dir>:
#   vine_<training>_g<growth>.glb   training ∈ einzelpfahl | guyot | cordon, growth 0..4
#       each file holds 8 nodes: s<seed>_lod<lod>, seed 0..1, lod 0..3 (same plant, cheaper geometry;
#       lod3 is a ~600-triangle stand-in for distant and neighbouring vines)
#       growth: 0 dormant (pruned wood) · 1 budburst · 2 shoots · 3 flowering (inflorescences) · 4 full canopy + bunches
#       VSP vines (guyot, cordon): row along local +X, canopy in the XY plane; Einzelpfahl: round, on a stake.
#       UV2 on leaves = (per-leaf random, position along the shoot 0..1); on berries = (per-bunch random, 1).
#       Berry vertex colour: R = bunch tone, G = per-berry random (colour is set in the shader from the sim).
#   stone_<0..4>.glb (flat chips) · pebble_<0..2>.glb (rounded gravel) · grass_<0..2>.glb (tufts)
#   leaf_detail.png (vein/mottle multiplier in leaf UV space)
#   tree_card.glb + trees_atlas.png + trees.json (4 impostor trees: 3 broadleaf, 1 conifer; cell heights in metres)
import bpy, bmesh, math, random, json, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import V, Acc, make_object, tube, catmull, leaf_blade, leaf_card, berry_sphere, export, ss

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
C.set_out(OUT)
ONLY = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else ""

GROWTH = [0.0, 0.06, 0.40, 0.80, 1.0]          # fraction of full shoot length per growth level
LEAF_SCALE = [0.0, 0.22, 0.70, 0.95, 1.0]
WHITE = (1, 1, 1)
VSP = {  # fruiting wire height, canopy top (topping height), in-row reach of the cane/arms
    "guyot":  dict(hw=0.80, top=1.75, reach=0.85),
    "cordon": dict(hw=0.95, top=1.95, reach=0.62),
}


class Emit:
    """Per-vine emission state: LOD-dependent thinning that never changes the random sequence."""
    def __init__(self):
        self.leaf_i = 0
        self.berry_i = 0

    def keep_leaf(self):
        self.leaf_i += 1
        return C.LOD < 2 or self.leaf_i % (3 if C.LOD == 2 else 7) == 0

    def leaf_size(self, s):
        return s * (1.0 if C.LOD < 2 else (1.75 if C.LOD == 2 else 2.5))


def leaf_col(R, frac, g, node):
    k = R.uniform(-1, 1)
    if g == 1:                                                    # budburst: pale, bronze-tinged rosettes
        return (0.20 + 0.04 * k, 0.24 + 0.03 * k, 0.05) if R.random() < 0.6 else (0.24, 0.18, 0.06)
    col = (0.075 + 0.02 * k, 0.20 + 0.05 * k, 0.030)
    if frac > 0.75 or g == 2 and frac > 0.5:
        col = (0.11 + 0.02 * k, 0.28 + 0.04 * k, 0.045)          # young tip leaves
    if g == 4 and node <= 2 and R.random() < 0.35:
        col = (0.26, 0.24, 0.05)                                  # senescing basal leaves
    return col


def cluster(P, R, E, p, cdir, g, scale=1.0):
    """Bunch hanging from node p. g=3: inflorescence (tiny), g=4: full bunch."""
    ped0 = p + cdir * 0.03
    ctop = ped0 + cdir * 0.02 + V((0, 0, -0.03))
    if C.LOD < 2:
        tube(P["vine_bark"], [p, ped0, ctop], [0.003] * 3, 3, WHITE)
    axis = V((R.uniform(-.25, .25), R.uniform(-.25, .25), -1)).normalized()
    small = g == 3
    lc = R.uniform(0.09, 0.13) * scale * (0.55 if small else 1.0)
    a1 = axis.orthogonal().normalized(); a2 = axis.cross(a1)
    tone = R.random()
    bid = R.random()
    n = 46
    for b in range(n):
        tt = R.random() ** 0.8
        w = 0.030 * scale * (1 - 0.55 * tt) * (1 - 0.3 * tt ** 3) * (0.6 if small else 1.0)
        rho = w * (0.45 + 0.55 * math.sqrt(R.random()))
        an = R.uniform(0, 2 * math.pi)
        c = ctop + axis * (tt * lc) + (a1 * math.cos(an) + a2 * math.sin(an)) * rho
        br = (0.0066 if not small else 0.0030) * scale * R.uniform(0.88, 1.08)
        brand = R.random()
        col = (tone, brand, 0.0)
        if C.LOD == 0:
            berry_sphere(P["vine_berry"], c, br, col, (bid, 1.0))
        elif C.LOD == 1:
            if b % 4 == 0: berry_sphere(P["vine_berry"], c, br * 1.6, col, (bid, 1.0), seg=4, rings=2)
        elif C.LOD == 2 and b % 23 == 0:
            berry_sphere(P["vine_berry"], c, br * 2.8, col, (bid, 1.0), seg=4, rings=2)
        elif C.LOD == 3 and b == 0:
            berry_sphere(P["vine_berry"], c + axis * lc * 0.35, br * 4.2, col, (bid, 1.0), seg=4, rings=2)


def leaves_on_shoot(P, R, E, spts, L, g, out_fn, cluster_nodes, lateral_p, cluster_dir_fn):
    """Leaves (+laterals, clusters) at the nodes of a shoot polyline spts."""
    node = 0
    spacing = 0.072 * max(0.55, GROWTH[g])
    dist, next_node = 0.0, spacing
    for i in range(1, len(spts)):
        dist += (spts[i] - spts[i - 1]).length
        if dist < next_node:
            continue
        next_node += R.uniform(0.87, 1.08) * spacing
        node += 1
        p = spts[i]
        t_dir = (spts[min(i + 1, len(spts) - 1)] - spts[i - 1]).normalized()
        alt = 1 if node % 2 else -1
        out, pdir, normal, tip = out_fn(R, p, t_dir, alt)
        pet = R.uniform(0.05, 0.08) * LEAF_SCALE[g]
        attach = p + pdir * pet
        if C.LOD == 0:
            tube(P["vine_bark"], [p, p + pdir * pet * 0.5 + V((0, 0, 0.01 * LEAF_SCALE[g])), attach], [0.0025] * 3, 3, WHITE)
        frac = min(1.0, dist / (L + 0.01))
        size = R.uniform(0.13, 0.19) * (1.15 - 0.45 * frac) * LEAF_SCALE[g]
        col = leaf_col(R, frac, g, node)
        lr = R.random()
        if E.keep_leaf():
            leaf_card(P["vine_leaf"], attach, tip, normal, E.leaf_size(size), col, (lr, frac))
        if g >= 4 and node >= 3 and R.random() < lateral_p:                  # lateral shoot, 2-3 leaves
            ldir = (out * 0.6 + V((0, 0, 0.55))).normalized()
            for q in range(R.randint(2, 3)):
                la = p + ldir * (0.05 + 0.06 * q)
                ln = (ldir * 0.5 + out * 0.5 + V((0, 0, 0.7)) + V((R.uniform(-.4, .4), R.uniform(-.4, .4), 0))).normalized()
                lt = (ldir * 0.3 + V((0, 0, -0.8))).normalized()
                lt = (lt - ln * lt.dot(ln)).normalized()
                k = R.uniform(-1, 1)
                s2 = size * R.uniform(0.55, 0.8)
                lr2 = R.random()
                if E.keep_leaf():
                    leaf_card(P["vine_leaf"], la, lt, ln, E.leaf_size(s2), (0.10 + 0.02 * k, 0.26 + 0.04 * k, 0.04), (lr2, 0.9))
        if g >= 3 and node in cluster_nodes[0] and R.random() < cluster_nodes[1][cluster_nodes[0].index(node)]:
            cluster(P, R, E, p, cluster_dir_fn(p, alt, out), g)


def dormant_bud(P, p, d):
    """Growth level 0: a winter bud (a small pointed ovoid) sitting on the one-year wood at p, pointing along d.
    Near detail only (LOD 0-1): it is what the pruner counts."""
    if C.LOD > 1:
        return
    d = d.normalized()
    a1 = d.orthogonal().normalized()
    a2 = d.cross(a1)
    r = 0.0058
    seg, rings = (7, 4) if C.LOD == 0 else (4, 2)
    c = p + d * r * 0.7
    verts, faces, uvs, cols = [], [], [], []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        k = 1.0 - 0.35 * (i / rings)                        # narrower towards the tip
        for j in range(seg):
            th = 2 * math.pi * j / seg
            verts.append(c + (a1 * math.cos(th) + a2 * math.sin(th)) * (r * k * math.sin(phi)) + d * (r * 1.7 * math.cos(phi)))
            uvs.append((j / seg, i / rings)); cols.append((0.8, 0.7, 0.62))
    for i in range(rings):
        for j in range(seg):
            a = i * seg + j; b = i * seg + (j + 1) % seg
            faces.append((a, a + seg, b + seg, b))
    P["vine_bark"].add(verts, faces, uvs, cols, [(0.0, 0.0)] * len(verts))


def budburst_rosette(P, R, E, p, up):
    """Growth level 1: a woolly bud opened into 2-4 tiny leaves."""
    for q in range(R.randint(2, 4)):
        az = R.uniform(0, 2 * math.pi)
        d = (up * 0.8 + V((math.cos(az), math.sin(az), 0)) * 0.6).normalized()
        attach = p + d * R.uniform(0.008, 0.02)
        normal = (up + V((math.cos(az), math.sin(az), 0)) * 0.5).normalized()
        tip = (d - normal * d.dot(normal)).normalized()
        col = leaf_col(R, 1.0, 1, 1)
        lr = R.random()
        if E.keep_leaf() or C.LOD >= 2:
            leaf_card(P["vine_leaf"], attach, tip, normal, R.uniform(0.022, 0.042) * (1.0 if C.LOD < 2 else 1.5), col, (lr, 1.0), cup=1.8)


# --------------------------------------------------------------------------- Einzelpfahl (single stake, heart-shaped bows)
def build_einzelpfahl(seed, g):
    R = random.Random(1000 + seed)
    E = Emit()
    P = {k: Acc() for k in ("vine_wood", "vine_bark", "vine_leaf", "vine_berry")}
    top = 1.85 + R.uniform(-0.06, 0.06)
    lean = V((R.uniform(-0.03, 0.03), R.uniform(-0.03, 0.03), 0))
    stake = [V((0, 0, -0.25)) + lean * -0.25, V((0, 0, top)) + lean * top]
    stake = [stake[0].lerp(stake[1], t / 6) for t in range(7)]
    tube(P["vine_wood"], stake, [0.028] * 7, 8, WHITE, v_scale=0.4, cap=True)
    head_h = R.uniform(0.55, 0.70)
    phi = R.uniform(0, 2 * math.pi)
    side = V((math.cos(phi), math.sin(phi), 0))
    fwd = V((-side.y, side.x, 0))
    base = fwd * 0.06
    tr = [base + V((R.uniform(-0.03, 0.03), R.uniform(-0.03, 0.03), head_h * k / 5)) for k in range(6)]
    tr[0] = base + V((0, 0, -0.1))
    head = tr[-1]
    tube(P["vine_bark"], catmull(tr, 4), [0.038 - 0.012 * k / 21 for k in range(21)], 8, WHITE, v_scale=0.3)
    bows = []
    for s in (-1, 1):
        sd = side * s
        ctrl = [head,
                head + sd * 0.06 + V((0, 0, 0.26)),
                head + sd * 0.24 + V((0, 0, 0.36)) + fwd * R.uniform(-0.05, 0.05),
                head + sd * 0.34 + V((0, 0, 0.16)) + fwd * R.uniform(-0.05, 0.05),
                head + sd * 0.22 + V((0, 0, -0.04)),
                V((0, 0, head.z - 0.10)) + sd * 0.035]
        pts = catmull(ctrl, 6)
        tube(P["vine_bark"], pts, [0.012] * len(pts), 6, WHITE, v_scale=0.3)
        bows.append(pts)
    total = 0
    counts = [R.randint(6, 8), R.randint(6, 8)]
    ntot = sum(counts)
    for bi, bow in enumerate(bows):
        nshoots = counts[bi]
        for k in range(nshoots):
            pb = bow[int((0.12 + 0.72 * k / max(1, nshoots - 1)) * (len(bow) - 1))]
            az = phi + 2 * math.pi * (total + 0.5 * bi) / ntot + R.uniform(-0.25, 0.25)
            total += 1
            radial = V((math.cos(az), math.sin(az), 0))
            L = R.uniform(0.75, 1.25) * GROWTH[g]
            rc = R.uniform(0.18, 0.32)
            if g == 0:
                dormant_bud(P, pb + (radial * 0.5 + V((0, 0, 1))).normalized() * 0.009, (radial * 0.6 + V((0, 0, 1))).normalized())
                continue
            if g == 1:
                budburst_rosette(P, R, E, pb, (radial * 0.5 + V((0, 0, 1))).normalized())
                continue
            r0 = V((pb.x, pb.y, 0)).length
            pts = []
            for i in range(9):
                t = i / 8
                h = pb.z + L * t
                h = min(h, top + 0.10 + 0.05 * t)                           # topped
                r = r0 + (rc * max(0.4, GROWTH[g]) - r0) * math.sin(t * math.pi * 0.55) + 0.03 * t * t
                tang = V((-radial.y, radial.x, 0))
                pts.append(radial * r + tang * (0.04 * math.sin(t * 5 + k)) + V((0, 0, h)))
            spts = catmull(pts, 3)
            if C.LOD < 3:
                tube(P["vine_bark"], spts, [0.0065 - 0.003 * i / len(spts) for i in range(len(spts))], 4, WHITE, v_scale=0.3)

            def out_fn(R, p, t_dir, alt, radial=radial):
                out = V((p.x, p.y, 0)).normalized() if V((p.x, p.y, 0)).length > 1e-3 else radial
                perp = t_dir.cross(out).normalized() * alt
                pdir = (out * 0.75 + perp * 0.55 + V((0, 0, 0.15))).normalized()
                normal = (pdir * 0.7 + V((0, 0, 0.8)) + V((R.uniform(-.3, .3), R.uniform(-.3, .3), 0))).normalized()
                tip = (pdir * 0.5 + V((0, 0, -0.75))).normalized()
                tip = (tip - normal * tip.dot(normal)).normalized()
                return out, pdir, normal, tip

            def cdir_fn(p, alt, out):
                return -(V((0, 0, 1)).cross(out).normalized() * alt)
            leaves_on_shoot(P, R, E, spts, L, g, out_fn, ([3, 4], [0.85, 0.35]), 0.55, cdir_fn)
    return P


# --------------------------------------------------------------------------- VSP: Guyot (cane) and Cordon (spurs)
def build_vsp(kind, seed, g):
    R = random.Random((2000 if kind == "guyot" else 3000) + seed)
    E = Emit()
    P = {k: Acc() for k in ("vine_wood", "vine_bark", "vine_leaf", "vine_berry")}
    cfg = VSP[kind]
    hw, top, reach = cfg["hw"], cfg["top"], cfg["reach"]
    # support stake next to the trunk (up to the fruiting wire)
    tube(P["vine_wood"], [V((-0.035, 0.03, -0.2)), V((-0.035, 0.03, hw + 0.30))], [0.007, 0.007], 6, WHITE, cap=True)
    head_z = hw - (0.08 if kind == "guyot" else 0.03)
    tr = [V((R.uniform(-0.02, 0.02), R.uniform(-0.02, 0.02), head_z * k / 5)) for k in range(6)]
    tr[0] = V((0, 0, -0.1)); tr[-1] = V((0.0, 0.0, head_z))
    tube(P["vine_bark"], catmull(tr, 4), [0.034 - 0.010 * k / 21 for k in range(21)], 8, WHITE, v_scale=0.3)
    buds = []                                       # (position, lateral sign)
    if kind == "guyot":
        ctrl = [V((0, 0, head_z)), V((0.05, 0.0, hw + 0.07)), V((0.16, 0.0, hw + 0.01))]
        x = 0.28
        while x <= reach:
            ctrl.append(V((x, R.uniform(-0.01, 0.01), hw + 0.005 * math.sin(x * 9))))
            x += 0.12
        cane = catmull(ctrl, 4)
        tube(P["vine_bark"], cane, [0.010 - 0.003 * i / len(cane) for i in range(len(cane))], 6, WHITE, v_scale=0.3)
        spur = [V((0, 0, head_z)), V((-0.04, 0.01, hw + 0.0)), V((-0.06, 0.015, hw + 0.05))]
        tube(P["vine_bark"], catmull(spur, 3), [0.011] * 7, 6, WHITE, v_scale=0.3)
        n = R.randint(7, 9)
        for k in range(n):
            t = 0.25 + 0.72 * k / max(1, n - 1)
            buds.append((cane[int(t * (len(cane) - 1))], 1 if k % 2 else -1))
        buds.append((spur[-1], 1)); buds.append((spur[1], -1))
    else:
        for sgn in (-1, 1):
            ctrl = [V((0, 0, head_z)), V((sgn * 0.08, 0, hw + 0.01))]
            x = 0.2
            while x <= reach:
                ctrl.append(V((sgn * x, R.uniform(-0.012, 0.012), hw + 0.006 * math.sin(x * 7))))
                x += 0.14
            arm = catmull(ctrl, 4)
            tube(P["vine_bark"], arm, [0.022 - 0.008 * i / len(arm) for i in range(len(arm))], 7, WHITE, v_scale=0.3)
            x = 0.14
            k = 0
            while x <= reach:
                p = min(arm, key=lambda q: abs(q.x - sgn * x))
                ys = 1 if k % 2 else -1
                tipp = p + V((R.uniform(-0.01, 0.01), ys * 0.02, 0.045))
                tube(P["vine_bark"], [p, p.lerp(tipp, 0.5), tipp], [0.012, 0.011, 0.010], 6, WHITE, cap=True)
                buds.append((p.lerp(tipp, 0.6), ys)); buds.append((tipp, -ys))
                x += R.uniform(0.13, 0.17)
                k += 1
    for bi, (b, ys) in enumerate(buds):
        L = (top - b.z + 0.12) * R.uniform(0.88, 1.08) * GROWTH[g]
        lean = ys * R.uniform(0.02, 0.10)
        # shoots splay a little along the row (the two shoots of a spur apart), so the summer hedge closes between them
        drift = R.uniform(-0.14, 0.14) + (0.06 if bi % 2 else -0.06) * (1.0 if kind == "cordon" else 0.5)
        wig = R.uniform(0.015, 0.04)
        if g == 0:
            dormant_bud(P, b + V((0, ys * 0.004, 0.008)), V((0, ys * 0.45, 1)))
            continue
        if g == 1:
            budburst_rosette(P, R, E, b, V((0, 0, 1)))
            continue
        pts = []
        for i in range(9):
            t = i / 8
            z = min(b.z + L * t, top + 0.03 * t)                           # hedged at the top
            pts.append(V((b.x + drift * t + wig * math.sin(t * 4.5 + bi * 1.7), b.y + lean * math.sin(t * math.pi / 2) + 0.015 * math.sin(t * 6 + bi), z)))
        spts = catmull(pts, 3)
        if C.LOD < 3:
            tube(P["vine_bark"], spts, [0.0065 - 0.003 * i / len(spts) for i in range(len(spts))], 4, WHITE, v_scale=0.3)

        def out_fn(R, p, t_dir, alt):
            out = V((0, alt, 0))
            pdir = (V((R.uniform(-0.6, 0.6), alt * 0.85, 0.30))).normalized()
            normal = (V((R.uniform(-0.3, 0.3), alt * 0.75, 0.62))).normalized()
            tip = (pdir * 0.4 + V((0, 0, -0.8))).normalized()
            tip = (tip - normal * tip.dot(normal)).normalized()
            return out, pdir, normal, tip

        def cdir_fn(p, alt, out):
            return V((R.uniform(-0.4, 0.4), -alt * 0.9, 0)).normalized()
        leaves_on_shoot(P, R, E, spts, L, g, out_fn, ([2, 3], [0.8, 0.45]), 0.4, cdir_fn)
    return P


def build_vine_file(training, g):
    obs = []
    for seed in range(2):
        for lod in range(4):
            C.LOD = lod
            P = build_einzelpfahl(seed, g) if training == "einzelpfahl" else build_vsp(training, seed, g)
            obs.append(make_object(f"s{seed}_lod{lod}", P, smooth=True))
    C.LOD = 0
    export(obs, f"vine_{training}_g{g}.glb")
    C.clear_scene()


# --------------------------------------------------------------------------- stones, gravel, grass
def build_stone(idx):
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
            [(v.co.x + 0.5, v.co.y + 0.5) for v in bm.verts], [(1, 1, 1)] * len(bm.verts))
    bm.free()
    return make_object(f"stone_{idx}", {"stone": acc}, smooth=False)


def build_pebble(idx):
    R = random.Random(2500 + idx)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    sx, sy, sz = R.uniform(0.8, 1.2), R.uniform(0.6, 0.95), R.uniform(0.35, 0.6)
    for v in bm.verts:
        n = v.co.normalized()
        v.co = V((v.co.x * sx, v.co.y * sy, v.co.z * sz)) * (1 + R.uniform(-0.08, 0.08))
    acc = Acc()
    bm.verts.index_update()
    acc.add([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces],
            [(v.co.x + 0.5, v.co.y + 0.5) for v in bm.verts], [(1, 1, 1)] * len(bm.verts))
    bm.free()
    return make_object(f"pebble_{idx}", {"stone": acc}, smooth=True)


def build_grass(idx):
    R = random.Random(3000 + idx)
    acc = Acc()
    for b in range(22):
        ang = R.uniform(0, 2 * math.pi)
        d = V((math.cos(ang), math.sin(ang), 0))
        side = V((-d.y, d.x, 0))
        base = d * R.uniform(0, 0.12)
        hgt = R.uniform(0.55, 1.0); bend = R.uniform(0.15, 0.5); wid = R.uniform(0.015, 0.03)
        verts, uvs, cols, faces = [], [], [], []
        for s in range(4):
            t = s / 3
            c = base + d * (bend * t * t) + V((0, 0, hgt * t))
            ww = wid * (1 - t * 0.9)
            for sgn in (-1, 1):
                verts.append(c + side * ww * sgn); uvs.append(((sgn + 1) / 2, t))
                k = R.uniform(-0.02, 0.02)
                cols.append((0.05 + 0.20 * t + k, 0.09 + 0.20 * t + k, 0.02 + 0.03 * t))
        for s in range(3):
            a = s * 2
            faces.append((a, a + 1, a + 3, a + 2))
        acc.add(verts, faces, uvs, cols)
    return make_object(f"grass_{idx}", {"grass": acc}, smooth=True)


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
        for k in range(1, 6):
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
    # alpha channel = vein mask (used for interveinal chlorosis in the leaf shader)
    img = bpy.data.images.new("leaf_detail", size, size, alpha=True)
    px = np.stack([r, g, b, np.clip(veins * 3.0, 0, 1)], -1).astype(np.float32).ravel()
    img.pixels.foreach_set(px)
    img.alpha_mode = "STRAIGHT"
    img.filepath_raw = os.path.join(OUT, "leaf_detail.png"); img.file_format = "PNG"; img.save()
    print("exported leaf_detail.png")


# --------------------------------------------------------------------------- far-hill tree impostors
def build_tree(idx, R):
    """Procedural broadleaf (0-2) or conifer (3) for impostor rendering. Blender coords, Z up, metres."""
    P = {"vine_bark": Acc(), "vine_leaf": Acc()}
    conifer = idx == 3
    height = 22.0 if conifer else R.uniform(17, 21)
    if conifer:
        tube(P["vine_bark"], [V((0, 0, 0)), V((0, 0, height))], [0.35, 0.05], 8, (1, 1, 1))
        for k in range(46):
            h = 2.5 + (height - 2.5) * k / 46
            rad = (1 - (h - 2.5) / (height - 2.5)) * 4.2 + 0.3
            for j in range(7):
                a = R.uniform(0, 2 * math.pi)
                base = V((0, 0, h))
                tip = base + V((math.cos(a) * rad, math.sin(a) * rad, -0.6 - 0.2 * rad))
                for q in range(int(4 + rad * 2)):
                    t = (q + 0.5) / (4 + rad * 2)
                    p = base.lerp(tip, t)
                    n = V((math.cos(a), math.sin(a), 0.9)).normalized()
                    leaf_blade(P["vine_leaf"], p, V((0, 0, -1)) - n * (-n.z), n, 0.9,
                               (0.010 + R.uniform(0, 0.006), 0.030 + R.uniform(0, 0.01), 0.020))
    else:
        def branch(p, d, length, radius, depth):
            q = p + d * length
            tube(P["vine_bark"], [p, p.lerp(q, 0.5) + V((R.uniform(-.3, .3), R.uniform(-.3, .3), 0)), q], [radius, radius * 0.8, radius * 0.6], 6, (1, 1, 1))
            if depth == 0:
                for _ in range(95):
                    c = q + V((R.gauss(0, 1.5), R.gauss(0, 1.5), R.gauss(0.3, 1.0)))
                    n = (c - q + V((0, 0, 0.8))).normalized()
                    tipd = V((0, 0, -1)); tipd = (tipd - n * tipd.dot(n)).normalized()
                    k = R.uniform(-1, 1)
                    leaf_blade(P["vine_leaf"], c, tipd, n, R.uniform(0.9, 1.3),
                               (0.022 + 0.008 * k, 0.050 + 0.014 * k, 0.014 if idx != 2 else 0.022))
                return
            for _ in range(3 if depth > 1 else 4):
                nd = (d + V((R.uniform(-.55, .55), R.uniform(-.55, .55), R.uniform(0.35, 1.0)))).normalized()
                branch(q, nd, length * R.uniform(0.55, 0.7), radius * 0.6, depth - 1)
        trunk_h = R.uniform(2.8, 4.0)
        tube(P["vine_bark"], [V((0, 0, 0)), V((0, 0, trunk_h))], [0.45, 0.32], 8, (1, 1, 1))
        branch(V((0, 0, trunk_h)), V((0, 0, 1)), height * 0.30, 0.30, 3)
        for _ in range(4):
            d = V((R.uniform(-0.5, 0.5), R.uniform(-0.5, 0.5), 1.0)).normalized()
            branch(V((0, 0, trunk_h * R.uniform(0.9, 1.4))), d, height * 0.25, 0.24, 3)
    return make_object(f"tree_{idx}", P, smooth=True), height


def render_tree_atlas(R):
    import numpy as np
    cells, heights = [], []
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 512, 1024
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.85, 0.9, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(35), 0, math.radians(20))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"
    for idx in range(4):
        for o in list(sc.collection.objects):
            if o.name.startswith("tree_"): bpy.data.objects.remove(o)
        ob, hgt = build_tree(idx, R)
        for m in bpy.data.materials:                      # leaves take their colour from vertex colours
            b = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
            if b and m.name.startswith("vine_leaf") and not any(n.type == "VERTEX_COLOR" for n in m.node_tree.nodes):
                vc = m.node_tree.nodes.new("ShaderNodeVertexColor"); vc.layer_name = ""
                m.node_tree.links.new(vc.outputs["Color"], b.inputs["Base Color"])
        bpy.context.view_layer.update()
        bb = [ob.matrix_world @ V(c) for c in ob.bound_box]
        top = max(p.z for p in bb); half_w = max(max(abs(p.x) for p in bb), max(abs(p.y) for p in bb))
        scale = max(top * 1.02, 4 * half_w * 1.02)
        heights.append(scale)
        cam.data.ortho_scale = scale
        cam.location = (0, -80, scale / 2); cam.rotation_euler = (math.radians(90), 0, 0)
        path = os.path.join(OUT, f"_tree_{idx}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        px = np.empty(512 * 1024 * 4, np.float32); img.pixels.foreach_get(px)
        cells.append(px.reshape(1024, 512, 4))
        bpy.data.images.remove(img); os.remove(path)
    atlas = np.concatenate(cells, axis=1)
    img = bpy.data.images.new("trees_atlas", 2048, 1024, alpha=True)
    img.pixels.foreach_set(atlas.ravel()); img.alpha_mode = "STRAIGHT"
    img.filepath_raw = os.path.join(OUT, "trees_atlas.png"); img.file_format = "PNG"; img.save()
    print("exported trees_atlas.png")
    for o in list(sc.collection.objects): bpy.data.objects.remove(o)
    return heights


def build_tree_card():
    acc = Acc()
    for a in (0.0, math.pi / 2):
        dx, dy = 0.25 * math.cos(a), 0.25 * math.sin(a)
        acc.add([V((-dx, -dy, 0)), V((dx, dy, 0)), V((dx, dy, 1)), V((-dx, -dy, 1))], [(0, 1, 2, 3)],
                [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    return make_object("tree_card", {"tree_card": acc}, smooth=False)


# --------------------------------------------------------------------------- main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    C.set_out(OUT)
    if ONLY in ("", "misc"):
        write_leaf_texture()
        heights = render_tree_atlas(random.Random(2025))
        export(build_tree_card(), "tree_card.glb"); C.clear_scene()
        with open(os.path.join(OUT, "trees.json"), "w") as fh:
            json.dump({"cells": 4, "cellMeters": [round(h, 2) for h in heights],
                       "hint": "variant v uses atlas u in [v/4,(v+1)/4]; card is 0.5 wide x 1 high, scale by cellMeters"}, fh)
        for i in range(5): export(build_stone(i), f"stone_{i}.glb"); C.clear_scene()
        for i in range(3): export(build_pebble(i), f"pebble_{i}.glb"); C.clear_scene()
        for i in range(3): export(build_grass(i), f"grass_{i}.glb"); C.clear_scene()
    for training in ("einzelpfahl", "guyot", "cordon"):
        if ONLY not in ("", training):
            continue
        for g in range(5):
            build_vine_file(training, g)
    print("DONE")


main()
