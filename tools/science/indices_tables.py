#!/usr/bin/env python3
"""Render docs/science/data/climate_indices.json as Markdown tables for the science docs.

Usage: python3 tools/science/indices_tables.py [climate|gfv|gsr]
"""
import json
import sys

d = json.load(open("docs/science/data/climate_indices.json"))
which = sys.argv[1] if len(sys.argv) > 1 else "climate"


def rng(x, digits=0):
    if not x:
        return "—"
    f = f"{{:.{digits}f}}"
    return f"{f.format(x['mean'])} ({f.format(x['min'])}–{f.format(x['max'])})"


if which == "climate":
    print("| Site (grid-cell elevation) | Period | Winkler GDD₁₀ Apr–Oct | Huglin HI | Cool night index (Sep Tmin, °C) | GST Apr–Oct (°C) | DTR Apr–Oct (°C) | Continentality (°C) | Rain Apr–Oct (mm) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for s, v in d["sites"].items():
        for per in ("1981-2000", "2001-2020", "1991-2020"):
            r = v[per]
            print(f"| {s} ({v['grid_cell_elevation_m']:.0f} m) | {per} | {rng(r['winkler_gdd10_apr_oct'])} | {rng(r['huglin_hi'])} | "
                  f"{rng(r['cool_night_index_sep_tmin'], 1)} | {rng(r['gst_apr_oct_mean'], 1)} | {rng(r['dtr_apr_oct'], 1)} | "
                  f"{rng(r['continentality_warmest_minus_coldest_month'], 1)} | {rng(r['rain_apr_oct_mm'])} |")
elif which == "gfv":
    print("| Site | Period | Variety | GFV flowering (mean date, DOY range) | GFV véraison (mean date, DOY range) | Years without véraison |")
    print("|---|---|---|---|---|---|")
    for s, v in d["sites"].items():
        for per in ("1981-2000", "2001-2020"):
            for var, g in v[per]["gfv"].items():
                f, ve = g["flowering_doy"], g["veraison_doy"]
                fs = f"{f['mean_date']} ({f['min']:.0f}–{f['max']:.0f})" if f else "—"
                vs = f"{ve['mean_date']} ({ve['min']:.0f}–{ve['max']:.0f})" if ve else "—"
                print(f"| {s} | {per} | {var} | {fs} | {vs} | {g['years_without_veraison']} |")
elif which == "gsr":
    print("| Site | Period | Thermal sum (Tmean > 0 °C from 1 Apr) at 15 Sep | at 1 Oct | at 15 Oct |")
    print("|---|---|---|---|---|")
    for s, v in d["sites"].items():
        for per in ("1981-2000", "2001-2020"):
            g = v[per]["gsr_thermal_sum_from_1_apr"]
            print(f"| {s} | {per} | {rng(g['15 Sep'])} | {rng(g['1 Oct'])} | {rng(g['15 Oct'])} |")
