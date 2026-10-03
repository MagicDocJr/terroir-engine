"""Visual change report: compare game/shots/*.png with the approved baselines in game/shots_baseline/.

Writes game/shots/diff/report.html with only the screens that changed (before, after, and the changed pixels in red),
plus the new and missing screens, and prints a one-line summary. `approve` copies the current shots over the baselines.
Usage: uv run --with pillow tools/shots_diff.py [diff|approve] [--threshold 0.003]
"""
import html, shutil, sys
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
SHOTS, BASE, OUT = ROOT / "game/shots", ROOT / "game/shots_baseline", ROOT / "game/shots/diff"


def approve() -> None:
    BASE.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in sorted(SHOTS.glob("*.png")):
        shutil.copy2(p, BASE / p.name); n += 1
    print(f"SHOTS approved {n} screens as the baseline")


def changed_fraction(a: Image.Image, b: Image.Image) -> tuple[float, Image.Image]:
    if a.size != b.size:
        b = b.resize(a.size)
    d = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
    mask = d.point(lambda v: 255 if v > 40 else 0)   # ignore anti-aliasing shimmer
    frac = mask.histogram()[255] / (a.size[0] * a.size[1])
    overlay = b.convert("RGB").copy()
    red = Image.new("RGB", a.size, (255, 40, 40))
    overlay.paste(red, (0, 0), mask)
    return frac, overlay


def diff(threshold: float) -> int:
    if not BASE.exists():
        print("SHOTS no baseline yet: run `approve` first"); return 0
    OUT.mkdir(parents=True, exist_ok=True)
    cur = {p.name: p for p in SHOTS.glob("*.png")}
    base = {p.name: p for p in BASE.glob("*.png")}
    rows, changed = [], []
    for name in sorted(cur.keys() & base.keys()):
        with Image.open(base[name]) as a, Image.open(cur[name]) as b:
            small_a, small_b = a.reduce(2), b.reduce(2)        # half size: faster, still sharp enough for a report
            frac, overlay = changed_fraction(small_a, small_b)
            if frac >= threshold:
                stem = name[:-4]
                small_a.save(OUT / f"{stem}.before.png"); small_b.save(OUT / f"{stem}.after.png"); overlay.save(OUT / f"{stem}.diff.png")
                changed.append(name)
                rows.append(f"<h2>{html.escape(name)} <small>{frac * 100:.1f} % of pixels changed</small></h2>"
                            f"<div class=row><figure><img src='{stem}.before.png'><figcaption>before</figcaption></figure>"
                            f"<figure><img src='{stem}.after.png'><figcaption>after</figcaption></figure>"
                            f"<figure><img src='{stem}.diff.png'><figcaption>changed pixels</figcaption></figure></div>")
    new, missing = sorted(cur.keys() - base.keys()), sorted(base.keys() - cur.keys())
    for name in new:
        shutil.copy2(cur[name], OUT / name)
        rows.append(f"<h2>{html.escape(name)} <small>new screen</small></h2><img class=one src='{html.escape(name)}'>")
    if missing:
        rows.append("<h2>Missing screens</h2><p>" + ", ".join(html.escape(m) for m in missing) + "</p>")
    total = len(cur.keys() & base.keys())
    head = (f"<h1>Visual change report</h1><p>{len(changed)} of {total} screens changed (≥ {threshold * 100:.1f} % of pixels), "
            f"{len(new)} new, {len(missing)} missing. Baseline: game/shots_baseline/ (approve with tools/shots_diff.py approve).</p>")
    css = ("body{background:#11161b;color:#e8e2d4;font-family:sans-serif;margin:24px} h2{margin-top:32px;font-size:18px} "
           "small{color:#8a96a3;font-weight:normal} .row{display:flex;gap:12px} figure{margin:0;flex:1} img{width:100%;border:1px solid #2a3540} "
           "img.one{max-width:960px} figcaption{color:#8a96a3;font-size:13px}")
    (OUT / "report.html").write_text(f"<!doctype html><meta charset=utf-8><title>Visual change report</title><style>{css}</style>{head}{''.join(rows)}", encoding="utf-8")
    print(f"SHOTS {len(changed)}/{total} changed, {len(new)} new, {len(missing)} missing: {', '.join(changed[:12])}{' …' if len(changed) > 12 else ''}")
    print(f"SHOTS report: {OUT / 'report.html'}")
    return len(changed)


if __name__ == "__main__":
    args = sys.argv[1:]
    th = float(args[args.index("--threshold") + 1]) if "--threshold" in args else 0.003
    if args and args[0] == "approve": approve()
    else: diff(th)
