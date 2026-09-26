# PROTOTYPE — finds the sun's direction in the HDRI (brightest pixel) so engines can rotate the sky to match layout.sun.
import bpy, sys, numpy as np, math
img = bpy.data.images.load(sys.argv[sys.argv.index("--") + 1])
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(px)
lum = px.reshape(h, w, 4)[..., :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
y, x = np.unravel_index(np.argmax(lum), lum.shape)   # Blender rows start at the bottom
u, v = (x + 0.5) / w, (y + 0.5) / h
print(f"HDRI_SUN u={u:.4f} v={v:.4f} elevationDeg={(v - 0.5) * 180:.2f} max={lum.max():.1f}")
