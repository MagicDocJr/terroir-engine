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
    "rail":         ((0.55, 0.45, 0.10), 0.50, False),
    "gutter":       ((0.55, 0.57, 0.60), 0.40, False),
    "sign_board":   ((0.10, 0.18, 0.14), 0.60, False),
    "door_wood":    ((0.25, 0.16, 0.10), 0.70, False),
    "window_dark":  ((0.03, 0.04, 0.05), 0.10, False),
    "canopy_roof":  ((0.40, 0.42, 0.44), 0.50, True),
    "bin_plastic":  ((0.45, 0.10, 0.08), 0.60, False),
    "tractor_paint": ((0.60, 0.10, 0.06), 0.45, False),
    "tractor_tyre": ((0.03, 0.03, 0.03), 0.90, False),
    "tractor_metal": ((0.08, 0.08, 0.09), 0.55, False),
    "sprayer_tank": ((0.85, 0.85, 0.82), 0.40, False),
    "w_skin":       ((0.60, 0.42, 0.32), 0.60, False),
    "w_shirt":      ((0.30, 0.40, 0.55), 0.80, False),
    "w_trousers":   ((0.15, 0.17, 0.22), 0.80, False),
    "w_hat":        ((0.70, 0.60, 0.35), 0.80, False),
    "w_gear":       ((0.10, 0.10, 0.10), 0.60, False),
    "facade":       ((0.85, 0.84, 0.80), 0.90, False),
    "plinth":       ((0.30, 0.30, 0.32), 0.90, False),
    "roof":         ((0.12, 0.12, 0.14), 0.70, False),
    "roof_under":   ((0.35, 0.28, 0.20), 0.80, False),
    "fascia":       ((0.25, 0.25, 0.26), 0.60, False),
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
DOOR, DOOR_H, REVEAL = 1.3, 2.1, 0.35      # cellar doorway (to the stair corridor)
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
    # end walls, built in horizontal bands that follow the vault; the -X end has the doorway to the stair
    # corridor (DOOR wide, DOOR_H high) with 0.35 m deep reveals and the oak door standing open inside
    def half_w(y):
        return rv if y <= wh else math.sqrt(max(rv * rv - (y - wh) ** 2, 0.0))
    top = wh + rv
    ys = [DOOR_H * i / 8 for i in range(8)] + [DOOR_H + (top - DOOR_H) * i / 40 for i in range(41)]
    dw = DOOR / 2
    for sx in (-1, 1):
        x = sx * L / 2
        vs, us, fs = [], [], []
        for i in range(len(ys) - 1):
            ya, yb = ys[i], ys[i + 1]
            wa, wb = half_w(ya), half_w(yb)
            spans = [(-wa, -wb, wa, wb)]
            if sx < 0 and yb <= DOOR_H + 1e-6:
                spans = [(-wa, -wb, -dw, -dw), (dw, dw, wa, wb)]
            for (za0, zb0, za1, zb1) in spans:
                quad = [(za0, ya), (za1, ya), (zb1, yb), (zb0, yb)]
                o = len(vs)
                for (z, y) in quad:
                    vs.append(gl(x, y, z)); us.append((z, y))
                fs.append((o, o + 3, o + 2, o + 1) if sx < 0 else (o, o + 1, o + 2, o + 3))
        P["cellar_wall"].add(vs, fs, us, [(1, 1, 1)] * len(vs))
    x0, x1 = -L / 2 - REVEAL, -L / 2
    def quad(acc, pts, uvs):
        acc.add([gl(*q) for q in pts], [(0, 1, 2, 3)], uvs, [(1, 1, 1)] * 4)
    quad(P["cellar_wall"], [(x0, 0, -dw), (x1, 0, -dw), (x1, DOOR_H, -dw), (x0, DOOR_H, -dw)], [(0, 0), (REVEAL, 0), (REVEAL, DOOR_H), (0, DOOR_H)])
    quad(P["cellar_wall"], [(x1, 0, dw), (x0, 0, dw), (x0, DOOR_H, dw), (x1, DOOR_H, dw)], [(0, 0), (REVEAL, 0), (REVEAL, DOOR_H), (0, DOOR_H)])
    quad(P["cellar_wall"], [(x0, DOOR_H, -dw), (x1, DOOR_H, -dw), (x1, DOOR_H, dw), (x0, DOOR_H, dw)], [(0, 0), (REVEAL, 0), (REVEAL, DOOR), (0, DOOR)])
    quad(P["cellar_floor"], [(x0, 0.002, dw), (x1, 0.002, dw), (x1, 0.002, -dw), (x0, 0.002, -dw)], [(0, 0), (REVEAL, 0), (REVEAL, DOOR), (0, DOOR)])
    # oak door leaf (5 cm thick), hinged at the +z jamb and swung open 150° into the cellar
    hx, hz_, ang = -L / 2, dw, math.radians(150)
    ux, uz = math.sin(ang), -math.cos(ang)        # along the leaf from the hinge (0° = closed)
    nx, nz = -uz, ux
    t = 0.05
    for (a0, a1) in ((0.0, DOOR),):
        c = []
        for (u, n) in ((a0, 0), (a1, 0), (a1, t), (a0, t)):
            c.append((hx + ux * u + nx * n, hz_ + uz * u + nz * n))
        for (y0, y1) in ((0.0, DOOR_H - 0.02),):
            pts = [(c[i][0], y, c[i][1]) for i in range(4) for y in (y0, y1)]
            faces = [(0, 2, 3, 1), (4, 6, 7, 5), (0, 1, 7, 6), (2, 4, 5, 3), (1, 3, 5, 7), (0, 6, 4, 2)]
            uvs = [(0, 0), (0, 1), (1, 0), (1, 1), (0, 0), (0, 1), (1, 0), (1, 1)]
            P["cellar_door"].add([gl(*q) for q in pts], faces, [(u * DOOR, v * DOOR_H) for (u, v) in uvs], [(1, 1, 1)] * 8)
    door_leaf = {"hinge": [hx, hz_], "angle": ang, "len": DOOR, "t": t}
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
    return ob, items, lights, door_leaf

# =========================================================================== fermentation hall, stairwell, shell
# One building in its own frame (the "building frame"): hall floor at y = 0, hall interior x∈[-12, 12],
# z∈[-7, 7], roller door in the east wall (+x). A straight flight of stairs along the west end goes down
# towards -z, through a short corridor under the north wall, into the vaulted cellar, which lies behind
# the hall (-z) under the ground. winery.gd places the building on a terrain pad in the vineyard and the
# cellar with CELLAR_XFORM.
HALL = dict(x0=-12.0, x1=12.0, z0=-7.0, z1=7.0, h=7.0)
WALL_T = 0.3
EAVE = 7.3
PITCH = math.radians(24.0)
OVERHANG, GABLE_OH = 0.6, 0.35
PLINTH = (-0.6, 0.45)
DOOR_Z, DOOR_TOP = (-2.2, 2.2), 4.5
WX = [(-10.5, -6.5), (-5.5, -1.5), (-0.5, 3.5), (4.5, 8.5)]       # north clerestory windows (x ranges)
WIN_Y = (4.4, 6.1)
SWX = [(-7.0, -5.4), (-2.8, -1.2), (1.2, 2.8), (5.4, 7.0), (8.9, 10.5)]   # south windows, between the tanks
SWIN_Y = (1.3, 2.9)
ST = dict(x0=-11.5, x1=-10.0, z_top=1.0, rise=0.175, run=0.28, n=30, hole_z0=-4.0)
ST_BOTTOM_Z = ST["z_top"] - (ST["n"] - 1) * ST["run"]           # -7.12: last riser
ST_FLOOR = -ST["n"] * ST["rise"]                                 # -5.25: corridor / cellar floor
CORR_CEIL, CORR_END = ST_FLOOR + 2.4, -8.6
CELLAR_DOOR_X = (ST["x0"] + ST["x1"]) / 2                        # -10.75
# cellar frame → building frame: x_b = ox + z_c, y_b = oy + y_c, z_b = oz - x_c (yaw +90°)
CELLAR_XFORM = dict(origin=[CELLAR_DOOR_X, ST_FLOOR, CORR_END - REVEAL - CELLAR["L"] / 2], yaw=math.pi / 2)


def cellar_to_building(p):
    o = CELLAR_XFORM["origin"]
    return [round(o[0] + p[2], 4), round(o[1] + p[1], 4), round(o[2] - p[0], 4)]


