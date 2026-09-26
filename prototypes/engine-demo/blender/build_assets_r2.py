# PROTOTYPE — throwaway. Round-2 shared assets: winery (cellar + fermentation hall), barrels, tanks,
# far-hill tree impostors, weather/time presets and dashboard data. Run via ../build_assets_r2.sh.
#
# Output → assets/models_r2/  (glTF convention: Y up, metres)
#   barrique.glb  fuder.glb  tank.glb  cellar.glb  hall.glb  tree_card.glb  trees_atlas.png
#   layout_r2.json  trees.json  dashboard_data.json
import bpy, bmesh, math, random, json, sys, os
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

# Reuse round-1 helpers (terrain function, mesh builders, exporter) without running its main().
ns = {"R2_IMPORT": True, "__name__": "r1_helpers", "__file__": os.path.join(HERE, "build_assets.py")}
exec(compile(open(ns["__file__"]).read(), ns["__file__"], "exec"), ns)
ns["OUT"] = OUT
Acc, make_object, tube, export, H, fbm, ss = (ns[k] for k in ("Acc", "make_object", "tube", "export", "H", "fbm", "ss"))
leaf_blade = ns["leaf_blade"]
ns["MAT"].update({
    "barrel_oak":   ((0.42, 0.28, 0.17), 0.70, False),
    "barrel_head":  ((0.38, 0.25, 0.15), 0.75, False),
    "barrel_hoop":  ((0.10, 0.10, 0.10), 0.45, False),
    "barrel_bung":  ((0.85, 0.85, 0.80), 0.50, False),
    "rack_wood":    ((0.22, 0.15, 0.09), 0.85, True),
    "cellar_wall":  ((1.0, 1.0, 1.0), 0.85, False),
    "cellar_floor": ((1.0, 1.0, 1.0), 0.80, False),
    "cellar_door":  ((0.20, 0.13, 0.08), 0.70, False),
    "hall_floor":   ((1.0, 1.0, 1.0), 0.75, False),
    "hall_wall":    ((1.0, 1.0, 1.0), 0.90, False),
    "hall_steel":   ((0.22, 0.23, 0.25), 0.50, True),
    "window_glass": ((0.60, 0.70, 0.75), 0.05, True),
    "grate":        ((0.30, 0.30, 0.31), 0.50, True),
    "tank_steel":   ((0.78, 0.78, 0.78), 0.25, False),
    "tank_jacket":  ((0.70, 0.70, 0.72), 0.35, False),
    "tank_dark":    ((0.08, 0.08, 0.08), 0.50, True),
    "tree_card":    ((1.0, 1.0, 1.0), 0.90, True),
})
V = Vector

def gl(x, y, z):
    """glTF coords (x, y-up, z) → Blender coords (x, -z, y)."""
    return V((x, -z, y))

