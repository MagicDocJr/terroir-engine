#!/usr/bin/env python3
"""Download Historical weather (daily) for each Region from the Open-Meteo Historical Weather API.

Model: ``era5_seamless`` = ERA5-Land (0.1°, ~9 km) where it provides a variable (temperatures, humidity,
dew point), gap-filled with ERA5 (0.25°, ~28 km) for the rest (precipitation, wind, radiation, ET₀).
Plain ``era5_land`` returns nulls for precipitation/wind/radiation/ET₀ on this API, so it cannot be used alone.

Standard library only.  Usage:  python3 tools/weather/fetch_weather.py [--start 1990-01-01] [--end 2025-12-31]
Output: data/weather/<region>.csv.gz and data/weather/meta.json
"""
import argparse, csv, gzip, io, json, os, sys, time, urllib.error, urllib.parse, urllib.request
from datetime import date, datetime, timezone

API = "https://archive-api.open-meteo.com/v1/archive"
MODEL = "era5_seamless"

# One representative coordinate per Region (spec §4.2). Blocks adjust these for elevation, slope and aspect.
REGIONS = {
    "mosel":    {"name": "Mosel (Middle Mosel, near Bernkastel-Kues)", "lat": 49.92, "lon": 7.07},
    "cote_dor": {"name": "Côte d'Or (near Beaune)",                   "lat": 47.03, "lon": 4.83},
    "napa":     {"name": "Napa Valley (Oakville)",                     "lat": 38.43, "lon": -122.40},
}

# API variable → CSV column (kept short; units in meta.json)
VARIABLES = [
    ("temperature_2m_min", "tmin"),
    ("temperature_2m_max", "tmax"),
    ("temperature_2m_mean", "tmean"),
    ("precipitation_sum", "precip"),
    ("relative_humidity_2m_mean", "rh_mean"),
    ("relative_humidity_2m_min", "rh_min"),
    ("relative_humidity_2m_max", "rh_max"),
    ("dew_point_2m_mean", "dewpoint"),
    ("wind_speed_10m_mean", "wind_mean"),
    ("wind_speed_10m_max", "wind_max"),
    ("shortwave_radiation_sum", "sw_rad"),
    ("et0_fao_evapotranspiration", "et0"),
]
UNITS = {"tmin": "°C", "tmax": "°C", "tmean": "°C", "precip": "mm", "rh_mean": "%", "rh_min": "%", "rh_max": "%",
         "dewpoint": "°C", "wind_mean": "km/h", "wind_max": "km/h", "sw_rad": "MJ/m²", "et0": "mm"}

CHUNK_YEARS = 6          # keeps each response modest
PAUSE_S = 3.0            # between requests (free tier: be polite)
TIMEOUT_S = 120


def fmt(v):
    if v is None: return ""
    if isinstance(v, float):
        out = f"{v:.1f}"
        return "0.0" if out == "-0.0" else out
    return v


def fetch(lat, lon, start, end, attempts=6):
    q = urllib.parse.urlencode({
        "latitude": lat, "longitude": lon, "start_date": start, "end_date": end,
        "daily": ",".join(v for v, _ in VARIABLES), "timezone": "auto", "models": MODEL,
    })
    delay = 10.0
    for i in range(attempts):
        try:
            req = urllib.request.Request(f"{API}?{q}", headers={"User-Agent": "terroir-engine/0.1 (private research)"})
            with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r:
                return json.load(r)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            code = getattr(e, "code", None)
            print(f"  attempt {i + 1} failed ({code or e}); retrying in {delay:.0f} s", file=sys.stderr)
            time.sleep(delay)
            delay = min(delay * 2, 300)
    raise RuntimeError(f"giving up on {start}..{end}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", default="1990-01-01")
    ap.add_argument("--end", default="2025-12-31")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "data", "weather"))
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    y0, y1 = int(a.start[:4]), int(a.end[:4])
    meta = {"source": API, "model": MODEL, "fetched": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "start": a.start, "end": a.end, "units": UNITS, "timezone": "local (Open-Meteo timezone=auto)", "regions": {}}
    for key, reg in REGIONS.items():
        rows = {}
        grid = None
        for ys in range(y0, y1 + 1, CHUNK_YEARS):
            ye = min(ys + CHUNK_YEARS - 1, y1)
            s = a.start if ys == y0 else f"{ys}-01-01"
            e = a.end if ye == y1 else f"{ye}-12-31"
            print(f"{key}: {s} .. {e}")
            d = fetch(reg["lat"], reg["lon"], s, e)
            grid = {"lat": d.get("latitude"), "lon": d.get("longitude"), "elevation_m": d.get("elevation"),
                    "timezone": d.get("timezone")}
            daily = d["daily"]
            for i, t in enumerate(daily["time"]):
                rows[t] = [daily[v][i] for v, _ in VARIABLES]
            time.sleep(PAUSE_S)
        missing = {col: sum(1 for r in rows.values() if r[j] is None) for j, (_, col) in enumerate(VARIABLES)}
        path = os.path.join(out, f"{key}.csv.gz")
        buf = io.StringIO()
        w = csv.writer(buf, lineterminator="\n")
        w.writerow(["date"] + [c for _, c in VARIABLES])
        for t in sorted(rows):
            w.writerow([t] + [fmt(v) for v in rows[t]])
        with gzip.open(path, "wt", encoding="utf-8", newline="", compresslevel=9) as fh:
            fh.write(buf.getvalue())
        meta["regions"][key] = {**reg, "grid": grid, "days": len(rows), "missing_values": missing,
                                "file": os.path.basename(path)}
        print(f"  wrote {path} ({len(rows)} days, {os.path.getsize(path) / 1024:.0f} KiB); missing: {missing}")
    with open(os.path.join(out, "meta.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
