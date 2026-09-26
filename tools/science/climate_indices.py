#!/usr/bin/env python3
"""Viticultural climate indices and GFV phenology dates from NASA POWER daily data (MERRA-2 based).

Produces the calibration anchors in docs/science/weather-and-climate.md and docs/science/phenology.md.
Usage:  python3 tools/science/climate_indices.py > docs/science/data/climate_indices.json
Data:   NASA POWER Daily API (https://power.larc.nasa.gov), MERRA-2 native resolution (~0.5° × 0.625°).
        Grid-cell values with the grid cell's own elevation — not station data, not Block-level values.
Raw downloads are cached in the system temp dir so reruns don't re-download.
"""
import datetime as dt
import json
import os
import statistics as st
import sys
import tempfile
import time
import urllib.error
import urllib.request

SITES = {
    "Bernkastel (Mosel)": (49.916, 7.07),
    "Beaune (Côte d'Or)": (47.025, 4.84),
    "Oakville (Napa)": (38.437, -122.40),
}
START, END = 1981, 2020
PERIODS = {"1981-2000": (1981, 2000), "2001-2020": (2001, 2020), "1991-2020": (1991, 2020)}

# Grapevine Flowering Véraison model (Parker et al. 2011, 2013): daily Tmean above 0 °C summed from DOY 60 (NH).
GFV_T0_DOY, GFV_TB = 60, 0.0
GFV_FSTAR = {  # Parker et al. 2013, Tables 1 and 2
    "Chardonnay": (1217, 2547),
    "Pinot noir": (1219, 2511),
    "Riesling": (1249, 2590),
    "Cabernet Sauvignon": (1299, 2689),
}
# GSR structure (Parker et al. 2020): Tmean above 0 °C from DOY 91. Thermal sums reported at fixed dates for calibration.
GSR_T0_DOY = 91
GSR_REPORT_DATES = {"15 Sep": (9, 15), "1 Oct": (10, 1), "15 Oct": (10, 15)}


def fetch(lat, lon):
    cache = os.path.join(tempfile.gettempdir(), f"power_{lat}_{lon}_{START}_{END}.json")
    if os.path.exists(cache):
        with open(cache) as fh:
            return json.load(fh)
    url = ("https://power.larc.nasa.gov/api/temporal/daily/point"
           f"?parameters=T2M,T2M_MAX,T2M_MIN,PRECTOTCORR&community=AG&longitude={lon}&latitude={lat}"
           f"&start={START}0101&end={END}1231&format=JSON")
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=300) as r:
                data = json.load(r)
            with open(cache, "w") as fh:
                json.dump(data, fh)
            return data
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
            if attempt == 5:
                raise
            time.sleep(20 * (attempt + 1))


def k_huglin(lat):
    """Day-length coefficient: 1.00 below 40°, 1.02 at 40° rising linearly to 1.06 at 50°."""
    a = abs(lat)
    if a < 40:
        return 1.0
    if a >= 50:
        return 1.06
    return 1.02 + (a - 40) / 10 * 0.04


def summarise(values):
    values = [v for v in values if v is not None]
    if not values:
        return None
    m = st.mean(values)
    fmt = "{:.0f}" if abs(m) >= 100 else "{:.1f}"
    return {"mean": float(fmt.format(m)), "min": float(fmt.format(min(values))),
            "max": float(fmt.format(max(values))), "n": len(values)}


def doy_to_date(doy):
    return (dt.date(2001, 1, 1) + dt.timedelta(days=round(doy) - 1)).strftime("%d %b")


