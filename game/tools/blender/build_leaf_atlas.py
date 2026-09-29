# Variety leaf atlas for the vine leaves (vineyard.gd, shaders/leaf.gdshader). Run headless via ../sync_assets3d.sh leaves:
#   blender -b --factory-startup -P build_leaf_atlas.py -- <models_dir>
# A 2x2 atlas, one cell per Variety (0 Riesling, 1 Chardonnay, 2 Pinot Noir, 3 Cabernet Sauvignon), in leaf UV space:
# petiole at (0.5, 0), blade centre (0.5, 0.5), tip towards v = 1.
#   leaf_atlas.png  RGB = albedo multiplier (veins lighter, mottling), A = coverage (the leaf's silhouette)
#   leaf_normal.png RG  = tangent-space normal x, y (blistering, raised veins; z rebuilt in the shader), B = vein mask
# The outlines follow the ampelographic descriptions of the mature leaf in the French official variety catalogue
# (Plantgrape, INRAE / Institut Agro Montpellier; docs/science/canopy-and-yield.md §2.6). Game simplification: one
# idealised leaf per Variety; real leaves vary within a vine and between clones.
import bpy, math, os, sys
import numpy as np

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
CELL = 512

# Per Variety. The blade is a smooth union of a central disc and one tapered lobe per main vein, radiating from the
# petiole point; the smaller the disc, the deeper the sinuses between the lobes (their bottoms come out U-shaped).
#   core: disc radius; lobes: [angle from the tip, length, base width, tip width]; basal: the lobes flanking the
#   petiole sinus (their angle sets it open, closed or overlapping); holes: the overlapping upper sinuses close over
#   near the rim and leave a hole (Cabernet Sauvignon); teeth/tooth_amp/tooth_convex: serration; blister, dark, scale.
def L(a, length, w0, w1):
    return [math.radians(a), length, w0, w1]


VARIETIES = [
    # Riesling: circular, five (or seven) lobes, deep U-shaped lateral sinuses, petiole sinus with overlapping lobes,
    # medium teeth with convex or straight sides, slightly goffered blade
    dict(name="Riesling", core=0.29, lobes=[L(0, 0.55, 0.21, 0.091), L(57, 0.50, 0.20, 0.084), L(-57, 0.50, 0.20, 0.084),
         L(114, 0.40, 0.18, 0.077), L(-114, 0.40, 0.18, 0.077)], basal=L(163, 0.26, 0.14, 0.070), holes=False, petiole="overlap",
         teeth=48, tooth_amp=0.012, tooth_convex=0.6, blister=0.45, dark=1.0, scale=0.94),
    # Chardonnay: circular, entire or with five lobes, slightly open petiole sinus with often naked veins, short teeth
    # with straight sides, slightly blistered blade
    dict(name="Chardonnay", core=0.39, lobes=[L(0, 0.55, 0.22, 0.098), L(58, 0.50, 0.22, 0.098), L(-58, 0.50, 0.22, 0.098),
         L(116, 0.41, 0.20, 0.084), L(-116, 0.41, 0.20, 0.084)], basal=L(145, 0.26, 0.14, 0.070), holes=False, petiole="open",
         teeth=52, tooth_amp=0.009, tooth_convex=0.0, blister=0.35, dark=1.02, scale=1.0),
    # Pinot Noir: dark green, entire or with three or five lobes, slightly open or closed petiole sinus, short teeth,
    # twisted, strongly blistered blade
    dict(name="Pinot Noir", core=0.36, lobes=[L(0, 0.54, 0.23, 0.098), L(58, 0.49, 0.22, 0.091), L(-58, 0.49, 0.22, 0.091),
         L(117, 0.39, 0.20, 0.084), L(-117, 0.39, 0.20, 0.084)], basal=L(158, 0.26, 0.14, 0.070), holes=False, petiole="closed",
         teeth=50, tooth_amp=0.008, tooth_convex=0.5, blister=1.0, dark=0.80, scale=0.9),
    # Cabernet Sauvignon: circular, seven or nine lobes (five main ones cut deep), club- or U-shaped lateral sinuses,
    # petiole sinus with slightly overlapping lobes, medium to long teeth with convex sides, blistered blade; the
    # overlapping upper sinuses leave the "punched" holes the variety is known by
    dict(name="Cabernet Sauvignon", core=0.22, lobes=[L(0, 0.56, 0.20, 0.084), L(55, 0.51, 0.19, 0.077), L(-55, 0.51, 0.19, 0.077),
         L(112, 0.42, 0.17, 0.070), L(-112, 0.42, 0.17, 0.070)], basal=L(170, 0.28, 0.13, 0.063), holes=True, petiole="overlap",
         teeth=44, tooth_amp=0.018, tooth_convex=1.0, blister=0.7, dark=0.92, scale=1.0),
]
PETIOLE_PT = (0.0, -0.17)                        # where the veins meet: the petiole's attachment on the blade
SMOOTH = 0.05                                    # roundness of the sinus bottoms


