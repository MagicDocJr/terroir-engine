# Winery assets for the 3D view (game/src/view3d/winery.gd). Run headless via ../sync_assets3d.sh:
#   blender -b --factory-startup -P build_winery.py -- <out_dir>
# Adapted from the engine demo (branch prototype/engine-demo, blender/build_assets_r2.py).
#
# Output (glTF, Y up, metres) into <out_dir>:
#   barrique.glb (225 L) · fuder.glb (1 000 L, on a cradle) · tank.glb (~5 000 L jacketed steel)
#   cellar.glb (vaulted slate barrel cellar with racks) · hall.glb (fermentation hall, open roller door)
#   winery.json: barrel/Fuder slots, tank positions + panel placement, lights, props, camera presets.
#   Slots carry no contents: winery.gd fills them from the simulation's Lots.
import bpy, math, random, json, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import V, Acc, make_object, tube, export, fbm, ss, gl

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
C.set_out(OUT)
C.MAT.update({
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
})

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
                items["barriques"].append({"pos": [round(bx, 3), y, round(zc, 3)], "yaw": 0.0 if side > 0 else math.pi,
                                           "roll": round(R.uniform(-0.25, 0.25), 3)})
                num += 1
    for i, fx_ in enumerate((5.9, 7.45, 9.0)):
        zc = -(W / 2 - 0.05 - FUDER["L"] / 2)
        items["fuder"].append({"pos": [fx_, 0.72, round(zc, 3)], "yaw": math.pi, "roll": 0.0})
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


# =========================================================================== main
bpy.ops.wm.read_factory_settings(use_empty=True)
C.set_out(OUT)
R = random.Random(2025)
export(barrel("barrique", nstaves=30, hoops=[(-0.43, 0.035), (-0.36, 0.035), (-0.14, 0.04), (0.14, 0.04), (0.36, 0.035), (0.43, 0.035)], seed=1, **BARRIQUE), "barrique.glb")
C.clear_scene()
export(barrel("fuder", nstaves=44, hoops=[(-0.56, 0.045), (-0.47, 0.045), (-0.2, 0.05), (0.2, 0.05), (0.47, 0.045), (0.56, 0.045)], seed=2, fuder=True, **FUDER), "fuder.glb")
C.clear_scene()
tank_ob, tank_info = build_tank()
export(tank_ob, "tank.glb")
C.clear_scene()
cellar_ob, cellar_items, cellar_lights = build_cellar(R)
export(cellar_ob, "cellar.glb")
C.clear_scene()
export(build_hall(), "hall.glb")
C.clear_scene()
for kind in ("barriques", "fuder"):                       # slots only: contents come from the simulation
    for i, it in enumerate(cellar_items[kind]):
        it["slot"] = i + 1
tanks = []
for i in range(8):
    row = -1 if i < 4 else 1
    x = (-8.0, -4.0, 0.0, 4.0)[i % 4]
    tanks.append({"id": f"T{i + 1}", "pos": [x, 0.0, row * 3.3], "yaw": 0.0 if row < 0 else math.pi})   # front (+z local) faces the aisle
hall_lights = [{"type": "hanging", "model": "hanging_industrial_lamp", "pos": [x, 6.2, z], "color": [1.0, 0.96, 0.9]}
               for x in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0) for z in (-2.2, 2.2)]
props = [{"model": "plastic_crate_01", "pos": [9.2 + 0.62 * (k % 3), 0.33 * ((k // 3) % 3), -4.6 - 0.45 * (k // 9)], "yaw": 0.0} for k in range(27)]
props += [{"model": "ladder_sectioned_01", "pos": [-11.6, 0.0, 0.0], "yaw": math.pi / 2}]
layout = {
    "note": "Winery layout for game/src/view3d/winery.gd. glTF coords. Cellar and hall have independent origins.",
    "cameras": {
        "cellar": {"position": [-10.2, 1.62, 0.0], "target": [8.0, 1.3, 0.0]},
        "cellar_heads": {"position": [-9.7, 1.2, -0.45], "target": [-8.6, 0.75, -2.1]},
        "cellar_fuder": {"position": [5.6, 1.55, -0.2], "target": [7.45, 0.85, -1.9]},
        "hall": {"position": [10.5, 2.2, 5.8], "target": [-6.0, 1.8, -1.0]},
        "hall_panel": {"position": [-7.72, 1.62, -1.72], "target": [-8.0, 1.52, -2.45]},
    },
    "cellar": {"model": "cellar.glb", "barriqueModel": "barrique.glb", "fuderModel": "fuder.glb", "dims": CELLAR,
               "barriques": cellar_items["barriques"], "fuder": cellar_items["fuder"], "lights": cellar_lights,
               "walk": {"x": [-10.6, 10.6], "z": [-1.6, 1.6]}},
    "hall": {"model": "hall.glb", "tankModel": "tank.glb", "tankInfo": tank_info, "dims": HALL, "tanks": tanks, "lights": hall_lights, "props": props,
             "walk": {"x": [-11.4, 11.4], "z": [-1.9, 1.9]}},
}
with open(os.path.join(OUT, "winery.json"), "w") as fh:
    json.dump(layout, fh, indent=1)
print("layout winery:", len(cellar_items["barriques"]), "barriques,", len(cellar_items["fuder"]), "fuder,", len(tanks), "tanks")
print("DONE")