def site_results(lat, lon):
    raw = fetch(lat, lon)
    p = raw["properties"]["parameter"]
    fill = raw["header"].get("fill_value", -999.0)
    elev = raw["geometry"]["coordinates"][2]
    years = {}
    for key in sorted(p["T2M"]):
        day = dt.datetime.strptime(key, "%Y%m%d").date()
        tm, tx, tn, pr = p["T2M"][key], p["T2M_MAX"][key], p["T2M_MIN"][key], p["PRECTOTCORR"][key]
        if fill in (tm, tx, tn):
            continue
        y = years.setdefault(day.year, {"wi": 0.0, "hi": 0.0, "cni": [], "gst": [], "dtr": [], "mon": {}, "p": 0.0,
                                        "gfv": 0.0, "gsr": 0.0, "gsr_at": {},
                                        "stage": {v: [None, None] for v in GFV_FSTAR}})
        doy = day.timetuple().tm_yday
        if 4 <= day.month <= 10:
            y["wi"] += max(0.0, tm - 10)
            y["gst"].append(tm)
            y["dtr"].append(tx - tn)
            y["p"] += max(pr, 0.0)
        if 4 <= day.month <= 9:
            y["hi"] += max(0.0, ((tm - 10) + (tx - 10)) / 2)
        if day.month == 9:
            y["cni"].append(tn)
        y["mon"].setdefault(day.month, []).append(tm)
        if doy >= GFV_T0_DOY:
            y["gfv"] += max(0.0, tm - GFV_TB)
            for v, (f_flo, f_ver) in GFV_FSTAR.items():
                s = y["stage"][v]
                if s[0] is None and y["gfv"] >= f_flo:
                    s[0] = doy
                if s[1] is None and y["gfv"] >= f_ver:
                    s[1] = doy
        if doy >= GSR_T0_DOY:
            y["gsr"] += max(0.0, tm)
        for label, (mo, da) in GSR_REPORT_DATES.items():
            if (day.month, day.day) == (mo, da):
                y["gsr_at"][label] = y["gsr"]
    out = {"grid_cell_elevation_m": elev}
    for label, (a, b) in PERIODS.items():
        ys = [years[yr] for yr in range(a, b + 1) if yr in years]
        res = {
            "winkler_gdd10_apr_oct": summarise([y["wi"] for y in ys]),
            "huglin_hi": summarise([y["hi"] * k_huglin(lat) for y in ys]),
            "cool_night_index_sep_tmin": summarise([st.mean(y["cni"]) for y in ys]),
            "gst_apr_oct_mean": summarise([st.mean(y["gst"]) for y in ys]),
            "dtr_apr_oct": summarise([st.mean(y["dtr"]) for y in ys]),
            "continentality_warmest_minus_coldest_month": summarise(
                [max(st.mean(v) for v in y["mon"].values()) - min(st.mean(v) for v in y["mon"].values()) for y in ys]),
            "rain_apr_oct_mm": summarise([y["p"] for y in ys]),
            "gsr_thermal_sum_from_1_apr": {lab: summarise([y["gsr_at"].get(lab) for y in ys]) for lab in GSR_REPORT_DATES},
            "gfv": {},
        }
        for v in GFV_FSTAR:
            flo = summarise([y["stage"][v][0] for y in ys])
            ver = summarise([y["stage"][v][1] for y in ys])
            res["gfv"][v] = {
                "flowering_doy": {**flo, "mean_date": doy_to_date(flo["mean"])} if flo else None,
                "veraison_doy": {**ver, "mean_date": doy_to_date(ver["mean"])} if ver else None,
                "years_without_veraison": sum(1 for y in ys if y["stage"][v][1] is None),
            }
        out[label] = res
    return out


if __name__ == "__main__":
    result = {"source": "NASA POWER Daily API (MERRA-2), grid-cell values at the grid cell's elevation",
              "k_huglin_rule": "1.00 below 40°, 1.02 at 40° rising linearly to 1.06 at 50°",
              "gfv_fstar": GFV_FSTAR, "sites": {}}
    for name, (lat, lon) in SITES.items():
        result["sites"][name] = {"lat": lat, "lon": lon, "k_huglin": round(k_huglin(lat), 3), **site_results(lat, lon)}
    json.dump(result, sys.stdout, indent=1, ensure_ascii=False)