def seg_dist(x, y, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = np.clip(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(x - (ax + t * dx), y - (ay + t * dy)), t


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def lobe_axes(p):
    out = list(p["lobes"])
    b = p["basal"]
    out += [b, [-b[0], b[1], b[2], b[3]]]
    return out


def cell(p):
    ys, xs = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    u, v = (xs + 0.5) / CELL, (ys + 0.5) / CELL
    s = p["scale"]
    x, y = (u - 0.5) / s, (v - 0.5) / s
    aa = 1.0 / (CELL * s) * 1.4
    px, py = PETIOLE_PT
    d = np.hypot(x - px, y - (py + 0.22)) - p["core"]
    tips = []
    for a, length, w0, w1 in lobe_axes(p):
        tx, ty = px + length * math.sin(a), py + length * math.cos(a)
        tips.append((tx, ty))
        dist, t = seg_dist(x, y, px, py, tx, ty)
        d = smin(d, dist - (w0 + (w1 - w0) * t), SMOOTH)
    rp = np.hypot(x - px, y - py)
    th = np.arctan2(x - px, y - py)
    # teeth along the edge, by the angle round the petiole point
    ph = (th / (2 * np.pi) * p["teeth"]) % 1.0
    tri = 1 - np.abs(2 * ph - 1)
    tooth = tri * (1 - p["tooth_convex"]) + np.sqrt(np.clip(tri, 0, 1)) * p["tooth_convex"]
    d += p["tooth_amp"] * 1.8 * (tooth - 0.5) * np.clip((rp - 0.12) / 0.14, 0, 1)   # on the rim, not near the petiole
    # Cabernet Sauvignon: the upper sinuses close over near the rim (the lobes overlap), leaving a hole
    if p["holes"]:
        for sgn in (1, -1):
            am = (p["lobes"][0][0] + p["lobes"][1][0]) / 2 * sgn
            sector = np.abs((th - am + np.pi) % (2 * np.pi) - np.pi) - math.radians(16)
            ring = np.maximum(0.33 - rp, rp - 0.50)
            d = np.minimum(d, np.maximum(sector * 0.3, ring) + p["tooth_amp"] * 1.8 * (tooth - 0.5))   # the mouth filled to the rim
        for sgn in (1, -1):
            am = (p["lobes"][0][0] + p["lobes"][1][0]) / 2 * sgn
            hx, hy = px + 0.30 * math.sin(am), py + 0.30 * math.cos(am)
            d = np.maximum(d, -(np.hypot(x - hx, y - hy) - 0.038))         # the hole left behind
    # the petiole sinus, from the rim at the base to the petiole point: open U, closed slit or overlapping
    dist, t = seg_dist(x, y, 0.0, -0.62, px, py - 0.005)
    width = {"open": 0.02 + 0.07 * (1 - t), "closed": 0.008 + 0.0 * t, "overlap": 0.002 + 0.0 * t}[p["petiole"]]
    d = np.maximum(d, -(dist - width))
    cov = np.clip(-d / aa, 0, 1)
    r = np.hypot(x, y)
    out = -d                                     # distance inside the edge (for the darker margin)
    # veins: from the petiole point to each lobe tip, secondary veins
    veins = np.zeros_like(r)

    def vein(ax, ay, bx, by, w0, gain):
        dd, t = seg_dist(x, y, ax, ay, bx, by)
        w = w0 * (1.0 - 0.65 * t)
        return np.clip(1 - dd / w, 0, 1) ** 1.4 * gain
    for (tx, ty) in tips:
        tx2, ty2 = px + (tx - px) * 0.92, py + (ty - py) * 0.92
        veins = np.maximum(veins, vein(px, py, tx2, ty2, 0.011, 1.0))
        for k in range(1, 6):
            f = k / 6.0
            qx, qy = px + (tx2 - px) * f, py + (ty2 - py) * f
            for side in (-1, 1):
                aa2 = math.atan2(tx2 - px, ty2 - py) + side * math.radians(48)
                Lk = 0.13 * (1 - 0.55 * f)
                veins = np.maximum(veins, vein(qx, qy, qx + Lk * math.sin(aa2), qy + Lk * math.cos(aa2), 0.005, 0.5))
    veins *= np.clip(out / 0.01, 0, 1)
    # blade relief: blisters between the veins and a fine grain
    # blisters: an irregular cellular bump (sum of rotated, warped waves; no single frequency, so no moiré)
    bl = np.zeros_like(x)
    for k, (f, ang) in enumerate(((34, 0.3), (41, 1.4), (47, 2.3), (29, 2.9))):
        ca, sa = math.cos(ang), math.sin(ang)
        xr, yr = x * ca - y * sa, x * sa + y * ca
        bl += np.sin(xr * f + np.sin(yr * f * 0.53 + k) * 1.7) * np.sin(yr * f * 1.07 + np.cos(xr * f * 0.47 + k) * 1.7)
    bl = np.clip(bl / 4.0 * 0.5 + 0.5, 0, 1) ** 1.3
    grain = np.clip(np.sin(x * 190 + np.sin(y * 73) * 2) * np.sin(y * 170 + np.cos(x * 61) * 2) * 0.5 + 0.5, 0, 1)
    height = p["blister"] * bl * (1 - veins) * 0.9 + grain * 0.08 - veins * 0.35
    gy, gx = np.gradient(height)
    nx = np.clip(-gx * 11, -1, 1)
    ny = np.clip(-gy * 11, -1, 1)
    # albedo multiplier: lighter veins, blister tops catch a little light, soft mottling, a slightly darker margin
    mott = 0.94 + 0.06 * np.sin(x * 13 + np.sin(y * 9) * 2) * np.sin(y * 11 + np.cos(x * 7) * 2)
    edge = np.clip(out * 14, 0, 1)
    val = (0.86 + 0.06 * bl * p["blister"]) * mott * (0.88 + 0.12 * edge) * p["dark"]
    alb_r = np.clip(val + veins * 0.34, 0, 1.3) / 1.3
    alb_g = np.clip(val + veins * 0.30, 0, 1.3) / 1.3
    alb_b = np.clip(val + veins * 0.14, 0, 1.3) / 1.3
    rgba = np.stack([alb_r, alb_g, alb_b, cov], -1)
    nrm = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, np.clip(veins * 2.5, 0, 1), np.ones_like(r)], -1)
    return rgba, nrm


