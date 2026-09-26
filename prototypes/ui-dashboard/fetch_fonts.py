#!/usr/bin/env python3
# PROTOTYPE — downloads the open-licence (SIL OFL 1.1) fonts used by the UI prototype from the Google Fonts repository.
import os, urllib.request
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
FILES = {
    "inter/Inter%5Bopsz,wght%5D.ttf": "Inter-Variable.ttf",
    "inter/OFL.txt": "OFL-Inter.txt",
    "barlowsemicondensed/BarlowSemiCondensed-Regular.ttf": "BarlowSemiCondensed-Regular.ttf",
    "barlowsemicondensed/BarlowSemiCondensed-Medium.ttf": "BarlowSemiCondensed-Medium.ttf",
    "barlowsemicondensed/BarlowSemiCondensed-SemiBold.ttf": "BarlowSemiCondensed-SemiBold.ttf",
    "barlowsemicondensed/OFL.txt": "OFL-Barlow.txt",
}
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
os.makedirs(out, exist_ok=True)
for src, dst in FILES.items():
    path = os.path.join(out, dst)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        continue
    req = urllib.request.Request(BASE + src, headers={"User-Agent": "terroir-prototype"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f:
        f.write(r.read())
    print("ok", dst, os.path.getsize(path))