def quad(acc, a, b, c, d, uvs=None):
    acc.add([gl(*a), gl(*b), gl(*c), gl(*d)], [(0, 1, 2, 3)], uvs or [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)


def rect(acc, axis, fixed, u0, u1, v0, v1, facing):
    """Axis-aligned rectangle with metre UVs. axis "x": plane x = fixed, u = z, v = y; "z": plane z = fixed,
    u = x, v = y; "y": plane y = fixed, u = x, v = z. facing = +1/-1: which side of the plane it faces."""
    if u1 - u0 < 1e-6 or v1 - v0 < 1e-6:
        return
    if axis == "z":
        p = [(u0, v0, fixed), (u1, v0, fixed), (u1, v1, fixed), (u0, v1, fixed)]; flip = facing < 0
    elif axis == "x":
        p = [(fixed, v0, u0), (fixed, v0, u1), (fixed, v1, u1), (fixed, v1, u0)]; flip = facing > 0
    else:
        p = [(u0, fixed, v0), (u1, fixed, v0), (u1, fixed, v1), (u0, fixed, v1)]; flip = facing > 0
    uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    if flip:
        p, uv = p[::-1], uv[::-1]
    quad(acc, *p, uvs=uv)


def split_holes(u0, u1, v0, v1, holes):
    """Rectangles covering [u0,u1]x[v0,v1] minus the hole rectangles (hu0, hu1, hv0, hv1)."""
    out = []
    us = sorted(set([u0, u1] + [min(max(h[k], u0), u1) for h in holes for k in (0, 1)]))
    for a, b in zip(us, us[1:]):
        if b - a < 1e-6:
            continue
        cuts = sorted((h[2], h[3]) for h in holes if h[0] <= a + 1e-6 and h[1] >= b - 1e-6)
        v = v0
        for c0, c1 in cuts:
            if c0 > v + 1e-6:
                out.append((a, b, v, min(c0, v1)))
            v = max(v, c1)
        if v1 > v + 1e-6:
            out.append((a, b, v, v1))
    return out


def wall(acc, axis, fixed, u0, u1, v0, v1, holes, facing):
    for (a, b, c, d) in split_holes(u0, u1, v0, v1, holes):
        rect(acc, axis, fixed, a, b, c, d, facing)


def box(acc, a, b):
    (ax, ay, az), (bx, by, bz) = a, b
    rect(acc, "x", ax, az, bz, ay, by, -1); rect(acc, "x", bx, az, bz, ay, by, +1)
    rect(acc, "y", ay, ax, bx, az, bz, -1); rect(acc, "y", by, ax, bx, az, bz, +1)
    rect(acc, "z", az, ax, bx, ay, by, -1); rect(acc, "z", bz, ax, bx, ay, by, +1)


def floor_rect(acc, x0, x1, z0, z1, step=0.5):
    """Hall floor patch, falling 12 mm towards the drain channel at z = 0."""
    nx, nz = max(1, round((x1 - x0) / step)), max(1, round((z1 - z0) / step))
    vs, us, fs = [], [], []
    for ix in range(nx + 1):
        for iz in range(nz + 1):
            x, z = x0 + (x1 - x0) * ix / nx, z0 + (z1 - z0) * iz / nz
            vs.append(gl(x, 0.012 * min(abs(z), 7.0) / 7.0, z)); us.append((x, z))
    for ix in range(nx):
        for iz in range(nz):
            a = ix * (nz + 1) + iz
            fs.append((a, a + 1, a + nz + 2, a + nz + 1))
    acc.add(vs, fs, us, [(1, 1, 1)] * len(vs))


def build_hall():
    x0, x1, z0, z1, hh = HALL["x0"], HALL["x1"], HALL["z0"], HALL["z1"], HALL["h"]
    P = {"hall_floor": Acc(), "hall_wall": Acc(), "hall_steel": Acc(), "window_glass": Acc(), "grate": Acc(),
         "cellar_wall": Acc(), "cellar_floor": Acc(), "rail": Acc()}
    sx0, sx1, hz0 = ST["x0"], ST["x1"], ST["hole_z0"]
    # floor (with the stairwell opening and the drain channel)
    for (a, b, c, d) in ((sx1, x1, 0.12, z1), (x0, sx1, ST["z_top"], z1), (x0, sx0, 0.12, ST["z_top"]),
                         (sx1, x1, z0, -0.12), (x0, sx1, z0, hz0), (x0, sx0, hz0, -0.12), (x0, sx0, -0.12, 0.12)):
        floor_rect(P["hall_floor"], a, b, c, d)
    floor_rect(P["hall_floor"], x1, x1 + WALL_T, DOOR_Z[0], DOOR_Z[1])          # threshold under the door
    quad(P["grate"], (sx1, -0.005, 0.12), (x1, -0.005, 0.12), (x1, -0.005, -0.12), (sx1, -0.005, -0.12),
         [(0, 0), ((x1 - sx1) / 0.24, 0), ((x1 - sx1) / 0.24, 1), (0, 1)])
    # inner walls: north with a ribbon of high windows, east with the open roller door
    wall(P["hall_wall"], "z", z0, x0, x1, 0, hh, [(a, b, WIN_Y[0], WIN_Y[1]) for a, b in WX], +1)
    for (a, b) in WX:
        rect(P["window_glass"], "z", z0 - 0.08, a, b, WIN_Y[0], WIN_Y[1], +1)
    wall(P["hall_wall"], "z", z1, x0, x1, 0, hh, [(a, b, SWIN_Y[0], SWIN_Y[1]) for a, b in SWX], -1)
    for (a, b) in SWX:
        rect(P["window_glass"], "z", z1 + 0.08, a, b, SWIN_Y[0], SWIN_Y[1], -1)
    rect(P["hall_wall"], "x", x0, z0, z1, 0, hh, +1)
    wall(P["hall_wall"], "x", x1, z0, z1, 0, hh, [(DOOR_Z[0], DOOR_Z[1], 0, DOOR_TOP)], -1)
    rect(P["hall_wall"], "y", hh, x0, x1, z0, z1, -1)
    # roller door: housing drum above the opening and guide rails
    box(P["hall_steel"], (x1 - 0.5, DOOR_TOP, DOOR_Z[0] - 0.2), (x1, DOOR_TOP + 0.5, DOOR_Z[1] + 0.2))
    for zr in (DOOR_Z[0] - 0.1, DOOR_Z[1]):
        box(P["hall_steel"], (x1 - 0.1, 0.0, zr), (x1, DOOR_TOP, zr + 0.1))
    # steel roof trusses (I-beams) + a catwalk over the tank aisle
    for x in (-10.0, -6.0, -2.0, 2.0, 6.0, 10.0):
        box(P["hall_steel"], (x - 0.08, 6.62, z0), (x + 0.08, 6.64, z1))
        box(P["hall_steel"], (x - 0.08, 6.96, z0), (x + 0.08, 6.98, z1))
        box(P["hall_steel"], (x - 0.006, 6.64, z0), (x + 0.006, 6.96, z1))
    cw0, cw1 = -9.0, 6.0
    box(P["grate"], (cw0, 3.72, -0.6), (cw1, 3.76, 0.6))
    for zr in (-0.6, 0.6):
        box(P["hall_steel"], (cw0, 4.72, zr - 0.02), (cw1, 4.76, zr + 0.02))
        box(P["hall_steel"], (cw0, 4.22, zr - 0.012), (cw1, 4.24, zr + 0.012))
        for x in range(-9, 7, 2):
            box(P["hall_steel"], (x - 0.02, 3.76, zr - 0.02), (x + 0.02, 4.76, zr + 0.02))
    for x in (-9.0, -2.0, 5.0):
        for zr in (-0.55, 0.55):
            box(P["hall_steel"], (x - 0.05, 0.0, zr - 0.05), (x + 0.05, 3.72, zr + 0.05))
    # stairs down to the cellar: treads, risers, steel nosings
    for k in range(1, ST["n"] + 1):
        zr = ST["z_top"] - (k - 1) * ST["run"]
        ya, yb = -(k - 1) * ST["rise"], -k * ST["rise"]
        rect(P["hall_floor"], "z", zr, sx0, sx1, yb, ya, -1)      # riser faces down the flight
        if k < ST["n"]:
            rect(P["hall_floor"], "y", yb, sx0, sx1, zr - ST["run"], zr, +1)
            box(P["hall_steel"], (sx0, yb - 0.004, zr - 0.04), (sx1, yb + 0.004, zr))
    # stair tunnel (slate like the cellar), slab underside, lintel, corridor
    for (x, f) in ((sx0, +1), (sx1, -1)):
        rect(P["cellar_wall"], "x", x, ST_BOTTOM_Z, ST["z_top"], ST_FLOOR - 0.05, 0.0, f)
        rect(P["cellar_wall"], "x", x, CORR_END, ST_BOTTOM_Z, ST_FLOOR - 0.05, CORR_CEIL, f)
    rect(P["hall_wall"], "y", -0.3, sx0, sx1, ST_BOTTOM_Z, hz0, -1)
    rect(P["hall_wall"], "z", hz0, sx0, sx1, -0.3, 0.0, +1)
    rect(P["cellar_wall"], "z", ST_BOTTOM_Z, sx0, sx1, CORR_CEIL, -0.3, +1)
    rect(P["cellar_wall"], "y", CORR_CEIL, sx0, sx1, CORR_END, ST_BOTTOM_Z, -1)
    rect(P["cellar_floor"], "y", ST_FLOOR, sx0, sx1, CORR_END, ST_BOTTOM_Z, +1)
    dx0, dx1 = CELLAR_DOOR_X - DOOR / 2, CELLAR_DOOR_X + DOOR / 2
    wall(P["cellar_wall"], "z", CORR_END, sx0, sx1, ST_FLOOR, CORR_CEIL, [(dx0, dx1, ST_FLOOR, ST_FLOOR + DOOR_H)], +1)
    # handrail on the west tunnel wall, railings round the stairwell opening
    hr = [gl(sx0 + 0.07, -k * ST["rise"] + 0.9, ST["z_top"] - k * ST["run"]) for k in range(6, ST["n"] + 1, 3)]
    tube(P["rail"], hr, [0.022] * len(hr), 10, (1, 1, 1))
    for k in range(6, ST["n"], 6):
        zr = ST["z_top"] - k * ST["run"]
        tube(P["rail"], [gl(sx0, -k * ST["rise"] + 0.9, zr), gl(sx0 + 0.07, -k * ST["rise"] + 0.9, zr)], [0.012, 0.012], 6, (1, 1, 1))

    def railing(pa, pb, n_posts):
        for h in (0.55, 1.05):
            tube(P["rail"], [gl(pa[0], h, pa[1]), gl(pb[0], h, pb[1])], [0.022, 0.022], 10, (1, 1, 1))
        for i in range(n_posts):
            t = i / (n_posts - 1)
            x, z = pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t
            tube(P["rail"], [gl(x, 0.0, z), gl(x, 1.07, z)], [0.022, 0.022], 10, (1, 1, 1), cap=True)
    railing((sx1 + 0.05, hz0 - 0.05), (sx1 + 0.05, ST["z_top"] - 0.02), 5)
    railing((sx0 - 0.05, hz0 - 0.05), (sx0 - 0.05, ST["z_top"] - 0.02), 5)
    railing((sx0 - 0.05, hz0 - 0.05), (sx1 + 0.05, hz0 - 0.05), 2)
    interior = make_object("hall", P, smooth=False)

    # ---------------------------------------------------------------- exterior shell (walls, reveals, gable roof)
    E = {"facade": Acc(), "plinth": Acc(), "roof": Acc(), "roof_under": Acc(), "fascia": Acc()}
    X0, X1, Z0, Z1 = x0 - WALL_T, x1 + WALL_T, z0 - WALL_T, z1 + WALL_T
    door_hole = [(DOOR_Z[0], DOOR_Z[1], PLINTH[0] - 0.1, DOOR_TOP)]
    win_holes = [(a, b, WIN_Y[0], WIN_Y[1]) for a, b in WX]
    swin_holes = [(a, b, SWIN_Y[0], SWIN_Y[1]) for a, b in SWX]
    for (mat, v0, v1) in (("plinth", PLINTH[0], PLINTH[1]), ("facade", PLINTH[1], EAVE)):
        wall(E[mat], "x", X1, Z0, Z1, v0, v1, door_hole, +1)
        wall(E[mat], "z", Z0, X0, X1, v0, v1, win_holes, -1)
        wall(E[mat], "z", Z1, X0, X1, v0, v1, swin_holes, +1)
        rect(E[mat], "x", X0, Z0, Z1, v0, v1, -1)
    # reveals: door jambs + lintel, window sides, sills and heads
    rect(E["facade"], "z", DOOR_Z[0], x1, X1, 0.0, DOOR_TOP, +1)
    rect(E["facade"], "z", DOOR_Z[1], x1, X1, 0.0, DOOR_TOP, -1)
    rect(E["facade"], "y", DOOR_TOP, x1, X1, DOOR_Z[0], DOOR_Z[1], -1)
    for (a, b) in WX:
        rect(E["facade"], "x", a, Z0, z0, WIN_Y[0], WIN_Y[1], +1)
        rect(E["facade"], "x", b, Z0, z0, WIN_Y[0], WIN_Y[1], -1)
        rect(E["facade"], "y", WIN_Y[0], a, b, Z0, z0, +1)
        rect(E["facade"], "y", WIN_Y[1], a, b, Z0, z0, -1)
        box(E["fascia"], (a - 0.05, WIN_Y[0] - 0.06, Z0 - 0.06), (b + 0.05, WIN_Y[0], Z0 + 0.02))    # sill
    for (a, b) in SWX:
        rect(E["facade"], "x", a, z1, Z1, SWIN_Y[0], SWIN_Y[1], +1)
        rect(E["facade"], "x", b, z1, Z1, SWIN_Y[0], SWIN_Y[1], -1)
        rect(E["facade"], "y", SWIN_Y[0], a, b, z1, Z1, +1)
        rect(E["facade"], "y", SWIN_Y[1], a, b, z1, Z1, -1)
        box(E["fascia"], (a - 0.05, SWIN_Y[0] - 0.06, Z1 - 0.02), (b + 0.05, SWIN_Y[0], Z1 + 0.06))
        for k in (1, 2):                                                             # glazing bars
            xm = a + (b - a) * k / 3
            box(E["fascia"], (xm - 0.025, SWIN_Y[0], z1 + 0.06), (xm + 0.025, SWIN_Y[1], z1 + 0.1))
        box(E["fascia"], (a, (SWIN_Y[0] + SWIN_Y[1]) / 2 - 0.025, z1 + 0.06), (b, (SWIN_Y[0] + SWIN_Y[1]) / 2 + 0.025, z1 + 0.1))
    # gables
    tp = math.tan(PITCH)
    ridge = EAVE + Z1 * tp
    for (x, s_) in ((X1, +1), (X0, -1)):
        pts = [(x, EAVE, Z0), (x, EAVE, Z1), (x, ridge, 0.0)]
        if s_ > 0:
            pts = [pts[1], pts[0], pts[2]]
        E["facade"].add([gl(*q) for q in pts], [(0, 1, 2)], [(q[2], q[1]) for q in pts], [(1, 1, 1)] * 3)
    # roof: two slabs (top: roof tiles, underside: soffit), fascia boards along the edges, ridge cap
    TH = 0.22
    zo = Z1 + OVERHANG
    xa, xb = X0 - GABLE_OH, X1 + GABLE_OH
    y_eave = EAVE - OVERHANG * tp
    slope = math.hypot(zo, zo * tp)
    for s_ in (-1, 1):
        ze = s_ * zo
        top = [(xa, y_eave + TH, ze), (xb, y_eave + TH, ze), (xb, ridge + TH, 0.0), (xa, ridge + TH, 0.0)]
        und = [(xa, y_eave, ze), (xb, y_eave, ze), (xb, ridge, 0.0), (xa, ridge, 0.0)]
        uv = [(xa, 0), (xb, 0), (xb, slope), (xa, slope)]
        if s_ > 0:                                   # corners run +x then up the slope: faces up on the +z side
            quad(E["roof"], *top, uvs=uv)
            quad(E["roof_under"], *und[::-1], uvs=uv[::-1])
        else:
            quad(E["roof"], *top[::-1], uvs=uv[::-1])
            quad(E["roof_under"], *und, uvs=uv)
        rect(E["fascia"], "z", ze, xa, xb, y_eave - 0.05, y_eave + TH, s_)                     # eave board
        for (x, f) in ((xa, -1), (xb, +1)):                                                     # verge boards
            pts = [(x, y_eave - 0.05, ze), (x, ridge - 0.05, 0.0), (x, ridge + TH, 0.0), (x, y_eave + TH, ze)]
            if (f > 0) != (s_ > 0):
                pts = pts[::-1]
            quad(E["fascia"], *pts)
    box(E["roof"], (xa, ridge + TH - 0.06, -0.16), (xb, ridge + TH + 0.1, 0.16))
    exterior = make_object("hall_ext", E, smooth=False)
    info = {"extent": [X0, X1, Z0, Z1], "eave": EAVE, "ridge": round(ridge + TH + 0.1, 3), "wallT": WALL_T,
            "door": {"x": X1, "z": list(DOOR_Z), "top": DOOR_TOP},
            "stair": dict(ST, bottom_z=ST_BOTTOM_Z, floor=ST_FLOOR, corridor_end=CORR_END, corridor_ceiling=CORR_CEIL)}
    return interior, exterior, info


def _box_entry(a, c):
    return {"c": [round((a[i] + c[i]) / 2, 4) for i in range(3)], "s": [round(abs(c[i] - a[i]), 4) for i in range(3)]}


def hall_collision(tanks):
    """Collision in the building frame: boxes {"c": centre, "s": size, "rx"/"ry": rotation (rad)} and tank
    cylinders {"cyl": radius, "h": height, "c": centre}."""
    x0, x1, z0, z1 = HALL["x0"], HALL["x1"], HALL["z0"], HALL["z1"]
    sx0, sx1, hz0 = ST["x0"], ST["x1"], ST["hole_z0"]
    out = []
    b = lambda a, c: out.append(_box_entry(a, c))
    # floor slab around the stairwell opening, threshold
    b((sx1, -0.3, z0), (x1, 0.0, z1))
    b((x0, -0.3, ST["z_top"]), (sx1, 0.0, z1))
    b((x0, -0.3, z0), (sx1, 0.0, hz0))
    b((x0, -0.3, hz0), (sx0, 0.0, ST["z_top"]))
    b((x1, -0.3, DOOR_Z[0]), (x1 + WALL_T + 0.3, 0.0, DOOR_Z[1]))
    # walls (the tunnel runs under the north wall, below the hall floor)
    b((x0 - WALL_T, -0.3, z0 - WALL_T), (x0, EAVE, z1 + WALL_T))
    b((x0 - WALL_T, 0.0, z0 - WALL_T), (x1 + WALL_T, EAVE, z0))
    b((x0 - WALL_T, -0.3, z1), (x1 + WALL_T, EAVE, z1 + WALL_T))
    b((x1, -0.3, z0 - WALL_T), (x1 + WALL_T, EAVE, DOOR_Z[0]))
    b((x1, -0.3, DOOR_Z[1]), (x1 + WALL_T, EAVE, z1 + WALL_T))
    b((x1, DOOR_TOP, DOOR_Z[0]), (x1 + WALL_T, EAVE, DOOR_Z[1]))
    # railings round the opening
    b((sx1, 0.0, hz0 - 0.1), (sx1 + 0.1, 1.1, ST["z_top"]))
    b((sx0 - 0.1, 0.0, hz0 - 0.1), (sx0, 1.1, ST["z_top"]))
    b((sx0 - 0.1, 0.0, hz0 - 0.1), (sx1 + 0.1, 1.1, hz0))
    # stair ramp (the capsule glides on it; treads are visual only)
    z_a, z_b = ST["z_top"], ST_BOTTOM_Z
    run, drop = z_a - z_b, -ST_FLOOR
    ang = math.atan2(drop, run)
    length = math.hypot(run, drop)
    th = 0.3
    cy = -drop / 2 - th / 2 * math.cos(ang)
    cz = (z_a + z_b) / 2 - th / 2 * math.sin(ang)
    out.append({"c": [round((sx0 + sx1) / 2, 4), round(cy, 4), round(cz, 4)], "s": [sx1 - sx0, th, round(length + 0.3, 4)], "rx": round(-ang, 5)})
    # tunnel walls, corridor floor, doorway jambs and lintel, corridor ceiling
    b((sx0 - 0.3, ST_FLOOR - 0.2, CORR_END - 0.4), (sx0, 0.0, ST["z_top"]))
    b((sx1, ST_FLOOR - 0.2, CORR_END - 0.4), (sx1 + 0.3, 0.0, ST["z_top"]))
    b((sx0, ST_FLOOR - 0.3, CORR_END - REVEAL - 0.05), (sx1, ST_FLOOR, ST_BOTTOM_Z + 0.3))
    dx0, dx1 = CELLAR_DOOR_X - DOOR / 2, CELLAR_DOOR_X + DOOR / 2
    b((sx0, ST_FLOOR, CORR_END - REVEAL), (dx0, CORR_CEIL, CORR_END))
    b((dx1, ST_FLOOR, CORR_END - REVEAL), (sx1, CORR_CEIL, CORR_END))
    b((dx0, ST_FLOOR + DOOR_H, CORR_END - REVEAL), (dx1, CORR_CEIL, CORR_END))
    b((sx0, CORR_CEIL, CORR_END - REVEAL), (sx1, CORR_CEIL + 0.3, ST_BOTTOM_Z))
    # catwalk posts, crate stack, ladder, tanks
    for x in (-9.0, -2.0, 5.0):
        for zr in (-0.55, 0.55):
            b((x - 0.06, 0.0, zr - 0.06), (x + 0.06, 3.72, zr + 0.06))
    b((8.85, 0.0, -5.75), (10.75, 1.0, -4.35))
    b((-12.0, 0.0, 3.8), (-11.3, 2.5, 4.6))
    for t in tanks:
        out.append({"cyl": 0.9, "h": 3.6, "c": [t["pos"][0], 1.8, t["pos"][2]]})
    return out


def cellar_collision(door_leaf):
    """Collision boxes in the cellar's own frame (floor y = 0, long axis x, doorway at x = -L/2)."""
    L, W = CELLAR["L"], CELLAR["W"]
    out = []
    b = lambda a, c: out.append(_box_entry(a, c))
    b((-L / 2 - REVEAL - 0.1, -0.3, -W / 2), (L / 2, 0.0, W / 2))
    b((-L / 2, 0.0, W / 2), (L / 2, 5.0, W / 2 + 0.3))
    b((-L / 2, 0.0, -W / 2 - 0.3), (L / 2, 5.0, -W / 2))
    b((L / 2, 0.0, -W / 2), (L / 2 + 0.3, 5.0, W / 2))
    b((-L / 2 - 0.3, 0.0, -W / 2), (-L / 2, 5.0, -DOOR / 2))
    b((-L / 2 - 0.3, 0.0, DOOR / 2), (-L / 2, 5.0, W / 2))
    b((-L / 2 - 0.3, DOOR_H, -DOOR / 2), (-L / 2, 5.0, DOOR / 2))
    b((-10.5, 0.0, -W / 2), (4.75, 1.4, -2.08))                         # barrique racks
    b((-10.5, 0.0, 2.08), (10.55, 1.4, W / 2))
    b((5.25, 0.0, -W / 2), (9.65, 1.3, -1.8))                           # Fuder
    hx, hz = door_leaf["hinge"]
    a = door_leaf["angle"]
    ux, uz = math.sin(a), -math.cos(a)
    cx, cz = hx + ux * DOOR / 2, hz + uz * DOOR / 2
    out.append({"c": [round(cx, 4), 1.05, round(cz, 4)], "s": [round(DOOR, 3), 2.1, 0.08], "ry": round(math.atan2(-uz, ux), 5)})
    return out


def occluders():
    """Occluder boxes (building frame) inside the exterior walls and the roof, leaving the door and windows open."""
    x0, x1, z0, z1 = HALL["x0"], HALL["x1"], HALL["z0"], HALL["z1"]
    out = []
    t = WALL_T - 0.12
    for (a, b_, c, d) in split_holes(z0 - WALL_T, z1 + WALL_T, 0.0, EAVE, [(DOOR_Z[0], DOOR_Z[1], -1.0, DOOR_TOP)]):
        out.append({"c": [x1 + WALL_T / 2, (c + d) / 2, (a + b_) / 2], "s": [t, d - c, b_ - a]})
    for (a, b_, c, d) in split_holes(x0 - WALL_T, x1 + WALL_T, 0.0, EAVE, [(p, q, WIN_Y[0], WIN_Y[1]) for p, q in WX]):
        out.append({"c": [(a + b_) / 2, (c + d) / 2, z0 - WALL_T / 2], "s": [b_ - a, d - c, t]})
    for (a, b_, c, d) in split_holes(x0 - WALL_T, x1 + WALL_T, 0.0, EAVE, [(p, q, SWIN_Y[0], SWIN_Y[1]) for p, q in SWX]):
        out.append({"c": [(a + b_) / 2, (c + d) / 2, z1 + WALL_T / 2], "s": [b_ - a, d - c, t]})
    out.append({"c": [x0 - WALL_T / 2, EAVE / 2, 0.0], "s": [t, EAVE, z1 - z0 + 2 * WALL_T]})
    out.append({"c": [0.0, HALL["h"] + 0.15, 0.0], "s": [x1 - x0, 0.2, z1 - z0]})
    return out


# =========================================================================== outside detail, yard, tractors
# All in the building frame (see above). Low-poly: boxes, quads and a few 8-12-sided tubes.
SIGN = dict(z=(-2.5, 2.5), y=(4.85, 5.75))
OFFICE_DOOR = dict(z=(3.4, 4.4), top=2.2)
OFFICE_WIN = dict(z=(5.1, 6.7), y=(1.0, 2.3))
LEANTO = dict(x=(3.0, 11.6), depth=3.2, y_wall=3.4, y_edge=2.8)
PRESS = (7.7, HALL["z1"] + WALL_T + 1.55)
DESTEM = (10.35, HALL["z1"] + WALL_T + 1.5)
SORTING = (4.35, HALL["z1"] + WALL_T + 1.9)          # sorting table (shown by workers.gd while grapes are sorted)
BINS = [(16.4, 0.0, 6.4), (17.8, 0.0, 6.4), (16.4, 0.76, 6.4)]
PALLET = (15.2, -6.6)
TRACTOR = dict(pos=[19.2, 0.0, -5.2], yaw=0.0)


def cylinder(acc, c, axis, r, length, sides=12, caps=True):
    """Closed cylinder in glTF coords, centred at c, along 'x' | 'y' | 'z'."""
    verts, faces, uvs = [], [], []
    for k, s in enumerate((-0.5, 0.5)):
        for i in range(sides):
            a = 2 * math.pi * i / sides
            u, v = r * math.cos(a), r * math.sin(a)
            p = {"x": (s * length, u, v), "y": (u, s * length, v), "z": (u, v, s * length)}[axis]
            verts.append(gl(c[0] + p[0], c[1] + p[1], c[2] + p[2])); uvs.append((i / sides * 2, k))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    if caps:
        faces.append(tuple(range(sides - 1, -1, -1)))
        faces.append(tuple(range(sides, 2 * sides)))
    acc.add(verts, faces, uvs, [(1, 1, 1)] * len(verts))


def build_yard():
    X1, Z1 = HALL["x1"] + WALL_T, HALL["z1"] + WALL_T
    X0 = HALL["x0"] - WALL_T
    Y = {k: Acc() for k in ("gutter", "sign_board", "fascia", "door_wood", "window_dark", "plinth", "rack_wood",
                            "canopy_roof", "tank_steel", "hall_steel", "bin_plastic")}
    tp = math.tan(PITCH)
    y_eave = EAVE - OVERHANG * tp
    ze = Z1 + OVERHANG
    # gutters along both eaves, downpipes at the corners (into the wall, down, a shoe at the foot)
    for s_ in (-1, 1):
        cylinder(Y["gutter"], (0.0, y_eave - 0.03, s_ * (ze + 0.08)), "x", 0.075, X1 - X0 + 2 * GABLE_OH, 10)
        for x in (X0 + 0.45, X1 - 0.45):
            pts = [gl(x, y_eave - 0.05, s_ * (ze + 0.08)), gl(x, y_eave - 0.45, s_ * (Z1 + 0.08)),
                   gl(x, 0.35, s_ * (Z1 + 0.08)), gl(x, 0.08, s_ * (Z1 + 0.3))]
            tube(Y["gutter"], pts, [0.05] * 4, 10, (1, 1, 1))
    # sign board over the roller door (the estate name is a Label3D in winery.gd)
    box(Y["fascia"], (X1, SIGN["y"][0] - 0.06, SIGN["z"][0] - 0.06), (X1 + 0.05, SIGN["y"][1] + 0.06, SIGN["z"][1] + 0.06))
    box(Y["sign_board"], (X1 + 0.05, SIGN["y"][0], SIGN["z"][0]), (X1 + 0.08, SIGN["y"][1], SIGN["z"][1]))
    # office / tasting-room door: frame, panelled leaf, handle, step
    d0, d1 = OFFICE_DOOR["z"]
    top = OFFICE_DOOR["top"]
    box(Y["fascia"], (X1, 0.0, d0 - 0.1), (X1 + 0.07, top + 0.1, d0))
    box(Y["fascia"], (X1, 0.0, d1), (X1 + 0.07, top + 0.1, d1 + 0.1))
    box(Y["fascia"], (X1, top, d0 - 0.1), (X1 + 0.07, top + 0.1, d1 + 0.1))
    box(Y["door_wood"], (X1, 0.15, d0), (X1 + 0.04, top, d1))
    for (ya, yb) in ((0.35, 1.05), (1.25, 2.0)):
        box(Y["door_wood"], (X1 + 0.04, ya, d0 + 0.12), (X1 + 0.06, yb, d1 - 0.12))
    cylinder(Y["hall_steel"], (X1 + 0.09, 1.05, d1 - 0.12), "z", 0.012, 0.14, 6)
    box(Y["plinth"], (X1, 0.0, d0 - 0.25), (X1 + 0.55, 0.15, d1 + 0.25))
    # office window with glazing bars and a sill
    w0, w1 = OFFICE_WIN["z"]
    v0, v1 = OFFICE_WIN["y"]
    box(Y["window_dark"], (X1, v0, w0), (X1 + 0.02, v1, w1))
    for (a, b, c, d) in ((w0 - 0.07, w0, v0, v1), (w1, w1 + 0.07, v0, v1), (w0 - 0.07, w1 + 0.07, v1, v1 + 0.07),
                         ((w0 + w1) / 2 - 0.025, (w0 + w1) / 2 + 0.025, v0, v1), (w0, w1, (v0 + v1) / 2 - 0.025, (v0 + v1) / 2 + 0.025)):
        box(Y["fascia"], (X1, c, a), (X1 + 0.06, d, b))
    box(Y["fascia"], (X1, v0 - 0.06, w0 - 0.1), (X1 + 0.12, v0, w1 + 0.1))
    # bench under the window
    bx0, bx1 = X1 + 0.2, X1 + 0.62
    box(Y["rack_wood"], (bx0, 0.42, w0 + 0.05), (bx1, 0.47, w1 - 0.05))
    box(Y["rack_wood"], (X1 + 0.08, 0.55, w0 + 0.05), (X1 + 0.12, 0.95, w1 - 0.05))
    for z in (w0 + 0.15, w1 - 0.2):
        box(Y["hall_steel"], (bx0 + 0.02, 0.0, z), (bx1 - 0.02, 0.42, z + 0.05))
    # lean-to canopy along the south wall with a basket press and a destemmer-crusher under it
    lx0, lx1 = LEANTO["x"]
    zo = Z1 + LEANTO["depth"]
    yw, ye = LEANTO["y_wall"], LEANTO["y_edge"]
    for x in (lx0 + 0.1, (lx0 + lx1) / 2, lx1 - 0.1):
        box(Y["rack_wood"], (x - 0.07, 0.0, zo - 0.2), (x + 0.07, ye, zo - 0.06))
        # rafter from the wall to the edge beam
        pts = [(x - 0.05, yw - 0.02, Z1), (x + 0.05, yw - 0.02, Z1), (x + 0.05, ye - 0.02, zo), (x - 0.05, ye - 0.02, zo)]
        Y["rack_wood"].add([gl(*q) for q in pts], [(0, 3, 2, 1)], [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    box(Y["rack_wood"], (lx0, ye - 0.18, zo - 0.2), (lx1, ye, zo - 0.06))
    box(Y["rack_wood"], (lx0, yw - 0.18, Z1), (lx1, yw, Z1 + 0.12))
    slope_len = math.hypot(zo - Z1 + 0.3, yw - ye)
    for (dy, flip) in ((0.0, False), (-0.02, True)):
        pts = [(lx0 - 0.2, yw + dy, Z1), (lx1 + 0.2, yw + dy, Z1), (lx1 + 0.2, ye - 0.05 + dy, zo + 0.3), (lx0 - 0.2, ye - 0.05 + dy, zo + 0.3)]
        f = [(0, 3, 2, 1)] if not flip else [(0, 1, 2, 3)]
        Y["canopy_roof"].add([gl(*q) for q in pts], f, [(0, 0), (lx1 - lx0, 0), (lx1 - lx0, slope_len), (0, slope_len)], [(1, 1, 1)] * 4)
    # basket press: legs, tray, slatted oak basket with two hoops, central screw and ratchet bar
    px, pz = PRESS
    for dx in (-0.55, 0.55):
        for dz in (-0.55, 0.55):
            cylinder(Y["hall_steel"], (px + dx, 0.23, pz + dz), "y", 0.04, 0.46, 8)
    box(Y["tank_steel"], (px - 0.72, 0.46, pz - 0.72), (px + 0.72, 0.56, pz + 0.72))
    for i in range(22):
        a = 2 * math.pi * i / 22
        cx, cz = px + 0.47 * math.cos(a), pz + 0.47 * math.sin(a)
        ex, ez = 0.045 * math.sin(a), -0.045 * math.cos(a)
        pts = [(cx - ex, 0.56, cz - ez), (cx + ex, 0.56, cz + ez), (cx + ex, 1.42, cz + ez), (cx - ex, 1.42, cz - ez)]
        o = [(q[0] + 0.025 * math.cos(a), q[1], q[2] + 0.025 * math.sin(a)) for q in pts]
        Y["rack_wood"].add([gl(*q) for q in o], [(0, 1, 2, 3)], [(0, 0), (0.1, 0), (0.1, 1), (0, 1)], [(1, 1, 1)] * 4)
    for yh in (0.72, 1.28):
        cylinder(Y["hall_steel"], (px, yh, pz), "y", 0.51, 0.06, 20, caps=False)
    cylinder(Y["tank_steel"], (px, 1.35, pz), "y", 0.035, 1.6, 8)
    box(Y["hall_steel"], (px - 0.5, 1.95, pz - 0.06), (px + 0.5, 2.05, pz + 0.06))
    for dx in (-0.5, 0.5):
        box(Y["hall_steel"], (px + dx - 0.05, 0.56, pz - 0.05), (px + dx + 0.05, 2.05, pz + 0.05))
    cylinder(Y["hall_steel"], (px + 0.35, 1.75, pz), "x", 0.02, 0.7, 6)
    # destemmer-crusher: stainless body on legs, wide hopper, motor box
    qx, qz = DESTEM
    for dx in (-0.5, 0.5):
        for dz in (-0.3, 0.3):
            cylinder(Y["hall_steel"], (qx + dx, 0.4, qz + dz), "y", 0.035, 0.8, 8)
    box(Y["tank_steel"], (qx - 0.62, 0.8, qz - 0.36), (qx + 0.62, 1.2, qz + 0.36))
    pts = [(qx - 0.6, 1.2, qz - 0.34), (qx + 0.6, 1.2, qz - 0.34), (qx + 0.8, 1.62, qz - 0.58), (qx - 0.8, 1.62, qz - 0.58)]
    for s_ in (-1, 1):
        q = [(p[0], p[1], qz + s_ * (p[2] - qz)) for p in pts]
        f = [(0, 1, 2, 3)] if s_ < 0 else [(0, 3, 2, 1)]
        Y["tank_steel"].add([gl(*p) for p in q], f, [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    for s_ in (-1, 1):
        q = [(qx + s_ * 0.6, 1.2, qz - 0.34), (qx + s_ * 0.6, 1.2, qz + 0.34), (qx + s_ * 0.8, 1.62, qz + 0.58), (qx + s_ * 0.8, 1.62, qz - 0.58)]
        f = [(0, 1, 2, 3)] if s_ > 0 else [(0, 3, 2, 1)]
        Y["tank_steel"].add([gl(*p) for p in q], f, [(0, 0), (1, 0), (1, 1), (0, 1)], [(1, 1, 1)] * 4)
    box(Y["hall_steel"], (qx + 0.62, 0.85, qz - 0.2), (qx + 0.95, 1.15, qz + 0.2))
    # half-tonne picking bins (open top), stacked
    for (x, y, z) in BINS:
        w, h, d, t = 1.2, 0.76, 1.0, 0.04
        box(Y["bin_plastic"], (x - w / 2, y, z - d / 2), (x + w / 2, y + 0.06, z + d / 2))
        box(Y["bin_plastic"], (x - w / 2, y, z - d / 2), (x + w / 2, y + h, z - d / 2 + t))
        box(Y["bin_plastic"], (x - w / 2, y, z + d / 2 - t), (x + w / 2, y + h, z + d / 2))
        box(Y["bin_plastic"], (x - w / 2, y, z - d / 2), (x - w / 2 + t, y + h, z + d / 2))
        box(Y["bin_plastic"], (x + w / 2 - t, y, z - d / 2), (x + w / 2, y + h, z + d / 2))
    # pallet (a crate stack goes on it, see winery.json exteriorProps)
    px_, pz_ = PALLET
    for dz in (-0.5, 0.0, 0.5):
        box(Y["rack_wood"], (px_ - 0.6, 0.0, pz_ + dz - 0.05), (px_ + 0.6, 0.1, pz_ + dz + 0.05))
    for i in range(7):
        x = px_ - 0.6 + 0.2 * i
        box(Y["rack_wood"], (x - 0.045, 0.1, pz_ - 0.55), (x + 0.045, 0.13, pz_ + 0.55))
    yard = make_object("yard", Y, smooth=False)
    info = {"sign": {"pos": [X1 + 0.085, (SIGN["y"][0] + SIGN["y"][1]) / 2, 0.0], "w": SIGN["z"][1] - SIGN["z"][0], "h": SIGN["y"][1] - SIGN["y"][0]},
            "lamp": {"pos": [X1, 2.75, 2.85], "facing": [1, 0, 0]},
            "tractor": TRACTOR, "sortingTable": {"pos": [SORTING[0], 0.0, SORTING[1]], "yaw": 0.0}}
    col = []
    b = lambda a, c: col.append(_box_entry(a, c))
    for x in (lx0 + 0.1, (lx0 + lx1) / 2, lx1 - 0.1):
        b((x - 0.08, 0.0, zo - 0.21), (x + 0.08, ye, zo - 0.05))
    b((px - 0.75, 0.0, pz - 0.75), (px + 0.75, 2.05, pz + 0.75))
    b((qx - 0.8, 0.0, qz - 0.6), (qx + 0.95, 1.62, qz + 0.6))
    b((15.8, 0.0, 5.9), (18.4, 1.52, 6.9))
    b((px_ - 0.6, 0.0, pz_ - 0.6), (px_ + 0.6, 1.2, pz_ + 0.6))
    b((bx0, 0.0, w0 + 0.05), (bx1, 0.47, w1 - 0.05))
    b((X1, 0.0, d0 - 0.25), (X1 + 0.55, 0.15, d1 + 0.25))
    t = TRACTOR["pos"]
    b((t[0] - 1.5, 0.0, t[2] - 1.0), (t[0] + 1.9, 2.4, t[2] + 1.0))
    b((3.05, 0.0, Z1 + 2.3), (3.9, 1.0, Z1 + 3.05))                                         # crate stack
    return yard, info, col


def build_tractors():
    """Three small tractors facing +x, origin on the ground between the axles: 'crawler' (Mosel steep-slope
    tracked tractor), 'straddle' (Côte d'Or high-clearance straddle tractor), 'standard' (Napa)."""
    obs = []

    def wheel(A, x, z, r, w):
        cylinder(A["tractor_tyre"], (x, r, z), "z", r, w, 14)
        cylinder(A["tractor_metal"], (x, r, z), "z", r * 0.55, w + 0.02, 10)

    def seat_rops(A, x, y, halfw, h):
        box(A["tractor_metal"], (x - 0.25, y, -0.22), (x + 0.15, y + 0.1, 0.22))
        box(A["tractor_metal"], (x - 0.3, y + 0.1, -0.22), (x - 0.22, y + 0.55, 0.22))
        for z in (-halfw, halfw):
            cylinder(A["tractor_metal"], (x - 0.35, y + h / 2, z), "y", 0.035, h, 8)
        cylinder(A["tractor_metal"], (x - 0.35, y + h, 0.0), "z", 0.035, 2 * halfw + 0.07, 8)
        tube(A["tractor_metal"], [gl(x + 0.35, y + 0.2, 0.0), gl(x + 0.25, y + 0.62, 0.0)], [0.02, 0.02], 6, (1, 1, 1))
        cylinder(A["tractor_metal"], (x + 0.24, y + 0.64, 0.0), "y", 0.14, 0.03, 12)

    # standard compact tractor
    A = {k: Acc() for k in ("tractor_paint", "tractor_tyre", "tractor_metal")}
    for z in (-0.72, 0.72):
        wheel(A, -0.55, z, 0.62, 0.34)
        wheel(A, 1.25, z * 0.9, 0.38, 0.22)
    box(A["tractor_paint"], (0.15, 0.5, -0.34), (1.75, 1.18, 0.34))                  # bonnet
    box(A["tractor_metal"], (1.72, 0.55, -0.3), (1.78, 1.1, 0.3))                   # grille
    box(A["tractor_paint"], (-0.9, 0.55, -0.42), (0.25, 1.0, 0.42))                 # body / transmission
    for z in (-0.72, 0.72):
        box(A["tractor_paint"], (-1.05, 1.12, z - 0.2), (-0.05, 1.18, z + 0.2))     # fenders
        box(A["tractor_paint"], (-1.05, 0.62, z - 0.2 if z > 0 else z + 0.14), (-0.99, 1.18, z + 0.2 if z < 0 else z - 0.14))
    cylinder(A["tractor_metal"], (1.3, 1.5, 0.22), "y", 0.04, 0.7, 8)                # exhaust
    seat_rops(A, -0.45, 1.0, 0.45, 1.3)
    obs.append(make_object("tractor_standard", A, smooth=False))
    # steep-slope crawler (narrow, tracked)
    A = {k: Acc() for k in ("tractor_paint", "tractor_tyre", "tractor_metal")}
    for z in (-0.46, 0.46):
        box(A["tractor_tyre"], (-0.85, 0.08, z - 0.13), (0.85, 0.42, z + 0.13))
        cylinder(A["tractor_tyre"], (-0.85, 0.25, z), "z", 0.25, 0.26, 12)
        cylinder(A["tractor_tyre"], (0.85, 0.25, z), "z", 0.25, 0.26, 12)
        for x in (-0.45, 0.0, 0.45):
            cylinder(A["tractor_metal"], (x, 0.22, z), "z", 0.12, 0.28, 8)
    box(A["tractor_paint"], (-0.8, 0.42, -0.3), (0.95, 0.95, 0.3))
    box(A["tractor_paint"], (0.3, 0.95, -0.28), (1.0, 1.15, 0.28))
    box(A["tractor_metal"], (0.98, 0.45, -0.25), (1.03, 1.1, 0.25))
    cylinder(A["tractor_metal"], (0.75, 1.45, 0.18), "y", 0.035, 0.6, 8)
    seat_rops(A, -0.35, 0.95, 0.34, 1.2)
    obs.append(make_object("tractor_crawler", A, smooth=False))
    # straddle tractor (enjambeur): portal legs over one row, cab on top
    A = {k: Acc() for k in ("tractor_paint", "tractor_tyre", "tractor_metal", "window_glass")}
    for x in (-1.0, 1.0):
        for z in (-0.78, 0.78):
            wheel(A, x, z, 0.42, 0.24)
            box(A["tractor_paint"], (x - 0.1, 0.42, z - 0.08), (x + 0.1, 1.95, z + 0.08))
    box(A["tractor_paint"], (-1.3, 1.95, -0.9), (1.3, 2.4, 0.9))
    box(A["tractor_metal"], (-1.25, 1.9, -0.86), (1.25, 1.95, 0.86))
    box(A["tractor_metal"], (-0.25, 2.4, -0.55), (0.95, 2.48, 0.55))
    box(A["tractor_metal"], (-0.25, 3.25, -0.58), (0.95, 3.32, 0.58))
    for x in (-0.25, 0.95):
        for z in (-0.55, 0.55):
            box(A["tractor_metal"], (x - 0.03, 2.48, z - 0.03), (x + 0.03, 3.25, z + 0.03))
    box(A["window_glass"], (-0.24, 2.48, -0.54), (0.94, 3.25, 0.54))
    cylinder(A["tractor_metal"], (-0.9, 2.9, 0.6), "y", 0.04, 1.0, 8)
    obs.append(make_object("tractor_straddle", A, smooth=False))
    return obs


# =========================================================================== field workers, trailer, sprayer, bins
# workers.glb (glTF coords, metres): "person" faces -Z, feet at the origin. UV2.x carries a part code the worker
# shader animates by (game/src/view3d/shaders/worker.gdshader): 1/2 left/right leg (+boot), 3/4 left/right arm
# (right arm carries the spray lance), 5 torso/head/hat, 6 bucket (on the ground by the right foot; lifted to the
# hand when carried), 7 backpack sprayer. Materials w_skin/w_shirt/w_trousers/w_hat/w_gear are tinted per person.
def build_workers():
    obs = []
    P = {k: Acc() for k in ("w_skin", "w_shirt", "w_trousers", "w_hat", "w_gear")}

    def part(acc, code, fn):
        n0 = len(acc.v)
        fn()
        for i in range(n0, len(acc.v)):
            acc.uv2[i] = (float(code), 0.0)

    for side, code in ((-1, 1), (1, 2)):
        x0, x1 = (side * 0.03, side * 0.17) if side > 0 else (side * 0.17, side * 0.03)
        part(P["w_trousers"], code, lambda x0=x0, x1=x1: box(P["w_trousers"], (x0, 0.07, -0.075), (x1, 0.93, 0.075)))
        part(P["w_gear"], code, lambda x0=x0, x1=x1: box(P["w_gear"], (x0 - 0.01, 0.0, -0.15), (x1 + 0.01, 0.08, 0.08)))
    part(P["w_shirt"], 5, lambda: box(P["w_shirt"], (-0.2, 0.9, -0.115), (0.2, 1.46, 0.115)))
    part(P["w_trousers"], 5, lambda: box(P["w_trousers"], (-0.19, 0.86, -0.11), (0.19, 0.95, 0.11)))      # belt / hips
    for side, code in ((-1, 3), (1, 4)):
        x0, x1 = (0.205, 0.3) if side > 0 else (-0.3, -0.205)
        part(P["w_shirt"], code, lambda x0=x0, x1=x1: box(P["w_shirt"], (x0, 0.84, -0.055), (x1, 1.44, 0.055)))
        part(P["w_skin"], code, lambda x0=x0, x1=x1: box(P["w_skin"], (x0 + 0.005, 0.72, -0.045), (x1 - 0.005, 0.84, 0.045)))
    part(P["w_skin"], 5, lambda: box(P["w_skin"], (-0.05, 1.46, -0.05), (0.05, 1.5, 0.05)))
    part(P["w_skin"], 5, lambda: C.berry_sphere(P["w_skin"], gl(0.0, 1.6, 0.0), 0.115, (1, 1, 1), seg=10, rings=7))
    part(P["w_hat"], 5, lambda: cylinder(P["w_hat"], (0.0, 1.685, 0.0), "y", 0.2, 0.02, 12))
    part(P["w_hat"], 5, lambda: cylinder(P["w_hat"], (0.0, 1.73, 0.0), "y", 0.115, 0.08, 12))
    # bucket (open top) by the right foot
    def bucket():
        cylinder(P["w_gear"], (0.34, 0.13, -0.02), "y", 0.12, 0.25, 12, caps=False)
        cylinder(P["w_gear"], (0.34, 0.01, -0.02), "y", 0.1, 0.02, 12)
    part(P["w_gear"], 6, bucket)
    # backpack sprayer + lance in the right hand
    part(P["w_gear"], 7, lambda: box(P["w_gear"], (-0.15, 0.98, 0.115), (0.15, 1.46, 0.3)))
    part(P["w_gear"], 4, lambda: box(P["w_gear"], (0.24, 0.76, -0.62), (0.265, 0.785, -0.02)))
    obs.append(make_object("person", P, smooth=False))

    # trailer with two picking bins (hitched behind a tractor facing +x: drawbar towards +x)
    T = {k: Acc() for k in ("tractor_paint", "tractor_tyre", "tractor_metal", "bin_plastic")}
    box(T["tractor_metal"], (-1.3, 0.5, -0.8), (1.3, 0.6, 0.8))
    box(T["tractor_metal"], (1.3, 0.48, -0.05), (2.3, 0.56, 0.05))
    for z in (-0.9, 0.9):
        cylinder(T["tractor_tyre"], (0.0, 0.33, z), "z", 0.33, 0.2, 12)
    for x in (-0.65, 0.65):
        w, h, d, t, y = 1.15, 0.72, 1.0, 0.04, 0.6
        box(T["bin_plastic"], (x - w / 2, y, -d / 2), (x + w / 2, y + 0.06, d / 2))
        box(T["bin_plastic"], (x - w / 2, y, -d / 2), (x + w / 2, y + h, -d / 2 + t))
        box(T["bin_plastic"], (x - w / 2, y, d / 2 - t), (x + w / 2, y + h, d / 2))
        box(T["bin_plastic"], (x - w / 2, y, -d / 2), (x - w / 2 + t, y + h, d / 2))
        box(T["bin_plastic"], (x + w / 2 - t, y, -d / 2), (x + w / 2, y + h, d / 2))
    obs.append(make_object("trailer", T, smooth=False))
    # air-blast vineyard sprayer: tank on two wheels, fan housing at the back
    S = {k: Acc() for k in ("tractor_tyre", "tractor_metal", "sprayer_tank")}
    cylinder(S["sprayer_tank"], (0.1, 0.9, 0.0), "x", 0.45, 1.5, 14)
    box(S["tractor_metal"], (-0.8, 0.42, -0.35), (0.9, 0.5, 0.35))
    box(S["tractor_metal"], (0.9, 0.46, -0.05), (1.9, 0.52, 0.05))
    cylinder(S["tractor_metal"], (-0.95, 0.95, 0.0), "x", 0.5, 0.35, 16)
    cylinder(S["tractor_tyre"], (-1.13, 0.95, 0.0), "x", 0.42, 0.02, 16)
    for z in (-0.55, 0.55):
        cylinder(S["tractor_tyre"], (0.1, 0.3, z), "z", 0.3, 0.18, 12)
    obs.append(make_object("sprayer", S, smooth=False))
    # a single picking bin
    B = {"bin_plastic": Acc()}
    w, h, d, t = 1.15, 0.72, 1.0, 0.04
    box(B["bin_plastic"], (-w / 2, 0.0, -d / 2), (w / 2, 0.06, d / 2))
    box(B["bin_plastic"], (-w / 2, 0.0, -d / 2), (w / 2, h, -d / 2 + t))
    box(B["bin_plastic"], (-w / 2, 0.0, d / 2 - t), (w / 2, h, d / 2))
    box(B["bin_plastic"], (-w / 2, 0.0, -d / 2), (-w / 2 + t, h, d / 2))
    box(B["bin_plastic"], (w / 2 - t, 0.0, -d / 2), (w / 2, h, d / 2))
    obs.append(make_object("bin", B, smooth=False))
    # sorting table: stainless tray on legs, dark belt, a bin at the discharge end (long axis x)
    Q = {k: Acc() for k in ("tank_steel", "tractor_tyre", "hall_steel", "bin_plastic")}
    for x in (-1.1, 1.1):
        for z in (-0.3, 0.3):
            box(Q["hall_steel"], (x - 0.03, 0.0, z - 0.03), (x + 0.03, 0.9, z + 0.03))
    box(Q["tank_steel"], (-1.3, 0.88, -0.38), (1.3, 0.92, 0.38))
    for z in (-0.38, 0.34):
        box(Q["tank_steel"], (-1.3, 0.92, z), (1.3, 1.02, z + 0.04))
    box(Q["tractor_tyre"], (-1.25, 0.92, -0.3), (1.25, 0.935, 0.3))
    box(Q["bin_plastic"], (1.35, 0.0, -0.45), (2.3, 0.62, 0.45))
    obs.append(make_object("sorting_table", Q, smooth=False))
    return obs


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
cellar_ob, cellar_items, cellar_lights, door_leaf = build_cellar(R)
export(cellar_ob, "cellar.glb")
C.clear_scene()
hall_ob, hall_ext_ob, building = build_hall()
export(hall_ob, "hall.glb")
export(hall_ext_ob, "hall_ext.glb")
C.clear_scene()
yard_ob, yard_info, yard_col = build_yard()
export(yard_ob, "yard.glb")
C.clear_scene()
export(build_tractors(), "tractors.glb")
C.clear_scene()
export(build_workers(), "workers.glb")
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
props += [{"model": "ladder_sectioned_01", "pos": [-11.6, 0.0, 4.2], "yaw": math.pi / 2}]
stair_lights = [{"pos": [ST["x0"] + 0.02, -1.1, -3.3], "facing": [1, 0, 0], "color": [1.0, 0.74, 0.46]},
                {"pos": [ST["x1"] - 0.02, -2.95, -5.9], "facing": [-1, 0, 0], "color": [1.0, 0.74, 0.46]},
                {"pos": [ST["x1"] - 0.02, ST_FLOOR + 2.05, -7.85], "facing": [-1, 0, 0], "color": [1.0, 0.74, 0.46]},
                {"pos": [ST["x0"] + 0.02, ST_FLOOR + 2.05, -8.3], "facing": [1, 0, 0], "color": [1.0, 0.74, 0.46]}]
Z1o = HALL["z1"] + WALL_T
ext_props = [{"model": "plastic_crate_01", "pos": [14.9 + 0.62 * (k % 2), 0.13 + 0.33 * (k // 4), -6.82 + 0.45 * ((k // 2) % 2)], "yaw": 0.0} for k in range(12)]
ext_props += [{"model": "plastic_crate_01", "pos": [3.2 + 0.45 * ((k // 2) % 2), 0.33 * (k // 4), Z1o + 2.4 + 0.45 * (k % 2)], "yaw": math.pi / 2} for k in range(8)]
C2B = cellar_to_building
eye = 1.65
layout = {
    "note": ("Winery layout for game/src/view3d/winery.gd. glTF coords (Y up, metres). Everything is in the building "
             "frame (hall floor y = 0) except the 'cellar' section, which is in the cellar's own frame; "
             "building.cellarXform places it (x_b = ox + z_c, y_b = oy + y_c, z_b = oz - x_c)."),
    "cameras": {
        "cellar": {"position": C2B([-10.2, 1.62, 0.0]), "target": C2B([8.0, 1.3, 0.0])},
        "cellar_heads": {"position": C2B([-9.7, 1.2, -0.45]), "target": C2B([-8.6, 0.75, -2.1])},
        "cellar_fuder": {"position": C2B([5.6, 1.55, -0.2]), "target": C2B([7.45, 0.85, -1.9])},
        "cellar_door": {"position": C2B([-6.0, 1.62, 0.9]), "target": C2B([-11.6, 1.2, 0.0])},
        "hall": {"position": [10.5, 2.2, 5.8], "target": [-6.0, 1.8, -1.0]},
        "hall_panel": {"position": [-7.72, 1.62, -1.72], "target": [-8.0, 1.52, -2.45]},
        "hall_stairs": {"position": [-6.2, eye, 2.6], "target": [-10.9, -0.6, -1.5]},
        "stairs_down": {"position": [CELLAR_DOOR_X, eye, 2.2], "target": [CELLAR_DOOR_X, -3.3, -7.4]},
        "stairs_up": {"position": [CELLAR_DOOR_X, ST_FLOOR + eye, -8.3], "target": [CELLAR_DOOR_X, 0.6, 1.8]},
        "door": {"position": [20.0, eye, 3.5], "target": [6.0, 1.5, -1.0]},
        "yard": {"position": [23.5, 1.9, 11.5], "target": [12.3, 2.6, 1.5]},
        "yard_leanto": {"position": [15.0, 1.7, 13.2], "target": [7.0, 1.3, 8.9]},
        "sorting": {"position": [7.4, 2.5, 13.4], "target": [4.3, 0.8, 9.1]},
    },
    # teleport spots (feet position + look target, building frame) for set_view("hall" | "cellar")
    "spawn": {
        "hall": {"feet": [9.8, 0.0, 1.2], "target": [-6.0, 1.6, -0.6]},
        "cellar": {"feet": C2B([-9.9, 0.0, 0.0]), "target": C2B([8.0, 1.4, 0.0])},
    },
    "building": dict(building, cellarXform=CELLAR_XFORM,
                     cellarExtent=[round(CELLAR_XFORM["origin"][0] - CELLAR["W"] / 2 - 0.3, 3), round(CELLAR_XFORM["origin"][0] + CELLAR["W"] / 2 + 0.3, 3),
                                   round(CELLAR_XFORM["origin"][2] - CELLAR["L"] / 2 - 0.3, 3), CORR_END],
                     zones={"hall": [HALL["x0"], HALL["x1"], -2.6, HALL["h"], HALL["z0"], HALL["z1"]],
                            "stair": [ST["x0"], ST["x1"], ST_FLOOR - 0.5, 0.5, CORR_END - REVEAL, ST["z_top"]]},
                     collision=hall_collision(tanks) + yard_col, occluders=occluders(), stairLights=stair_lights),
    "yard": dict(yard_info, model="yard.glb", tractorModel="tractors.glb", props=ext_props,
                 tractors={"mosel": "tractor_crawler", "cote-dor": "tractor_straddle", "napa": "tractor_standard"}),
    "cellar": {"model": "cellar.glb", "barriqueModel": "barrique.glb", "fuderModel": "fuder.glb", "dims": CELLAR,
               "barriques": cellar_items["barriques"], "fuder": cellar_items["fuder"], "lights": cellar_lights,
               "doorLeaf": door_leaf, "collision": cellar_collision(door_leaf)},
    "hall": {"model": "hall.glb", "exteriorModel": "hall_ext.glb", "tankModel": "tank.glb", "tankInfo": tank_info, "dims": HALL,
             "tanks": tanks, "lights": hall_lights, "props": props},
}
with open(os.path.join(OUT, "winery.json"), "w") as fh:
    json.dump(layout, fh, indent=1)
print("layout winery:", len(cellar_items["barriques"]), "barriques,", len(cellar_items["fuder"]), "fuder,", len(tanks), "tanks")
print("DONE")