def save(name, arr):
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(arr[::-1].astype(np.float32).ravel())      # Blender images start at the bottom row
    img.alpha_mode = "STRAIGHT"
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("exported", name + ".png")


alb = np.zeros((CELL * 2, CELL * 2, 4), np.float32)
nrm = np.zeros((CELL * 2, CELL * 2, 4), np.float32)
nrm[..., 0] = 0.5; nrm[..., 1] = 0.5; nrm[..., 3] = 1.0
for i, p in enumerate(VARIETIES):
    a, n = cell(p)
    cx, cy = i % 2, i // 2
    # row 0 of the image is v = 0 (the petiole) in the leaf UV: Godot samples UV (0,0) at the image's top-left
    alb[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = a
    nrm[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = n
    print("layout leaf", p["name"], "cell", i, "coverage %.2f" % float(a[..., 3].mean()))
save("leaf_atlas", alb)
save("leaf_normal", nrm)
# review image (not used by the game): each leaf in a leaf-green tint over a dark background
bg = np.array([0.08, 0.06, 0.05], np.float32)
green = np.array([0.30, 0.52, 0.16], np.float32)
prev = alb[..., :3] * green * 1.6 * alb[..., 3:4] + bg * (1 - alb[..., 3:4])
save("leaf_atlas_preview", np.concatenate([prev, np.ones_like(alb[..., :1])], -1))
print("DONE")
