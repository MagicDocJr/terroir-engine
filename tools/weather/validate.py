#!/usr/bin/env python3
"""Per-Region, per-year viticultural climate indices from data/weather/*.csv.gz (standard library only).

Indices (all Regions are northern hemisphere):
  winkler   Growing degree-days, base 10 °C, 1 Apr–31 Oct, daily mean = (Tmax+Tmin)/2   [Amerine & Winkler 1944]
  huglin    Heliothermal index, 1 Apr–30 Sep: Σ max(0, ((Tmean−10)+(Tmax−10))/2) × k(latitude)   [Huglin 1978]
  gs_rain   Growing-season rainfall, 1 Apr–31 Oct (mm)
  harvest_rain  Rainfall 1 Sep–31 Oct (mm)
  last_frost / first_frost   Last day before 1 Jul / first day after 1 Jul with Tmin ≤ 0 °C
  frost_am  Nights with Tmin ≤ 0 °C in April–May;  hard_frost_am: Tmin ≤ −2 °C in April–May
  hot30 / hot35   Days with Tmax ≥ 30 °C / ≥ 35 °C (whole year)
  jja_tmax  Mean daily Tmax, June–August

Usage: python3 tools/weather/validate.py [--json out.json]   → prints Markdown tables to stdout.
"""
import argparse, csv, gzip, json, os
from collections import defaultdict
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "data", "weather"))
REGIONS = {"mosel": "Mosel", "cote_dor": "Côte d'Or", "napa": "Napa (Oakville)"}


def huglin_k(lat):
    """Day-length coefficient (Huglin 1978; as tabulated by Tonietto & Carbonneau 2004): 1.00 below 40°, rising to 1.06 at 48–50°."""
    lat = abs(lat)
    for lo, k in ((48, 1.06), (46, 1.05), (44, 1.04), (42, 1.03), (40, 1.02)):
        if lat >= lo:
            return k
    return 1.00


def winkler_region(gdd):
    """Winkler regions in °C·days (Amerine & Winkler 1944; °F bands 2500/3000/3500/4000 converted)."""
    for limit, name in ((1389, "I"), (1667, "II"), (1944, "III"), (2222, "IV")):
        if gdd <= limit:
            return name
    return "V"


def huglin_class(hi):
    """Tonietto & Carbonneau (2004) HI classes."""
    for limit, name in ((1500, "very cool"), (1800, "cool"), (2100, "temperate"), (2400, "warm temperate"), (3000, "warm")):
        if hi <= limit:
            return name
    return "very warm"


def load(region):
    with gzip.open(os.path.join(DATA, f"{region}.csv.gz"), "rt", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            yield date.fromisoformat(r["date"]), {k: (float(v) if v != "" else None) for k, v in r.items() if k != "date"}


def indices(region, lat):
    k = huglin_k(lat)
    yrs = defaultdict(lambda: {"winkler": 0.0, "huglin": 0.0, "gs_rain": 0.0, "harvest_rain": 0.0, "last_frost": None,
                               "first_frost": None, "frost_am": 0, "hard_frost_am": 0, "hot30": 0, "hot35": 0,
                               "_jja": [], "max_tmax": -99.0, "max_tmax_date": None, "min_tmin_am": 99.0, "min_tmin_am_date": None})
    for d, v in load(region):
        y = yrs[d.year]
        tmax, tmin = v["tmax"], v["tmin"]
        tm = (tmax + tmin) / 2
        m = d.month
        if 4 <= m <= 10:
            y["winkler"] += max(0.0, tm - 10)
            y["gs_rain"] += v["precip"] or 0.0
        if 4 <= m <= 9:
            y["huglin"] += max(0.0, ((tm - 10) + (tmax - 10)) / 2) * k
        if m in (9, 10):
            y["harvest_rain"] += v["precip"] or 0.0
        if tmin <= 0:
            if m < 7:
                y["last_frost"] = d
            elif y["first_frost"] is None:
                y["first_frost"] = d
        if m in (4, 5):
            y["frost_am"] += tmin <= 0
            y["hard_frost_am"] += tmin <= -2
            if tmin < y["min_tmin_am"]:
                y["min_tmin_am"], y["min_tmin_am_date"] = tmin, d
        y["hot30"] += tmax >= 30
        y["hot35"] += tmax >= 35
        if m in (6, 7, 8):
            y["_jja"].append(tmax)
        if tmax > y["max_tmax"]:
            y["max_tmax"], y["max_tmax_date"] = tmax, d
    out = {}
    for yr, y in sorted(yrs.items()):
        y["jja_tmax"] = sum(y["_jja"]) / len(y["_jja"]) if y["_jja"] else None
        del y["_jja"]
        for key in ("last_frost", "first_frost", "max_tmax_date", "min_tmin_am_date"):
            if y[key] is not None:
                y[key] = y[key].isoformat()
        out[yr] = {kk: (round(vv, 1) if isinstance(vv, float) else vv) for kk, vv in y.items()}
    return out


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    a = ap.parse_args()
    meta = json.load(open(os.path.join(DATA, "meta.json"), encoding="utf-8"))
    result = {}
    for reg, label in REGIONS.items():
        lat = meta["regions"][reg]["lat"]
        result[reg] = indices(reg, lat)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=1)
    # Markdown: 1991–2020 normals + per-year table
    print("## Normals, 1991–2020\n")
    print("| Region | Winkler GDD (°C) | Winkler region | Huglin | Huglin class | Apr–Oct rain (mm) | Apr–May frost nights | Days ≥ 30 °C | Days ≥ 35 °C |")
    print("|---|---|---|---|---|---|---|---|---|")
    for reg, label in REGIONS.items():
        ys = [v for yr, v in result[reg].items() if 1991 <= yr <= 2020]
        w, h = mean([y["winkler"] for y in ys]), mean([y["huglin"] for y in ys])
        print(f"| {label} | {w:.0f} | {winkler_region(w)} | {h:.0f} | {huglin_class(h)} | {mean([y['gs_rain'] for y in ys]):.0f} | "
              f"{mean([y['frost_am'] for y in ys]):.1f} | {mean([y['hot30'] for y in ys]):.1f} | {mean([y['hot35'] for y in ys]):.1f} |")
    for reg, label in REGIONS.items():
        print(f"\n## {label}: every year\n")
        print("| Year | Winkler | Huglin | Apr–Oct rain | Sep–Oct rain | Last spring frost | Apr–May min Tmin | Frost nights Apr–May | ≥30 °C | ≥35 °C | Max Tmax (date) | Jun–Aug mean Tmax |")
        print("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for yr, y in result[reg].items():
            print(f"| {yr} | {y['winkler']:.0f} | {y['huglin']:.0f} | {y['gs_rain']:.0f} | {y['harvest_rain']:.0f} | {y['last_frost'] or '—'} | "
                  f"{y['min_tmin_am']:.1f} ({y['min_tmin_am_date'][5:]}) | {y['frost_am']} | {y['hot30']} | {y['hot35']} | "
                  f"{y['max_tmax']:.1f} ({y['max_tmax_date'][5:]}) | {y['jja_tmax']:.1f} |")


if __name__ == "__main__":
    main()