# =========================================================================== barrels
def barrel(name, L, r_head, r_bilge, nstaves, hoops, chime=0.035, th=0.024, seg=12, fuder=False, seed=0):
    """Cask lying along glTF +Z (heads face ±Z). Individual staves with gaps, flush heads of planks, steel hoops."""
    R = random.Random(seed)
    P = {"barrel_oak": Acc(), "barrel_head": Acc(), "barrel_hoop": Acc(), "barrel_bung": Acc()}
    if fuder: P["rack_wood"] = Acc()
    half = L / 2
    def prof(z): t = z / half; return r_head + (r_bilge - r_head) * (1 - t * t)
    def pt(z, r, a): return gl(r * math.cos(a), r * math.sin(a), z)     # barrel axis = glTF z
    w = [R.uniform(0.75, 1.25) for _ in range(nstaves)]
    tot = sum(w); cum = [0.0]
    for x in w: cum.append(cum[-1] + x / tot * 2 * math.pi)
    gap = 0.0022
    for i in range(nstaves):
        a0, a1 = cum[i] + gap / r_bilge, cum[i + 1] - gap / r_bilge
        jitter = R.uniform(-0.0012, 0.0012)
        shade = R.uniform(0.82, 1.12)
        col = (shade, shade * R.uniform(0.96, 1.02), shade * R.uniform(0.92, 1.0))
        verts, faces, uvs, cols = [], [], [], []
        J = 3
        for k in range(seg + 1):
            z = -half + L * k / seg
            r = prof(z) + jitter
            for j in range(J + 1):
                a = a0 + (a1 - a0) * j / J
                verts.append(pt(z, r, a)); uvs.append((i * 0.37 + (a - a0) * r_bilge / 0.25, (z + half) / 1.0)); cols.append(col)
        for k in range(seg + 1):                       # inner skin
            z = -half + L * k / seg
            r = prof(z) + jitter - th
            for j in range(J + 1):
                a = a0 + (a1 - a0) * j / J
                verts.append(pt(z, r, a)); uvs.append((i * 0.37 + (a - a0) * r_bilge / 0.25, (z + half) / 1.0)); cols.append(col)
        n = (seg + 1) * (J + 1)
        for k in range(seg):
            for j in range(J):
                a = k * (J + 1) + j
                faces.append((a, a + 1, a + J + 2, a + J + 1))                      # outer
                faces.append((n + a, n + a + J + 1, n + a + J + 2, n + a + 1))      # inner
            for j, (o, d) in enumerate(((0, 0), (J, 0))):                         # stave edges
                a = k * (J + 1) + o; b = a + J + 1
                faces.append((a, b, n + b, n + a) if o == 0 else (a, n + a, n + b, b))
        for k in (0, seg):                                                          # end grain
            for j in range(J):
                a = k * (J + 1) + j
                faces.append((a, n + a, n + a + 1, a + 1) if k == 0 else (a, a + 1, n + a + 1, n + a))
        P["barrel_oak"].add(verts, faces, uvs, cols)
    # heads: planks, recessed by the chime
    for sgn in (-1, 1):
        zc = sgn * (half - chime)
        rr = prof(zc) - th * 0.9
        nplanks = 5 if not fuder else 7
        for p in range(nplanks):
            y0 = -rr + 2 * rr * p / nplanks + 0.0015
            y1 = -rr + 2 * rr * (p + 1) / nplanks - 0.0015
            pts = []
            steps = 10
            for s_ in range(steps + 1):                        # left arc edge x<0 going up, right edge down
                y = y0 + (y1 - y0) * s_ / steps
                pts.append((-math.sqrt(max(rr * rr - y * y, 0)), y))
            for s_ in range(steps + 1):
                y = y1 - (y1 - y0) * s_ / steps
                pts.append((math.sqrt(max(rr * rr - y * y, 0)), y))
            c = (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
            shade = R.uniform(0.85, 1.1)
            verts = [gl(c[0], c[1], zc)] + [gl(q[0], q[1], zc) for q in pts]
            uvs = [(c[0] / 0.5 + p * 0.21, c[1] / 0.5)] + [(q[0] / 0.5 + p * 0.21, q[1] / 0.5) for q in pts]
            m = len(pts)
            faces = [((0, 1 + i, 1 + (i + 1) % m) if sgn < 0 else (0, 1 + (i + 1) % m, 1 + i)) for i in range(m)]
            P["barrel_head"].add(verts, faces, uvs, [(shade, shade, shade)] * len(verts))
        if fuder:                                             # carved oval relief on Fuder heads
            ring = []
            for i in range(48):
                a = 2 * math.pi * i / 48
                ring.append((0.26 * math.cos(a), 0.34 * math.sin(a)))
            verts = [gl(q[0], q[1], zc + sgn * 0.012) for q in ring] + [gl(q[0] * 0.86, q[1] * 0.88, zc + sgn * 0.012) for q in ring]
            faces = []
            for i in range(48):
                j = (i + 1) % 48
                faces.append((i, j, 48 + j, 48 + i) if sgn > 0 else (i, 48 + i, 48 + j, j))
            P["barrel_head"].add(verts, faces, [(0.5, 0.5)] * len(verts), [(0.7, 0.7, 0.7)] * len(verts))
    # hoops
    for zh, wd in hoops:
        verts, faces, uvs = [], [], []
        N = 72
        for k, z in enumerate((zh - wd / 2, zh + wd / 2)):
            r = prof(z) + 0.0045
            for i in range(N):
                a = 2 * math.pi * i / N
                verts.append(pt(z, r, a)); uvs.append((i / N * 8, k))
        for i in range(N):
            j = (i + 1) % N
            faces.append((i, j, N + j, N + i))
        P["barrel_hoop"].add(verts, faces, uvs, [(1, 1, 1)] * len(verts))
    # silicone bung on top
    bz, br = 0.0, (0.025 if not fuder else 0.035)
    top = prof(bz)
    tube(P["barrel_bung"], [gl(0, top - 0.005, bz), gl(0, top + 0.022, bz)], [br, br * 0.8], 12, (1, 1, 1), cap=True)
    if fuder:                                                  # wooden cradle (Lager) under the Fuder
        for zc in (-half * 0.55, half * 0.55):
            verts, faces = [], []
            x0, x1, y0, y1, d = -r_bilge * 0.9, r_bilge * 0.9, -r_bilge - 0.02, -r_bilge + 0.18, 0.09
            for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
                for dz in (-d, d): verts.append(gl(x, y, zc + dz))
            faces = [(0, 6, 4, 2), (1, 3, 5, 7), (0, 2, 3, 1), (2, 4, 5, 3), (4, 6, 7, 5), (6, 0, 1, 7)]
            P["rack_wood"].add(verts, faces, [(0, 0)] * len(verts), [(1, 1, 1)] * len(verts))
    return make_object(name, P, smooth=True)

BARRIQUE = dict(L=0.95, r_head=0.2825, r_bilge=0.3475)
FUDER = dict(L=1.22, r_head=0.48, r_bilge=0.56)

# =========================================================================== tank
def lathe(acc, profile, n, col=(1, 1, 1), yoff=0.0, z0=0.0, a_range=(0, 2 * math.pi), uv_scale=1.0):
    """profile: list of (r, y) in glTF metres, revolved around the glTF Y axis."""
    verts, uvs, faces = [], [], []
    s = 0.0; ss_ = [0.0]
    for i in range(1, len(profile)):
        s += math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]); ss_.append(s)
    for k in range(n + 1):
        a = a_range[0] + (a_range[1] - a_range[0]) * k / n
        for i, (r, y) in enumerate(profile):
            verts.append(gl(r * math.sin(a), y + yoff, r * math.cos(a) + z0))
            uvs.append((a * 0.8 / uv_scale, ss_[i] / uv_scale))
    m = len(profile)
    for k in range(n):
        for i in range(m - 1):
            a = k * m + i
            faces.append((a, a + m, a + m + 1, a + 1))
    acc.add(verts, faces, uvs, [col] * len(verts))

def build_tank():
    P = {"tank_steel": Acc(), "tank_jacket": Acc(), "tank_dark": Acc()}
    R0, yb, yt = 0.80, 0.62, 3.20                   # ≈ 5 000 L Riesling tank
    body = [(0.0, yb - 0.10), (0.35, yb - 0.07), (0.72, yb - 0.02), (R0, yb + 0.03), (R0, 1.0), (R0, 1.9), (R0, 2.35)]
    lathe(P["tank_steel"], body, 72)
    lathe(P["tank_jacket"], [(R0 + 0.012, 2.35), (R0 + 0.012, 3.0)], 72)
    lathe(P["tank_steel"], [(R0, 3.0), (R0, yt), (0.62, yt + 0.12), (0.30, yt + 0.24), (0.26, yt + 0.25), (0.26, yt + 0.33), (0.0, yt + 0.34)], 72)
    lathe(P["tank_steel"], [(R0 + 0.004, 1.58), (R0 + 0.004, 1.60)], 72)          # weld seam
    lathe(P["tank_steel"], [(R0 + 0.004, 2.34), (R0 + 0.004, 2.36)], 72)
    for i in range(4):                                                             # legs + feet
        a = math.pi / 4 + i * math.pi / 2
        x, z = 0.70 * math.sin(a), 0.70 * math.cos(a)
        tube(P["tank_steel"], [gl(x, 0.02, z), gl(x, yb + 0.02, z)], [0.038, 0.038], 12, (1, 1, 1), cap=True)
        tube(P["tank_steel"], [gl(x, 0.0, z), gl(x, 0.02, z)], [0.08, 0.08], 12, (1, 1, 1), cap=True)
    # front (+z) manway door, valves, sample tap, thermowell + controller box
    fz = R0 + 0.01
    ring = [(0.24 * math.cos(2 * math.pi * i / 40), 0.95 + 0.17 * math.sin(2 * math.pi * i / 40)) for i in range(40)]
    verts = [gl(q[0], q[1], fz + 0.05) for q in ring] + [gl(q[0] * 0.88, q[1] * 0.88 + 0.95 * 0.12, fz + 0.06) for q in ring]
    faces = [(i, (i + 1) % 40, 40 + (i + 1) % 40, 40 + i) for i in range(40)]
    P["tank_steel"].add(verts, faces, [(0, 0)] * 80, [(1, 1, 1)] * 80)
    c = len(verts)
    P["tank_steel"].add([gl(q[0] * 0.88, q[1] * 0.88 + 0.95 * 0.12, fz + 0.06) for q in ring] + [gl(0, 0.95, fz + 0.065)],
                        [(i, (i + 1) % 40, 40) for i in range(40)], [(0, 0)] * 41, [(1, 1, 1)] * 41)
    tube(P["tank_dark"], [gl(0.30, 0.95, fz + 0.07), gl(0.30, 0.95, fz + 0.14)], [0.018, 0.018], 8, (1, 1, 1), cap=True)
    for (x, y, rr) in ((-0.35, 0.70, 0.035), (0.0, yb - 0.05, 0.045)):                 # racking + drain valve
        tube(P["tank_steel"], [gl(x, y, fz - 0.02), gl(x, y, fz + 0.16)], [rr, rr], 16, (1, 1, 1), cap=True)
        tube(P["tank_dark"], [gl(x - 0.12, y + 0.07, fz + 0.12), gl(x + 0.12, y + 0.07, fz + 0.12)], [0.012, 0.012], 6, (1, 1, 1), cap=True)
    tube(P["tank_steel"], [gl(0.45, 1.25, fz), gl(0.45, 1.25, fz + 0.09), gl(0.45, 1.19, fz + 0.12)], [0.009] * 3, 8, (1, 1, 1))
    for i, (x0, x1, y0, y1) in enumerate(((-0.62, -0.38, 1.35, 1.55),)):                # temperature controller box
        d0, d1 = fz - 0.02, fz + 0.07
        vs = [gl(x, y, d) for d in (d0, d1) for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        P["tank_dark"].add(vs, [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], [(0, 0)] * 8, [(1, 1, 1)] * 8)
    for x in (-0.12, 0.12):                                                            # glycol lines to the ceiling
        tube(P["tank_steel"], [gl(x, 2.9, R0 + 0.02), gl(x, 2.9, R0 + 0.12), gl(x, 3.4, R0 + 0.12), gl(x, 6.55, R0 + 0.12)],
             [0.017] * 4, 10, (1, 1, 1))
    ob = make_object("tank", P, smooth=True)
    return ob, {"radius": R0, "height": yt + 0.34, "panel": {"x": 0.0, "y": 1.55, "z": R0 + 0.035, "w": 0.46, "h": 0.30},
                "controllerLed": [-0.5, 1.45, fz + 0.075]}

# =========================================================================== cellar (vaulted Mosel slate cellar)
CELLAR = dict(L=22.0, W=6.2, wall_h=1.6)
def build_cellar(R):
    L, W, wh = CELLAR["L"], CELLAR["W"], CELLAR["wall_h"]
    rv = W / 2
    P = {"cellar_wall": Acc(), "cellar_floor": Acc(), "rack_wood": Acc(), "cellar_door": Acc()}
    prof = [(-rv, 0.0), (-rv, wh * 0.5), (-rv, wh)]
    for i in range(1, 36):
        a = math.pi - math.pi * i / 36
        prof.append((rv * math.cos(a), wh + rv * math.sin(a)))
    prof += [(rv, wh), (rv, wh * 0.5), (rv, 0.0)]
    dense = []
    for i in range(len(prof) - 1):
        (z0, y0), (z1, y1) = prof[i], prof[i + 1]
        n = max(1, int(math.hypot(z1 - z0, y1 - y0) / 0.25))
        for k in range(n): dense.append((z0 + (z1 - z0) * k / n, y0 + (y1 - y0) * k / n))
    dense.append(prof[-1])
    arc = [0.0]
    for i in range(1, len(dense)): arc.append(arc[-1] + math.hypot(dense[i][0] - dense[i - 1][0], dense[i][1] - dense[i - 1][1]))
    nx = int(L / 0.25)
    verts, uvs = [], []
    for ix in range(nx + 1):
        x = -L / 2 + L * ix / nx
        for i, (z, y) in enumerate(dense):
            n = V((0, 0, 0))
            inward = V((0, wh + 0.5 - y, -z)).normalized() if y > wh else V((0, 0, -math.copysign(1, z)))
            bump = 0.035 * fbm(x * 3.1, arc[i] * 3.1, 1.3, 2, 41.0)
            verts.append(gl(x, y, z) + gl(0, 0, 0) - V((0, 0, 0)))
            p = V((x, y, z)) + V((0, inward.y, -inward.z)) * 0.0 + V((0, 0, 0))
            q = V((x, y, z)) - V((0, 0, 0))
            # push stones in/out along the inward normal (glTF), convert to Blender
            off = V((0, inward.y, inward.z)) * bump
            verts[-1] = gl(x, y + off.y, z + off.z)
            uvs.append((arc[i], x))
    m = len(dense)
    faces = []
    for ix in range(nx):
        for i in range(m - 1):
            a = ix * m + i
            faces.append((a, a + m, a + m + 1, a + 1))                  # faces the room
    P["cellar_wall"].add(verts, faces, uvs, [(1, 1, 1)] * len(verts))
    # end walls (fan from a centre point)
    for sx in (-1, 1):
        x = sx * L / 2
        cz, cy = 0.0, wh
        vs = [gl(x, cy, cz)] + [gl(x, y, z) for (z, y) in dense]
        us = [(cz, cy)] + [(z, y) for (z, y) in dense]
        fs = [((0, i + 2, i + 1) if sx > 0 else (0, i + 1, i + 2)) for i in range(len(dense) - 1)]
        fs.append((0, 1, len(dense)) if sx > 0 else (0, len(dense), 1))
        P["cellar_wall"].add(vs, fs, us, [(1, 1, 1)] * len(vs))
    # cobbled floor
    fx, fz = int(L / 0.5), int(W / 0.5)
    vs, us = [], []
    for ix in range(fx + 1):
        for iz in range(fz + 1):
            x, z = -L / 2 + L * ix / fx, -W / 2 + W * iz / fz
            vs.append(gl(x, 0.006 * fbm(x, z, 0.7, 2, 43.0), z)); us.append((x, z))
    fs = []
    for ix in range(fx):
        for iz in range(fz):
            a = ix * (fz + 1) + iz
            fs.append((a, a + 1, a + fz + 2, a + fz + 1))
    P["cellar_floor"].add(vs, fs, us, [(1, 1, 1)] * len(vs))
    # oak door at the -X end
    d = [gl(-L / 2 + 0.02, y, z) for (z, y) in ((-0.65, 0), (0.65, 0), (0.65, 2.1), (-0.65, 2.1))]
    P["cellar_door"].add(d, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    # barrel racks + barrel/Fuder placements
    items = {"barriques": [], "fuder": []}
    oaks = [("FR · Allier", 0.4), ("FR · Tronçais", 0.25), ("HU · Zemplén", 0.15), ("US · Missouri", 0.2)]
    toasts = ["L", "M", "M", "M+", "H"]
    fills = ["neu", "1. Bel.", "2. Bel.", "neutral", "neutral"]
    lots = ["Riesling A (Steillage)", "Riesling B", "Spätburgunder D", "Riesling C"]
    def pick(opts):
        r, acc = R.random(), 0
        for o, w in opts:
            acc += w
            if r <= acc: return o
        return opts[-1][0]
    num = 1
    for side in (-1, 1):
        zc = side * (W / 2 - 0.05 - BARRIQUE["L"] / 2)
        xmax = 4.3 if side < 0 else 10.1
        for bz in (zc - side * 0.30, zc + side * 0.30):                               # two rack beams per row
            vs = []
            for (x, y, z) in ((-10.5, 0, bz - 0.06), (xmax + 0.4, 0, bz - 0.06), (xmax + 0.4, 0.12, bz - 0.06), (-10.5, 0.12, bz - 0.06),
                              (-10.5, 0, bz + 0.06), (xmax + 0.4, 0, bz + 0.06), (xmax + 0.4, 0.12, bz + 0.06), (-10.5, 0.12, bz + 0.06)):
                vs.append(gl(x, y, z))
            P["rack_wood"].add(vs, [(3, 2, 6, 7), (0, 1, 2, 3), (4, 7, 6, 5), (1, 5, 6, 2), (0, 3, 7, 4)],
                               [(0, 0), (8, 0), (8, 0.1), (0, 0.1), (0, 0.3), (8, 0.3), (8, 0.4), (0, 0.4)], [(1, 1, 1)] * 8)
        x = -10.1
        tier0 = []
        while x <= xmax + 1e-6:
            tier0.append(x); x += 0.75
        for tier, xs in ((0, tier0), (1, [a + 0.375 for a in tier0[:-1]])):
            y = 0.44 if tier == 0 else 1.03
            for bx in xs:
                lot = lots[R.randrange(len(lots))]
                label = {"fass": num, "lot": lot, "vintage": 2025 if R.random() < 0.8 else 2024, "oak": pick(oaks),
                         "toast": toasts[R.randrange(len(toasts))], "fill": fills[R.randrange(len(fills))]}
                items["barriques"].append({"pos": [round(bx, 3), y, round(zc, 3)], "yaw": 0.0 if side > 0 else math.pi,
                                           "roll": round(R.uniform(-0.25, 0.25), 3), "label": label})
                num += 1
    for i, fx_ in enumerate((5.9, 7.45, 9.0)):
        zc = -(W / 2 - 0.05 - FUDER["L"] / 2)
        items["fuder"].append({"pos": [fx_, 0.72, round(zc, 3)], "yaw": math.pi, "roll": 0.0,
                               "label": {"fuder": i + 1, "litres": 1000, "lot": ["Riesling Spätlese A", "Riesling Kabinett C", "Riesling B"][i], "vintage": 2025}})
    ob = make_object("cellar", P, smooth=True)
    lights = []
    for i, lx in enumerate((-9.0, -5.0, -1.0, 3.0, 7.0)):
        side = -1 if i % 2 else 1
        lights.append({"type": "sconce", "model": "industrial_caged_sconce", "pos": [lx, 2.15, side * 3.0], "facing": [0, 0, -side],
                       "color": [1.0, 0.71, 0.42], "lumens": 650, "kelvin": 2700})
    lights += [{"type": "bulb", "pos": [x, 4.3, 0.0], "color": [1.0, 0.74, 0.46], "lumens": 450, "kelvin": 2700} for x in (-3.0, 5.0)]
    return ob, items, lights

# =========================================================================== fermentation hall
HALL = dict(x0=-12.0, x1=12.0, z0=-7.0, z1=7.0, h=7.0)
def build_hall():
    x0, x1, z0, z1, hh = HALL["x0"], HALL["x1"], HALL["z0"], HALL["z1"], HALL["h"]
    P = {"hall_floor": Acc(), "hall_wall": Acc(), "hall_steel": Acc(), "window_glass": Acc(), "grate": Acc()}
    def quad(acc, a, b, c, d, uvs=None):
        acc.add([gl(*a), gl(*b), gl(*c), gl(*d)], [(0, 1, 2, 3)], uvs or [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    def wall_rect(acc, axis, fixed, u0, u1, v0, v1, facing):
        """Axis-aligned wall rectangle, UV in metres; facing = +1/-1 along the fixed axis (normal towards the room)."""
        if axis == "z":   # wall at z = fixed, spanning x
            p = [(u0, v0, fixed), (u1, v0, fixed), (u1, v1, fixed), (u0, v1, fixed)]
        else:             # wall at x = fixed, spanning z
            p = [(fixed, v0, u0), (fixed, v0, u1), (fixed, v1, u1), (fixed, v1, u0)]
        uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        if (axis == "z" and facing < 0) or (axis == "x" and facing > 0): p, uv = p[::-1], uv[::-1]
        quad(acc, *p, uvs=uv)
    # floor with a central drain channel (grate)
    for (za, zb) in ((z0, -0.12), (0.12, z1)):
        nxs, nzs = 48, 14
        vs, us, fs = [], [], []
        for ix in range(nxs + 1):
            for iz in range(nzs + 1):
                x, z = x0 + (x1 - x0) * ix / nxs, za + (zb - za) * iz / nzs
                vs.append(gl(x, 0.012 * abs(z) / 7, z)); us.append((x, z))          # floor falls towards the drain
        for ix in range(nxs):
            for iz in range(nzs):
                a = ix * (nzs + 1) + iz
                fs.append((a, a + 1, a + nzs + 2, a + nzs + 1))
        P["hall_floor"].add(vs, fs, us, [(1, 1, 1)] * len(vs))
    quad(P["grate"], (x0, -0.005, 0.12), (x1, -0.005, 0.12), (x1, -0.005, -0.12), (x0, -0.005, -0.12),
         [(0, 0), (24 / 0.24, 0), (24 / 0.24, 1), (0, 1)])
    # north wall with a ribbon of high windows
    wall_rect(P["hall_wall"], "z", z0, x0, x1, 0, 4.4, +1)
    wall_rect(P["hall_wall"], "z", z0, x0, x1, 6.1, hh, +1)
    wx = [(-10.5, -6.5), (-5.5, -1.5), (-0.5, 3.5), (4.5, 8.5)]
    edges = [x0] + [v for w in wx for v in w] + [x1]
    for i in range(0, len(edges), 2):
        wall_rect(P["hall_wall"], "z", z0, edges[i], edges[i + 1], 4.4, 6.1, +1)
    for (a, b) in wx:
        wall_rect(P["window_glass"], "z", z0 - 0.08, a, b, 4.4, 6.1, +1)
    wall_rect(P["hall_wall"], "z", z1, x0, x1, 0, hh, -1)
    wall_rect(P["hall_wall"], "x", x0, z0, z1, 0, hh, +1)
    # east wall with an open roller door
    wall_rect(P["hall_wall"], "x", x1, z0, -2.2, 0, hh, -1)
    wall_rect(P["hall_wall"], "x", x1, 2.2, z1, 0, hh, -1)
    wall_rect(P["hall_wall"], "x", x1, -2.2, 2.2, 4.5, hh, -1)
    quad(P["hall_wall"], (x1, hh, z0), (x1, hh, z1), (x0, hh, z1), (x0, hh, z0), [(x1, z0), (x1, z1), (x0, z1), (x0, z0)])
    # steel roof trusses (I-beams) + a catwalk over the tank aisle
    def box(acc, a, b):
        (ax, ay, az), (bx, by, bz) = a, b
        vs = [gl(ax, ay, az), gl(bx, ay, az), gl(bx, by, az), gl(ax, by, az), gl(ax, ay, bz), gl(bx, ay, bz), gl(bx, by, bz), gl(ax, by, bz)]
        acc.add(vs, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)],
                [(0, 0), (1, 0), (1, 1), (0, 1)] * 2, [(1, 1, 1)] * 8)
    for x in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0):
        box(P["hall_steel"], (x - 0.08, 6.62, z0), (x + 0.08, 6.64, z1))
        box(P["hall_steel"], (x - 0.08, 6.96, z0), (x + 0.08, 6.98, z1))
        box(P["hall_steel"], (x - 0.006, 6.64, z0), (x + 0.006, 6.96, z1))
    box(P["grate"], (-11.0, 3.72, -0.6), (6.0, 3.76, 0.6))
    for zr in (-0.6, 0.6):
        box(P["hall_steel"], (-11.0, 4.72, zr - 0.02), (6.0, 4.76, zr + 0.02))
        box(P["hall_steel"], (-11.0, 4.22, zr - 0.012), (6.0, 4.24, zr + 0.012))
        for x in range(-11, 7, 2):
            box(P["hall_steel"], (x - 0.02, 3.76, zr - 0.02), (x + 0.02, 4.76, zr + 0.02))
    for x in (-11.0, -3.0, 5.0):
        for zr in (-0.55, 0.55):
            box(P["hall_steel"], (x - 0.05, 0.0, zr - 0.05), (x + 0.05, 3.72, zr + 0.05))
    return make_object("hall", P, smooth=False)

TANK_DATA = [
    {"id": "T1", "contents": "Riesling · Block A (Steillage)", "phase": "Alcoholic fermentation", "day": 9, "tempC": 16.2, "setC": 16.0,
     "yeast": "Cultured S. cerevisiae", "oe_series": [88, 87, 84, 78, 70, 60, 48, 36, 25, 17, 12], "note": "Nutrient (DAP) added day 2"},
    {"id": "T2", "contents": "Riesling · Block B", "phase": "Spontaneous fermentation", "day": 14, "tempC": 17.1, "setC": 17.0,
     "yeast": "Ambient (spontaneous)", "oe_series": [86, 86, 85, 83, 80, 76, 71, 65, 59, 53, 48, 43, 38, 34, 30], "note": "Slow and steady — monitor H₂S"},
    {"id": "T3", "contents": "Riesling · Block C (Kabinett)", "phase": "Stopped — chilled, SO₂ added", "day": 11, "tempC": 8.3, "setC": 8.0,
     "yeast": "Cultured S. cerevisiae", "oe_series": [80, 79, 76, 70, 62, 53, 44, 36, 29, 24, 21], "note": "8.8 % vol · RS 38 g/L · TA 8.6 g/L"},
    {"id": "T4", "contents": "Spätburgunder · Block D", "phase": "Maceration · pump-over 2×/day", "day": 5, "tempC": 27.4, "setC": 27.0,
     "yeast": "Cultured S. cerevisiae", "oe_series": [92, 90, 82, 68, 52, 40], "note": "Cap temperature 29 °C — within target"},
    {"id": "T5", "contents": "— empty —", "phase": "Cleaned · available", "day": 0, "tempC": 14.0, "setC": None, "yeast": "", "oe_series": [], "note": ""},
    {"id": "T6", "contents": "Riesling · press fraction", "phase": "Must settling (débourbage)", "day": 1, "tempC": 10.1, "setC": 10.0,
     "yeast": "", "oe_series": [84], "note": "Rack off gross lees after 18 h"},
    {"id": "T7", "contents": "Riesling 2024 · on fine lees", "phase": "Ageing on fine lees", "day": 312, "tempC": 11.0, "setC": 11.0,
     "yeast": "", "oe_series": [], "note": "Free SO₂ 32 mg/L · pH 3.08"},
    {"id": "T8", "contents": "— empty —", "phase": "Cleaned · available", "day": 0, "tempC": 14.0, "setC": None, "yeast": "", "oe_series": [], "note": ""},
]

# =========================================================================== far-hill tree impostors
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
                    g = R.uniform(-1, 1)
                    leaf_blade(P["vine_leaf"], c, tipd, n, R.uniform(0.9, 1.3),
                               (0.022 + 0.008 * g, 0.050 + 0.014 * g, 0.014 if idx != 2 else 0.022))
                return
            for _ in range(3 if depth > 1 else 4):
                nd = (d + V((R.uniform(-.55, .55), R.uniform(-.55, .55), R.uniform(0.35, 1.0)))).normalized()
                branch(q, nd, length * R.uniform(0.55, 0.7), radius * 0.6, depth - 1)
        trunk_h = R.uniform(2.8, 4.0)
        tube(P["vine_bark"], [V((0, 0, 0)), V((0, 0, trunk_h))], [0.45, 0.32], 8, (1, 1, 1))
        branch(V((0, 0, trunk_h)), V((0, 0, 1)), height * 0.30, 0.30, 3)          # central leader
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
        heights.append(hgt)
        for m in bpy.data.materials:                      # leaves take their colour from vertex colours
            b = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
            if b and m.name.startswith("vine_leaf") and not any(n.type == "VERTEX_COLOR" for n in m.node_tree.nodes):
                vc = m.node_tree.nodes.new("ShaderNodeVertexColor"); vc.layer_name = ""
                m.node_tree.links.new(vc.outputs["Color"], b.inputs["Base Color"])
        bpy.context.view_layer.update()
        bb = [ob.matrix_world @ V(c) for c in ob.bound_box]
        top = max(p.z for p in bb); half_w = max(max(abs(p.x) for p in bb), max(abs(p.y) for p in bb))
        scale = max(top * 1.02, 4 * half_w * 1.02)
        heights[-1] = scale
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
    return heights

def build_tree_card():
    acc = Acc()
    for a in (0.0, math.pi / 2):
        dx, dy = 0.25 * math.cos(a), 0.25 * math.sin(a)
        acc.add([V((-dx, -dy, 0)), V((dx, dy, 0)), V((dx, dy, 1)), V((-dx, -dy, 1))], [(0, 1, 2, 3)],
                [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    return make_object("tree_card", {"tree_card": acc}, smooth=False)

def tree_positions(R):
    BANK, SOUTH = ns["BANK_Z"], ns["SOUTH_Z"]
    out = []
    z = -990.0
    while z < 1790:
        x = -1790.0
        while x < 1790:
            px, pz = x + R.uniform(-4, 4), z + R.uniform(-4, 4)
            north_forest = pz < BANK - 210
            south_forest = pz > SOUTH + 175
            edge = fbm(px, pz, 90, 2, 51.0)
            if (north_forest or south_forest) and edge > -0.35 and not (abs(px) < 90 and abs(pz) < 90):
                v = 3 if R.random() < 0.22 else R.randrange(3)
                out.append([v, round(px, 1), round(H(px, pz) - 0.6, 1), round(pz, 1), round(R.uniform(0, 6.283), 2),
                            round(R.uniform(15, 25) if v != 3 else R.uniform(18, 28), 1)])
            x += 9.0
        z += 9.0
    return out

# =========================================================================== dashboard data (fake but plausible, Mosel 2025, 26 Sep)
def dashboard_data():
    weeks = ["18 Aug", "25 Aug", "1 Sep", "8 Sep", "15 Sep", "22 Sep", "26 Sep"]
    def series(oe0, oe1, ta0, ta1, ph0, ph1):
        n = len(weeks)
        return {"oe": [round(oe0 + (oe1 - oe0) * (i / (n - 1)) ** 0.8, 1) for i in range(n)],
                "ta": [round(ta0 + (ta1 - ta0) * (i / (n - 1)) ** 0.7, 1) for i in range(n)],
                "ph": [round(ph0 + (ph1 - ph0) * (i / (n - 1)), 2) for i in range(n)]}
    blocks = [
        {"id": "A", "name": "Steillage Süd", "soil": "Blue Devonian slate, shallow", "slope": 35, "aspect": "S", "variety": "Riesling",
         "rootstock": "SO4", "stage": "Ripening", "health": 0.92, "water": -0.95, "downy": 18, "powdery": 12, "botrytis": 22,
         "yieldKgHa": 6800, "lai": 1.9, "sun": 0.96, **series(52, 86, 19.5, 9.4, 2.78, 3.02)},
        {"id": "B", "name": "Mittelhang", "soil": "Slate with loess patches", "slope": 28, "aspect": "SSW", "variety": "Riesling",
         "rootstock": "5BB", "stage": "Ripening", "health": 0.88, "water": -0.78, "downy": 24, "powdery": 10, "botrytis": 31,
         "yieldKgHa": 7900, "lai": 2.2, "sun": 0.91, **series(49, 81, 20.4, 10.1, 2.76, 2.98)},
        {"id": "C", "name": "Hangfuß", "soil": "Colluvial slate loam, deeper", "slope": 18, "aspect": "S", "variety": "Riesling",
         "rootstock": "SO4", "stage": "Ripening", "health": 0.81, "water": -0.52, "downy": 35, "powdery": 9, "botrytis": 46,
         "yieldKgHa": 9400, "lai": 2.7, "sun": 0.84, **series(46, 76, 21.2, 11.0, 2.74, 2.95)},
        {"id": "D", "name": "Kuppe", "soil": "Red slate, very stony", "slope": 31, "aspect": "SW", "variety": "Spätburgunder",
         "rootstock": "3309C", "stage": "Ripening", "health": 0.90, "water": -1.05, "downy": 15, "powdery": 21, "botrytis": 27,
         "yieldKgHa": 5600, "lai": 1.8, "sun": 0.95, **series(55, 92, 17.1, 7.8, 2.95, 3.28)},
        {"id": "E", "name": "Waldrand", "soil": "Slate under forest edge, cool", "slope": 24, "aspect": "SE", "variety": "Riesling",
         "rootstock": "Fercal", "stage": "Ripening", "health": 0.85, "water": -0.60, "downy": 29, "powdery": 14, "botrytis": 25,
         "yieldKgHa": 7200, "lai": 2.1, "sun": 0.80, **series(44, 72, 21.8, 11.8, 2.72, 2.91)},
    ]
    forecast = [
        {"day": "Sat 27", "icon": "sun", "tmin": 9, "tmax": 21, "rain": 0.0, "rh": 64},
        {"day": "Sun 28", "icon": "cloud", "tmin": 11, "tmax": 19, "rain": 0.4, "rh": 71},
        {"day": "Mon 29", "icon": "rain", "tmin": 12, "tmax": 16, "rain": 14.2, "rh": 92},
        {"day": "Tue 30", "icon": "rain", "tmin": 11, "tmax": 15, "rain": 8.6, "rh": 94},
        {"day": "Wed 1", "icon": "cloud", "tmin": 9, "tmax": 17, "rain": 1.1, "rh": 83},
        {"day": "Thu 2", "icon": "sun", "tmin": 7, "tmax": 19, "rain": 0.0, "rh": 70},
        {"day": "Fri 3", "icon": "sun", "tmin": 6, "tmax": 20, "rain": 0.0, "rh": 66},
    ]
    inbox = [
        {"from": "Mentor · Klaus Weber", "time": "07:10", "priority": "high",
         "subject": "Rain Monday–Tuesday: pick Block C before it?",
         "body": "Block C sits lowest and holds moisture. With 23 mm forecast and botrytis risk already at 46 %, I would pick it Saturday at ~76 °Oe for a fresh Kabinett rather than gamble. Blocks A and D can hang through the rain."},
        {"from": "Vineyard manager", "time": "06:45", "priority": "normal", "subject": "Berry samples in — 200 berries per Block",
         "body": "Block A 86 °Oe, TA 9.4 g/L. Seeds turning brown in A and D, still greenish in E."},
        {"from": "Cellar master", "time": "Yesterday", "priority": "normal", "subject": "T2 spontaneous ferment is slow but clean",
         "body": "No H₂S so far. Holding 17 °C."},
        {"from": "Weather service", "time": "Yesterday", "priority": "low", "subject": "Frontal system arriving Monday", "body": ""},
    ]
    return {"note": "PROTOTYPE fake data — plausible Mosel values, not simulated.", "date": "Fri 26 Sep 2025", "stage": "Ripening · harvest window",
            "cash": 184300, "estate": "Weingut (prototype)", "plot": "Steep slate slope, Middle Mosel", "weeks": weeks,
            "blocks": blocks, "forecast": forecast, "inbox": inbox,
            "legend": {"oe": "Must weight °Oechsle", "ta": "Titratable acidity g/L (as tartaric)", "water": "Stem water potential MPa (Ψstem)",
                       "risk": "Infection risk % (model)"}}

# =========================================================================== main
bpy.ops.wm.read_factory_settings(use_empty=True)
R = random.Random(2025)
heights = render_tree_atlas(R)
for o in list(bpy.context.scene.collection.objects): bpy.data.objects.remove(o)
export(build_tree_card(), "tree_card.glb")
export(barrel("barrique", nstaves=30, hoops=[(-0.43, 0.035), (-0.36, 0.035), (-0.14, 0.04), (0.14, 0.04), (0.36, 0.035), (0.43, 0.035)], seed=1, **BARRIQUE), "barrique.glb")
export(barrel("fuder", nstaves=44, hoops=[(-0.56, 0.045), (-0.47, 0.045), (-0.2, 0.05), (0.2, 0.05), (0.47, 0.045), (0.56, 0.045)], seed=2, fuder=True, **FUDER), "fuder.glb")
tank_ob, tank_info = build_tank()
export(tank_ob, "tank.glb")
cellar_ob, cellar_items, cellar_lights = build_cellar(R)
export(cellar_ob, "cellar.glb")
export(build_hall(), "hall.glb")

tanks = []
for i, td in enumerate(TANK_DATA):
    row = -1 if i < 4 else 1
    x = (-8.0, -4.0, 0.0, 4.0)[i % 4]
    tanks.append({**td, "pos": [x, 0.0, row * 3.3], "yaw": 0.0 if row < 0 else math.pi})   # front (+z local) faces the aisle
hall_lights = [{"type": "hanging", "model": "hanging_industrial_lamp", "pos": [x, 6.2, z], "color": [1.0, 0.96, 0.9], "lumens": 3200, "kelvin": 4000}
               for x in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0) for z in (-2.2, 2.2)]
props = [{"model": "plastic_crate_01", "pos": [9.2 + 0.62 * (k % 3), 0.33 * ((k // 3) % 3), -4.6 - 0.45 * (k // 9)], "yaw": 0.0} for k in range(27)]   # 3×3×3 stack beside the door, clear of hall_overview
props += [{"model": "ladder_sectioned_01", "pos": [-11.6, 0.0, 0.0], "yaw": math.pi / 2}]

layout = {
    "note": "PROTOTYPE round-2 layout. glTF coords. Scenes are independent (own origin).",
    "vineyard_presets": {
        "clear_afternoon": {"timeOfDay": 16.5, "sun": {"elevationDeg": 20, "azimuthDeg": 240}, "weather": "clear", "rain": 0.0, "wetness": 0.0,
                            "cloudCover": 0.1, "fog": {"density": 0.0007, "valleyFogTopY": None}, "sky": "hdri/sky.hdr"},
        "misty_sunrise": {"timeOfDay": 7.2, "sun": {"elevationDeg": 4, "azimuthDeg": 95}, "weather": "mist", "rain": 0.0, "wetness": 0.35,
                          "cloudCover": 0.3, "fog": {"density": 0.004, "valleyFogTopY": 38.0}, "sky": "hdri/qwantani_sunrise_puresky.hdr"},
        "rain_morning": {"timeOfDay": 9.5, "sun": {"elevationDeg": 25, "azimuthDeg": 130}, "weather": "rain", "rain": 0.85, "wetness": 1.0,
                         "cloudCover": 1.0, "fog": {"density": 0.0025, "valleyFogTopY": 70.0}, "sky": "hdri/kloofendal_overcast_puresky.hdr"},
        "dusk": {"timeOfDay": 19.2, "sun": {"elevationDeg": 2, "azimuthDeg": 268}, "weather": "clear", "rain": 0.0, "wetness": 0.1,
                 "cloudCover": 0.35, "fog": {"density": 0.0012, "valleyFogTopY": 20.0}, "sky": "hdri/qwantani_dusk_2_puresky.hdr"},
    },
    "shots": {
        "rain_row": {"scene": "vineyard", "preset": "rain_morning", "camera": "row_downhill"},
        "rain_close": {"scene": "vineyard", "preset": "rain_morning", "camera": "vine_close"},
        "mist_valley": {"scene": "vineyard", "preset": "misty_sunrise", "camera": "valley_view"},
        "sunrise_drone": {"scene": "vineyard", "preset": "misty_sunrise", "camera": "drone"},
        "dusk_uphill": {"scene": "vineyard", "preset": "dusk", "camera": "uphill"},
        "cellar_aisle": {"scene": "cellar", "camera": {"position": [-10.2, 1.62, 0.0], "target": [8.0, 1.3, 0.0]}},
        "cellar_heads": {"scene": "cellar", "camera": {"position": [-2.3, 1.25, -0.55], "target": [-1.2, 0.75, -2.1]}},
        "cellar_fuder": {"scene": "cellar", "camera": {"position": [5.6, 1.55, -0.2], "target": [7.45, 0.85, -1.9]}},
        "hall_overview": {"scene": "hall", "camera": {"position": [10.5, 2.2, 5.8], "target": [-6.0, 1.8, -1.0]}},
        "hall_panel": {"scene": "hall", "camera": {"position": [-3.6, 1.62, -1.35], "target": [-4.0, 1.5, -2.5]}},
        "dashboard": {"scene": "dashboard"},
    },
    "cellar": {"model": "cellar.glb", "barriqueModel": "barrique.glb", "fuderModel": "fuder.glb", "dims": CELLAR,
               "barriques": cellar_items["barriques"], "fuder": cellar_items["fuder"], "lights": cellar_lights,
               "materials": {"cellar_wall": "textures/castle_wall_slates (UV in metres)", "cellar_floor": "textures/cobblestone_floor_04 (UV in metres)",
                             "barrel_oak / barrel_head": "textures/oak_veneer_01 × vertex colour", "barrel_hoop": "textures/rusty_metal_02 or dark galvanised steel",
                             "rack_wood": "dark aged oak"},
               "labelHint": "Chalk text on each barrel head (heads face the aisle): 'Fass {fass} · {lot} {vintage}' / '{oak} · Toast {toast} · {fill}'."},
    "hall": {"model": "hall.glb", "tankModel": "tank.glb", "tankInfo": tank_info, "dims": HALL, "tanks": tanks, "lights": hall_lights, "props": props,
             "materials": {"hall_floor": "textures/concrete_floor_worn_001 (UV metres)", "hall_wall": "textures/grey_plaster_02 (UV metres)",
                           "tank_steel": "brushed stainless (anisotropic if available)", "window_glass": "daylight comes through; open roller door on +X wall"},
             "panelHint": "Live readout on each tank at tankInfo.panel (local, front = +z): contents, phase + day, temp vs setpoint, °Oe with sparkline of oe_series, note. Values may tick slowly."},
    "trees": {"model": "tree_card.glb", "atlas": "trees_atlas.png", "cells": 4, "cellHint": "variant v uses u ∈ [v/4, (v+1)/4]. Card is 0.5 wide × 1 high, ground at v=0 (bottom of the image). Scale the card uniformly by trees.json height (= cell height in metres).",
              "cellMeters": [round(h, 1) for h in heights], "file": "trees.json"},
}
with open(os.path.join(OUT, "layout_r2.json"), "w") as fh: json.dump(layout, fh, indent=1)
trees = tree_positions(R)
with open(os.path.join(OUT, "trees.json"), "w") as fh: json.dump({"fields": "variant,x,y,z,yaw,height", "items": trees}, fh, separators=(",", ":"))
with open(os.path.join(OUT, "dashboard_data.json"), "w") as fh: json.dump(dashboard_data(), fh, indent=1, ensure_ascii=False)
print("layout_r2:", len(cellar_items["barriques"]), "barriques,", len(cellar_items["fuder"]), "fuder,", len(tanks), "tanks,", len(trees), "trees")
print("DONE")
