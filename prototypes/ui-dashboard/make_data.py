#!/usr/bin/env python3
# PROTOTYPE — generates data/fake_data.json for the UI prototype.
# Fake but plausible Mosel values (not simulated, not yet checked against docs/science). Same world as the
# engine-demo dashboard_data.json, moved forward to 20 Oct 2025 so every screen has content:
# Blocks A–D are harvested and fermenting, Block E is still hanging.
import json, math, os, random, datetime as dt

R = random.Random(2025)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "fake_data.json")
TODAY = dt.date(2025, 10, 20)

def d(s): return dt.date.fromisoformat(s)
def fmt(day): return f"{day.day} {day.strftime('%b')}"

# ------------------------------------------------------------------ blocks + ripeness
weeks = [d("2025-08-18") + dt.timedelta(days=7 * i) for i in range(10)]          # 18 Aug … 20 Oct
def ramp(v0, v1, n, curve=0.8, nd=1): return [round(v0 + (v1 - v0) * (i / (n - 1)) ** curve, nd) for i in range(n)]

BLOCKS = [
    dict(id="A", name="Steillage Süd", area=0.40, soil="Blue Devonian slate, shallow", slope=35, aspect="S", elevation=165,
         variety="Riesling", rootstock="SO4", clone="Gm 198-30", awc=70, health=0.93, water=-0.95, downy=12, powdery=8, botrytis=18,
         yieldKgHa=6400, harvested="2025-10-08", oe_end=91, ta_end=8.6, ph_end=3.08, target=("Spätlese trocken", 88),
         horizons=[(0, 25, "Ah", "Stony silt loam, humic", 55, "#4a4038"), (25, 70, "Cv", "Weathered slate scree", 80, "#3e4651"),
                   (70, 180, "R", "Fissured Devonian slate", 97, "#2e353e")], ph_soil=6.1),
    dict(id="B", name="Mittelhang", area=0.35, soil="Slate with loess patches", slope=28, aspect="SSW", elevation=140,
         variety="Riesling", rootstock="5BB", clone="Gm 239-17", awc=95, health=0.88, water=-0.78, downy=15, powdery=7, botrytis=24,
         yieldKgHa=7900, harvested="2025-10-03", oe_end=84, ta_end=9.3, ph_end=3.02, target=("Kabinett feinherb", 80),
         horizons=[(0, 30, "Ah", "Loamy silt with slate chips", 35, "#57493c"), (30, 60, "Bv", "Loess loam, slate fragments", 30, "#6b5a44"),
                   (60, 170, "Cv", "Weathered slate", 85, "#3e4651")], ph_soil=6.4),
    dict(id="C", name="Hangfuß", area=0.25, soil="Colluvial slate loam, deeper", slope=18, aspect="S", elevation=118,
         variety="Riesling", rootstock="SO4", clone="Gm 198-30", awc=140, health=0.82, water=-0.52, downy=20, powdery=6, botrytis=38,
         yieldKgHa=9400, harvested="2025-09-27", oe_end=77, ta_end=10.4, ph_end=2.96, target=("Kabinett", 74),
         horizons=[(0, 40, "Ap", "Colluvial loam, slate chips", 25, "#5a4a3b"), (40, 110, "M", "Colluvium, silty clay loam", 20, "#6a5641"),
                   (110, 180, "Cv", "Weathered slate", 80, "#3e4651")], ph_soil=6.6),
    dict(id="D", name="Kuppe", area=0.20, soil="Red slate, very stony", slope=31, aspect="SW", elevation=182,
         variety="Spätburgunder", rootstock="3309C", clone="Mariafeld", awc=60, health=0.90, water=-1.05, downy=10, powdery=14, botrytis=16,
         yieldKgHa=5600, harvested="2025-10-10", oe_end=97, ta_end=7.1, ph_end=3.35, target=("Spätburgunder trocken", 95),
         horizons=[(0, 20, "Ah", "Red stony loam", 65, "#6b3f35"), (20, 60, "Cv", "Red slate scree", 85, "#5a3530"),
                   (60, 180, "R", "Red slate bedrock", 98, "#44292a")], ph_soil=6.0),
    dict(id="E", name="Waldrand", area=0.20, soil="Slate under the forest edge, cool", slope=24, aspect="SE", elevation=205,
         variety="Riesling", rootstock="101-14", clone="Gm 239-17", awc=85, health=0.86, water=-0.60, downy=18, powdery=11, botrytis=32,
         yieldKgHa=6900, harvested=None, oe_end=81, ta_end=9.8, ph_end=3.00, target=("Auslese", 83),
         horizons=[(0, 35, "Ah", "Humic slate loam, leaf litter", 40, "#473d33"), (35, 80, "Cv", "Weathered slate", 80, "#3e4651"),
                   (80, 180, "R", "Fissured slate", 96, "#2e353e")], ph_soil=5.8),
]
blocks = []
for b in BLOCKS:
    n_weeks = len(weeks)
    if b["harvested"]:
        hd = d(b["harvested"])
        last = max(i for i, w in enumerate(weeks) if w <= hd)
    else:
        last = n_weeks - 1
    oe0 = {"A": 52, "B": 49, "C": 46, "D": 55, "E": 44}[b["id"]]
    ta0 = {"A": 19.5, "B": 20.4, "C": 21.2, "D": 17.1, "E": 21.8}[b["id"]]
    ph0 = {"A": 2.78, "B": 2.76, "C": 2.74, "D": 2.95, "E": 2.72}[b["id"]]
    oe = ramp(oe0, b["oe_end"], last + 1); ta = ramp(ta0, b["ta_end"], last + 1, 0.7); ph = ramp(ph0, b["ph_end"], last + 1, 1.0, 2)
    blocks.append({
        "id": b["id"], "name": b["name"], "area": b["area"], "soil": b["soil"], "slope": b["slope"], "aspect": b["aspect"],
        "elevation": b["elevation"], "variety": b["variety"], "rootstock": b["rootstock"], "clone": b["clone"], "training": "Einzelpfahl",
        "density": 7800, "planted": 2022, "leaf": 4, "awc": b["awc"], "health": b["health"], "water": b["water"],
        "downy": b["downy"], "powdery": b["powdery"], "botrytis": b["botrytis"], "yieldKgHa": b["yieldKgHa"],
        "harvested": b["harvested"], "oe": oe, "ta": ta, "ph": ph, "target": {"style": b["target"][0], "oe": b["target"][1]},
        "soilProfile": {"phTopsoil": b["ph_soil"], "caco3": 0, "awcMm": b["awc"], "rootDepthCm": 160 if b["awc"] < 100 else 120,
                        "horizons": [{"from": h[0], "to": h[1], "name": h[2], "texture": h[3], "stones": h[4], "color": h[5]} for h in b["horizons"]]},
    })

# ------------------------------------------------------------------ weather (season to date + normals, disease risk, forecast)
season_start = d("2025-04-01")
days = (TODAY - season_start).days + 1
normal_tmean = lambda doy: 9.8 + 8.3 * math.sin((doy - 105) / 365 * 2 * math.pi)   # Middle Mosel, °C, rough 1991–2020 shape
gdd, gdd_n, weekly = 0.0, 0.0, []
for i in range(days):
    day = season_start + dt.timedelta(days=i)
    doy = day.timetuple().tm_yday
    tn = normal_tmean(doy)
    anomaly = 1.1 + 1.6 * math.sin(i / 23.0) + R.uniform(-2.2, 2.2)          # a warm 2025 with spells
    t = tn + anomaly
    gdd += max(0.0, t - 10.0); gdd_n += max(0.0, tn - 10.0)
    if day.weekday() == 0 or i == days - 1:
        weekly.append({"date": fmt(day), "tmean": round(t, 1), "tmeanNormal": round(tn, 1), "gdd": round(gdd), "gddNormal": round(gdd_n)})
months = ["Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct"]
rain = [48, 51, 38, 44, 36, 71, 29]; rain_n = [45, 62, 65, 70, 62, 55, 58]            # Oct = to date (20 days) vs full-month normal
risk_raw = []
for i in range(60):
    day = TODAY - dt.timedelta(days=59 - i)
    wet = 1.0 if dt.date(2025, 9, 29) <= day <= dt.date(2025, 10, 1) else (0.5 if day.day % 9 in (0, 1) else 0.0)
    risk_raw.append({"date": fmt(day),
                 "downy": round(min(100, 8 + 45 * wet + 6 * math.sin(i / 5) + R.uniform(0, 5))),
                 "powdery": round(max(2, 26 - 0.35 * i + 5 * math.sin(i / 4) + R.uniform(0, 4))),
                 "botrytis": round(min(100, 10 + 0.45 * i + 30 * wet + R.uniform(0, 6)))})
forecast = [
    {"day": "Tue 21", "icon": "fog", "tmin": 6, "tmax": 15, "rain": 0.0, "rh": 88, "note": "Morning fog until 11:00"},
    {"day": "Wed 22", "icon": "fog", "tmin": 7, "tmax": 16, "rain": 0.0, "rh": 86, "note": "Morning fog"},
    {"day": "Thu 23", "icon": "sun", "tmin": 5, "tmax": 17, "rain": 0.0, "rh": 72, "note": ""},
    {"day": "Fri 24", "icon": "cloud", "tmin": 8, "tmax": 15, "rain": 0.6, "rh": 80, "note": ""},
    {"day": "Sat 25", "icon": "rain", "tmin": 9, "tmax": 13, "rain": 11.4, "rh": 94, "note": "Front arrives in the afternoon"},
    {"day": "Sun 26", "icon": "rain", "tmin": 8, "tmax": 12, "rain": 6.2, "rh": 93, "note": ""},
    {"day": "Mon 27", "icon": "cloud", "tmin": 6, "tmax": 13, "rain": 0.8, "rh": 84, "note": ""},
]
def smooth(key, k=3):
    vals = [r[key] for r in risk_raw]
    return [round(sum(vals[max(0, i - k):i + k + 1]) / len(vals[max(0, i - k):i + k + 1])) for i in range(len(vals))]
sm = {k: smooth(k) for k in ("downy", "powdery", "botrytis")}
risk = [{"date": r["date"], "downy": sm["downy"][i], "powdery": sm["powdery"][i], "botrytis": sm["botrytis"][i]} for i, r in enumerate(risk_raw)]
weather = {"station": "Bernkastel (historical weather, Mosel 2025)", "weekly": weekly, "months": months, "rain": rain, "rainNormal": rain_n,
           "risk": risk, "forecast": forecast,
           "indices": {"winkler": weekly[-1]["gdd"], "winklerNormal": weekly[-1]["gddNormal"], "huglin": 1740, "huglinNormal": 1590,
                       "seasonTmean": 15.9, "seasonTmeanNormal": 14.6, "rainSeason": sum(rain), "rainSeasonNormal": sum(rain_n)},
           "phenology": [{"stage": "Budburst", "date": "14 Apr"}, {"stage": "Flowering", "date": "9 Jun"}, {"stage": "Bunch closure", "date": "6 Jul"},
                         {"stage": "Veraison", "date": "11 Aug"}, {"stage": "Harvest A–D", "date": "27 Sep–10 Oct"}]}

# ------------------------------------------------------------------ programmes (tiers)
programmes = [
    {"id": "spray", "name": "Spray programme", "current": "Medium", "notes": "Contact + systemic fungicides, timed by the Vineyard manager", "tiers": {
        "Low": {"cost": 1300, "hours": 38, "effect": "5 applications, contact products only. Infections get through in wet spells.", "risk": +18},
        "Medium": {"cost": 2600, "hours": 64, "effect": "8 applications timed to model alerts. Good protection in a normal year.", "risk": 0},
        "High": {"cost": 4100, "hours": 92, "effect": "11 applications at tight intervals, systemic before rain. Best protection, most cost.", "risk": -12}}},
    {"id": "canopy", "name": "Canopy work", "current": "Medium", "notes": "Shoot tying, leaf removal in the fruit zone, topping", "tiers": {
        "Low": {"cost": 900, "hours": 60, "effect": "Tying and topping only. Dense canopy: more rot, greener flavours.", "risk": +10},
        "Medium": {"cost": 2200, "hours": 150, "effect": "Adds leaf removal on the morning side after flowering. Airier bunches.", "risk": 0},
        "High": {"cost": 3900, "hours": 260, "effect": "Two leaf-removal passes and bunch thinning. Riper fruit, sunburn risk in heat.", "risk": -8}}},
    {"id": "floor", "name": "Floor management", "current": "Low", "notes": "Steep slope: strimming only, no herbicide", "tiers": {
        "Low": {"cost": 600, "hours": 45, "effect": "Strim twice. Some water competition from weeds in dry spells.", "risk": 0},
        "Medium": {"cost": 1100, "hours": 80, "effect": "Strim four times. Less competition, more labour.", "risk": 0},
        "High": {"cost": 1900, "hours": 120, "effect": "Sown cover crop plus mowing. Better soil structure and erosion control.", "risk": 0}}},
    {"id": "labour", "name": "Labour crew", "current": "Medium", "notes": "Seasonal workers on top of your staff", "tiers": {
        "Low": {"cost": 14000, "hours": 1200, "effect": "2 seasonal workers. Tasks run late; harvest takes longer.", "risk": 0},
        "Medium": {"cost": 26000, "hours": 2300, "effect": "4 seasonal workers. Enough for a normal season on 1.4 ha of steep slope.", "risk": 0},
        "High": {"cost": 38000, "hours": 3400, "effect": "6 seasonal workers. Every task on time, fast selective picking.", "risk": 0}}},
    {"id": "frost", "name": "Frost protection", "current": "Low", "notes": "Only matters from budburst to mid-May", "tiers": {
        "Low": {"cost": 0, "hours": 0, "effect": "None. This slope drains cold air well.", "risk": 0},
        "Medium": {"cost": 1500, "hours": 20, "effect": "Frost candles in the lower Blocks on alert nights.", "risk": 0},
        "High": {"cost": 4800, "hours": 30, "effect": "Rented wind machine for the lower Blocks.", "risk": 0}}},
    {"id": "irrigation", "name": "Irrigation", "current": "Unavailable", "notes": "No water connection on this Plot", "tiers": {}},
]
labour_hours = {"available": 2300 + 3200, "planned": 5100, "weekly": [120, 140, 160, 150, 140, 110, 180, 220, 260, 310, 240, 90]}

# ------------------------------------------------------------------ winery (Lots)
def ferment(oe0, days_, end, curve=1.2, lag=1):
    out = []
    for k in range(days_ + 1):
        t = max(0.0, (k - lag) / max(1, days_ - lag))
        out.append(round(oe0 - (oe0 - end) * (1 - (1 - t) ** curve) if k > lag else oe0 - 0.5 * k, 1))
    return out
lots = [
    {"id": "A", "block": "A", "vessel": "Fuder 1 + 2 (old oak, 2 × 1 000 L)", "volume": 1790, "picked": "8 Oct", "must": {"oe": 91, "ta": 8.6, "ph": 3.08, "yan": 168},
     "phase": "Spontaneous fermentation", "day": 12, "tempC": 17.4, "setC": None, "status": "ok",
     "oe": ferment(91, 12, 24, 1.4, 3), "temp": [12, 12.5, 13, 14.5, 16, 17, 17.8, 18.2, 18.0, 17.8, 17.6, 17.5, 17.4],
     "choices": {"Pressing": "Whole bunch, slow press", "Settling": "Natural, 18 h", "Yeast": "Ambient (spontaneous)", "Temperature": "Cellar ambient (~17 °C)",
                 "MLF": "Not planned", "Vessel": "Old Fuder (neutral oak)", "Lees": "Keep on fine lees until spring", "Sweetness": "Ferment to dry"}},
    {"id": "B", "block": "B", "vessel": "Tank T2 (stainless, 5 000 L)", "volume": 1935, "picked": "3 Oct", "must": {"oe": 84, "ta": 9.3, "ph": 3.02, "yan": 131},
     "phase": "Spontaneous fermentation (slow)", "day": 17, "tempC": 16.8, "setC": 17.0, "status": "warn",
     "oe": ferment(84, 17, 31, 1.1, 3), "temp": [11, 11.5, 12, 13, 14.5, 15.5, 16.4, 16.8, 17, 17, 16.9, 16.9, 16.8, 16.8, 16.8, 16.8, 16.8, 16.8],
     "choices": {"Pressing": "Whole bunch", "Settling": "Cold settling, 24 h", "Yeast": "Ambient (spontaneous)", "Temperature": "17 °C",
                 "MLF": "Block (chill + SO₂ after fermentation)", "Vessel": "Stainless steel", "Lees": "Rack off gross lees", "Sweetness": "Decide later"}},
    {"id": "C", "block": "C", "vessel": "Tank T3 (stainless, 5 000 L)", "volume": 1645, "picked": "27 Sep", "must": {"oe": 77, "ta": 10.4, "ph": 2.96, "yan": 182},
     "phase": "Stopped: chilled, SO₂ added", "day": 21, "tempC": 8.2, "setC": 8.0, "status": "ok",
     "oe": ferment(77, 11, 20, 1.3, 1) + [20.0] * 10, "temp": [12, 13, 14.5, 15.8, 16, 16, 16.1, 16, 16, 15.8, 14, 10, 8.5, 8.3, 8.2, 8.2, 8.2, 8.2, 8.2, 8.2, 8.2, 8.2],
     "analysis": {"abv": 8.9, "rs": 38, "ta": 9.1, "ph": 3.01},
     "choices": {"Pressing": "Whole bunch", "Settling": "Cold settling, 24 h", "Yeast": "Cultured S. cerevisiae (neutral)", "Temperature": "16 °C",
                 "MLF": "Block (chill + SO₂)", "Vessel": "Stainless steel", "Lees": "Rack off gross lees", "Sweetness": "Stop at 38 g/L residual sugar"}},
    {"id": "D", "block": "D", "vessel": "Tank T4 (open-top, on skins)", "volume": 980, "picked": "10 Oct", "must": {"oe": 97, "ta": 7.1, "ph": 3.35, "yan": 205},
     "phase": "Maceration day 10, press tomorrow", "day": 10, "tempC": 26.1, "setC": 27.0, "status": "ok",
     "oe": ferment(97, 10, 4, 1.2, 2), "temp": [14, 14, 18, 23, 27, 29, 28.5, 28, 27.4, 26.8, 26.1],
     "choices": {"Destemming": "100 % destemmed", "Cold soak": "3 days at 10 °C", "Yeast": "Cultured S. cerevisiae", "Temperature": "27 °C (cap to 30 °C)",
                 "Cap management": "Punch-down 2×/day", "Maceration": "10 days, then press", "MLF": "Yes, in barrel", "Vessel": "Barriques: 1 new, 3 used (French)"}},
    {"id": "E", "block": "E", "vessel": "Tank T5 (reserved)", "volume": 0, "picked": None, "must": {"oe": 81, "ta": 9.8, "ph": 3.00, "yan": None},
     "phase": "Still in the vineyard", "day": 0, "tempC": None, "setC": None, "status": "idle", "oe": [], "temp": [], "choices": {}},
]
choice_options = {
    "Pressing": ["Whole bunch, slow press", "Whole bunch", "Destemmed + 6 h skin contact"],
    "Settling": ["Cold settling, 24 h", "Natural, 18 h", "No settling (cloudy must)"],
    "Yeast": ["Ambient (spontaneous)", "Cultured S. cerevisiae (neutral)", "Cultured S. cerevisiae"],
    "Temperature": ["14 °C", "16 °C", "17 °C", "Cellar ambient (~17 °C)", "20 °C", "27 °C (cap to 30 °C)"],
    "MLF": ["Block (chill + SO₂)", "Block (chill + SO₂ after fermentation)", "Allow", "Not planned", "Yes, in barrel"],
    "Vessel": ["Stainless steel", "Old Fuder (neutral oak)", "Barriques: 1 new, 3 used (French)"],
    "Lees": ["Rack off gross lees", "Keep on fine lees until spring", "Lees stirring weekly"],
    "Sweetness": ["Ferment to dry", "Stop at 38 g/L residual sugar", "Stop at 60 g/L residual sugar", "Decide later"],
    "Destemming": ["100 % destemmed", "20 % whole bunch", "50 % whole bunch"],
    "Cold soak": ["None", "3 days at 10 °C", "5 days at 8 °C"],
    "Cap management": ["Pump-over 2×/day", "Punch-down 2×/day", "Délestage once"],
    "Maceration": ["7 days, then press", "10 days, then press", "18 days extended maceration"],
}
choice_why = {
    "Pressing": "Whole-bunch pressing is gentle: fewer phenolics, cleaner juice, the classic choice for Mosel Riesling.",
    "Settling": "Settling removes solids before fermentation; clearer must gives a cleaner, more reductive style.",
    "Yeast": "Ambient yeasts can add complexity but ferment slowly and less predictably; cultured yeast is reliable.",
    "Temperature": "Cool fermentation keeps fruity esters; warm fermentation extracts colour and tannin in reds.",
    "MLF": "Malolactic conversion turns malic into lactic acid: softer acidity, buttery notes. Usually blocked for Riesling.",
    "Vessel": "Stainless steel keeps fruit pure; old oak Fuder adds texture without oak flavour; new oak adds vanilla and spice.",
    "Lees": "Time on fine lees adds texture and protects against oxidation.",
    "Sweetness": "Stopping fermentation (chilling + SO₂) keeps natural grape sugar: off-dry or sweet styles at lower alcohol.",
    "Destemming": "Whole bunches add structure and fresh, herbal notes when stems are ripe; green stems add harsh tannin.",
    "Cold soak": "A cool pre-fermentation soak extracts colour and fruit before alcohol forms.",
    "Cap management": "Moving the cap of skins extracts colour and tannin and keeps it from drying out.",
    "Maceration": "Longer skin contact extracts more tannin; too long can make the wine harsh.",
}

# ------------------------------------------------------------------ blending + wines
blend_lots = [
    {"lot": "A", "name": "Riesling A (Steillage)", "volume": 1790, "abv": 12.4, "rs": 6.0, "ta": 7.9, "ph": 3.12, "oe": 91, "level": "Auslese"},
    {"lot": "B", "name": "Riesling B (Mittelhang)", "volume": 1935, "abv": 11.3, "rs": 9.0, "ta": 8.4, "ph": 3.08, "oe": 84, "level": "Auslese"},
    {"lot": "C", "name": "Riesling C (Hangfuß)", "volume": 1645, "abv": 8.9, "rs": 38.0, "ta": 9.1, "ph": 3.01, "oe": 77, "level": "Spätlese"},
    {"lot": "D", "name": "Spätburgunder D (Kuppe)", "volume": 980, "abv": 13.4, "rs": 1.5, "ta": 5.6, "ph": 3.52, "oe": 97, "level": "UNVERIFIED (red Prädikat minimums)"},
]
wines = [
    {"id": 1, "name": "2025 Riesling Spätlese trocken", "assign": {"A": 100}},
    {"id": 2, "name": "2025 Riesling Kabinett feinherb", "assign": {"C": 100, "B": 40}},
    {"id": 3, "name": "2025 Spätburgunder trocken", "assign": {"D": 100}},
]
tasting = {
    "wine": "2025 Riesling Kabinett feinherb", "status": "Projected at bottling (April 2026)",
    "analysis": {"abv": 9.7, "rs": 29.0, "ta": 8.9, "ph": 3.04, "freeSO2": 38},
    "legal": {"category": "Qualitätswein mit Prädikat: Kabinett, Mosel", "qualifies": "Spätlese (lowest level of its Lots); declared one level lower as Kabinett, which is allowed", "labelTerm": "feinherb (label term, not legally defined)",
              "note": "Game simplification (rulebook v0): a blend takes the lowest Prädikat level of its Lots."},
    "price": {"exCellar": 13.5, "bottles": 3130, "revenue": 42255},
    "sections": [
        {"title": "Appearance", "rows": [
            {"k": "Clarity", "v": "Clear", "why": "Cold settling and a clean fermentation; will be filtered before bottling."},
            {"k": "Intensity", "v": "Pale", "why": "White grape, whole-bunch pressing with no skin contact."},
            {"k": "Colour", "v": "Lemon-green", "why": "Young, reductively handled Riesling in stainless steel."}]},
        {"title": "Nose", "rows": [
            {"k": "Condition", "v": "Clean", "why": "No faults detected: free SO₂ 38 mg/L protected the wine after the stop."},
            {"k": "Intensity", "v": "Medium(+)", "why": "Aromatic variety; cool 16 °C fermentation kept fruity esters."},
            {"k": "Aromas", "v": "Green apple, lemon, lime, white peach, white blossom", "why": "Cool-climate ripening in Block C, picked at 77 °Oe before the rain; the riper Block B share adds peach."},
            {"k": "Development", "v": "Youthful", "why": "Months from harvest. Petrol notes (TDN) typically appear only with bottle age."}]},
        {"title": "Palate", "rows": [
            {"k": "Sweetness", "v": "Off-dry", "why": "Fermentation stopped by chilling and SO₂ at 38 g/L in Lot C; blending with drier Lot B brings it to 29 g/L."},
            {"k": "Acidity", "v": "High", "why": "Early pick (TA 10.4 g/L in the must) and malolactic conversion blocked."},
            {"k": "Alcohol", "v": "Low (9.7 % vol)", "why": "Modest must weight and a stopped fermentation leave sugar unfermented."},
            {"k": "Body", "v": "Light", "why": "Low alcohol and no oak or lees ageing."},
            {"k": "Flavour intensity", "v": "Medium(+)", "why": "Moderate yield in Block B concentrates flavour; Block C's high yield dilutes it slightly."},
            {"k": "Finish", "v": "Medium(+)", "why": "High acidity and fruit concentration carry the finish."}]},
        {"title": "Conclusions", "rows": [
            {"k": "Quality", "v": "Very good", "why": "Balance: sugar offsets the high acidity. Length medium(+), intensity medium(+). Complexity limited while young."},
            {"k": "Readiness", "v": "Can drink now, but has potential for ageing", "why": "High acidity and sugar let it develop honey and petrol notes over 5–10 years."}]},
    ],
}

# ------------------------------------------------------------------ estate, staff, inbox
pnl = [
    {"line": "Wine sales", "actual": 0, "budget": 0, "kind": "income", "note": "First Vintage: nothing sold until bottling"},
    {"line": "Seasonal labour", "actual": -24800, "budget": -26000, "kind": "cost"},
    {"line": "Staff salaries", "actual": -62300, "budget": -63000, "kind": "cost"},
    {"line": "Sprays and canopy", "actual": -4800, "budget": -4800, "kind": "cost"},
    {"line": "Harvest crew", "actual": -6840, "budget": -6000, "kind": "cost"},
    {"line": "Winery consumables", "actual": -1920, "budget": -2500, "kind": "cost", "note": "Yeast, SO₂, nutrients, cleaning"},
    {"line": "Barrels and Fuder", "actual": -4150, "budget": -4000, "kind": "cost", "note": "1 new barrique (French), 3 used, Fuder repair"},
    {"line": "Insurance and fees", "actual": -2100, "budget": -2100, "kind": "cost"},
]
staff = [
    {"role": "Vineyard manager", "name": "Jonas Becker", "level": "Junior", "salary": 2650, "attrs": {"Spray timing": 9, "Canopy work": 11, "Crew efficiency": 10, "Forecast reading": 8, "Explanations": 9}},
    {"role": "Cellar master", "name": "Mira Hoffmann", "level": "Experienced", "salary": 3900, "attrs": {"Fermentation control": 14, "Hygiene": 15, "Sensory skill": 13, "Blending": 12, "Explanations": 12}},
    {"role": "Mentor", "name": "Klaus Weber", "level": "Senior (retires after bottling)", "salary": 0, "attrs": {"Spray timing": 18, "Fermentation control": 17, "Forecast reading": 19, "Blending": 17, "Explanations": 20}},
]
inbox = [
    {"id": 1, "from": "Mentor: Klaus Weber", "role": "mentor", "time": "07:05", "priority": "high", "alert": True,
     "subject": "Block E: noble rot is starting. Pick a Spätlese now, or wait for Auslese?",
     "body": "The fog mornings this week are ideal for Botrytis cinerea to turn noble on healthy, ripe berries. Block E is at 81 °Oe, already a Spätlese. If the dry spell holds until Friday, a selective pass of the botrytised bunches could reach Auslese (≥ 83 °Oe): noble rot shrivels the berries and concentrates the sugar. But rain on Saturday turns noble rot grey within days.",
     "why": "Noble rot needs humid mornings and dry afternoons on ripe, intact berries. Rain splits berries and spreads grey rot, which ruins flavour. The forecast gives you about four good days.",
     "actions": ["Wait, check again Thursday", "Selective pass Friday (two passes)", "Pick everything now as Spätlese"]},
    {"id": 2, "from": "Cellar master", "role": "cellar", "time": "06:50", "priority": "high", "alert": True,
     "subject": "Lot B (T2) has slowed at 31 °Oe",
     "body": "Spontaneous fermentation is losing pace: −1 °Oe per day now, down from −4. Must YAN was only 131 mg N/L.",
     "why": "Yeast need nitrogen to multiply and finish. Below about 140 mg N/L fermentations often slow or stick, and stressed yeast can produce hydrogen sulfide (a rotten-egg smell).",
     "actions": ["Add yeast nutrient", "Warm to 18 °C", "Leave it and watch"]},
    {"id": 3, "from": "Cellar master", "role": "cellar", "time": "Yesterday", "priority": "normal", "alert": True,
     "subject": "Lot D Spätburgunder: press tomorrow?",
     "body": "Ten days on skins, the cap is falling and tannins taste ripe. Pressing tomorrow and moving to barrique for MLF.",
     "why": "Extraction slows once fermentation ends. Longer maceration adds tannin, but past a point it gets harsh and dry.",
     "actions": ["Press tomorrow", "Extend 4 days"]},
    {"id": 4, "from": "Vineyard manager", "role": "vineyard", "time": "Yesterday", "priority": "normal", "alert": False,
     "subject": "Blocks A–D cleared, leaf fall starting", "body": "Picking crates washed and stored. Block E is checked every morning.", "why": "", "actions": []},
    {"id": 5, "from": "Weather service", "role": "weather", "time": "Yesterday", "priority": "low", "alert": False,
     "subject": "Fog mornings until Wednesday, front on Saturday", "body": "", "why": "", "actions": []},
    {"id": 6, "from": "Estate", "role": "estate", "time": "17 Oct", "priority": "low", "alert": False,
     "subject": "Harvest crew paid: €6,840", "body": "", "why": "", "actions": []},
]

# ------------------------------------------------------------------ pre-game: regions + plot comparison
regions = [
    {"id": "mosel", "name": "Mosel", "country": "Germany", "lat": "50° N", "climate": "Cool, marginal continental",
     "winkler": "Region I", "rain": "≈ 700 mm/year", "soils": "Devonian slate on steep river slopes; alluvium on the valley floor",
     "hazards": ["Spring frost on the valley floor", "Rot in wet autumns", "Very high labour on steep slopes"],
     "law": "Prädikat system: must weight at harvest sets Kabinett, Spätlese, Auslese and above", "land": "€15,000–90,000 per ha", "plots": 4,
     "styles": ["Riesling from dry to lusciously sweet", "Light, high-acid, low-alcohol Kabinett", "Some Spätburgunder (Pinot Noir)"],
     "tmean": [1.5, 2.5, 6.0, 9.5, 13.5, 16.5, 18.5, 18.0, 14.5, 10.0, 5.5, 2.5], "rainMonthly": [60, 55, 55, 45, 60, 65, 70, 60, 55, 60, 65, 70],
     "suit": {"Riesling": 5, "Chardonnay": 3, "Pinot Noir": 3, "Cabernet Sauvignon": 1},
     "blurb": "Riesling on slate at the cool edge of ripening. Sun on the steep slopes makes the difference."},
    {"id": "cotedor", "name": "Côte d'Or", "country": "France", "lat": "47° N", "climate": "Cool continental",
     "winkler": "Region I–II", "rain": "≈ 750 mm/year", "soils": "Limestone and marl on an east-facing escarpment",
     "hazards": ["Hail", "Spring frost", "Mildew in wet years"],
     "law": "AOC hierarchy: Bourgogne, Village, Premier Cru, Grand Cru; Pinot Noir and Chardonnay", "land": "€150,000 to several million per ha", "plots": 4,
     "styles": ["Pinot Noir: red fruit, silky tannins", "Chardonnay, often fermented and aged in oak", "Wines named after the site, not the grape"],
     "tmean": [2.0, 3.0, 7.0, 10.0, 14.5, 18.0, 20.5, 20.0, 16.0, 11.5, 6.0, 3.0], "rainMonthly": [55, 50, 50, 60, 80, 65, 60, 60, 60, 70, 70, 65],
     "suit": {"Riesling": 3, "Chardonnay": 5, "Pinot Noir": 5, "Cabernet Sauvignon": 1},
     "blurb": "The home of Pinot Noir and Chardonnay, where a few metres of slope change the Classification."},
    {"id": "napa", "name": "Napa Valley", "country": "USA", "lat": "38.5° N", "climate": "Warm Mediterranean",
     "winkler": "Region II–IV", "rain": "≈ 600 mm, almost all in winter", "soils": "Alluvial fans, volcanic hillsides, clay in Carneros",
     "hazards": ["Heat spikes at harvest", "Drought", "Frost in low spots"],
     "law": "AVA rules: 85 % from the AVA, 75 % of the named Variety", "land": "€250,000–1,000,000+ per ha", "plots": 4,
     "styles": ["Full-bodied Cabernet Sauvignon, often in new oak", "Ripe Chardonnay", "Pinot Noir and Chardonnay from cool Carneros"],
     "tmean": [9.0, 10.5, 12.0, 13.5, 17.0, 20.0, 22.0, 21.5, 20.5, 17.0, 12.0, 9.0], "rainMonthly": [125, 115, 85, 35, 15, 4, 0, 1, 4, 30, 75, 110],
     "suit": {"Riesling": 1, "Chardonnay": 4, "Pinot Noir": 3, "Cabernet Sauvignon": 5},
     "blurb": "Sun is never short. The craft is keeping acidity and freshness in the heat."},
]
plots = [
    {"id": 1, "name": "Moselufer", "kind": "Flat riverbank alluvium", "price": 38000, "ha": 1.6, "elevation": 108, "slope": 3, "aspect": "S", "soil": "Deep sandy-loam alluvium",
     "classification": "Mosel (Prädikat possible)",
     "attrs": {"Sun exposure": 9, "Heat accumulation": 10, "Frost safety": 4, "Drainage": 8, "Water holding": 16, "Low vigour": 5, "Rot safety": 7, "Mechanisation": 18, "Labour ease": 17},
     "hoursPerHa": 450, "suit": {"Riesling": 2, "Chardonnay": 2, "Pinot Noir": 2, "Cabernet Sauvignon": 1},
     "mentor": "Cheap and easy to work, but it's a frost pocket and too fertile. You'll fight vigour and rot every year."},
    {"id": 2, "name": "Seitental Ost", "kind": "Gentle east-facing side valley", "price": 52000, "ha": 1.3, "elevation": 170, "slope": 14, "aspect": "E", "soil": "Loess over slate",
     "classification": "Mosel (Prädikat possible)",
     "attrs": {"Sun exposure": 11, "Heat accumulation": 9, "Frost safety": 11, "Drainage": 12, "Water holding": 13, "Low vigour": 10, "Rot safety": 11, "Mechanisation": 13, "Labour ease": 13},
     "hoursPerHa": 650, "suit": {"Riesling": 3, "Chardonnay": 3, "Pinot Noir": 3, "Cabernet Sauvignon": 1},
     "mentor": "Morning sun only, so it ripens late. Fine for a fresh Kabinett in warm years, a struggle in cool ones."},
    {"id": 3, "name": "Schieferhang Südwest", "kind": "Steep south-west blue slate", "price": 96000, "ha": 1.4, "elevation": 150, "slope": 55, "aspect": "SW", "soil": "Blue Devonian slate, shallow",
     "classification": "Mosel (Prädikat possible)",
     "attrs": {"Sun exposure": 17, "Heat accumulation": 15, "Frost safety": 16, "Drainage": 18, "Water holding": 7, "Low vigour": 16, "Rot safety": 15, "Mechanisation": 5, "Labour ease": 5},
     "hoursPerHa": 1300, "suit": {"Riesling": 5, "Chardonnay": 3, "Pinot Noir": 4, "Cabernet Sauvignon": 1},
     "mentor": "This is the classic. Slate stores the day's heat and the slope catches the afternoon sun. Hard work, and worth it."},
    {"id": 4, "name": "Terrassen Süd", "kind": "Very steep south-facing terraces", "price": 158000, "ha": 1.1, "elevation": 190, "slope": 68, "aspect": "S", "soil": "Slate terraces with dry-stone walls",
     "classification": "Mosel (Prädikat possible)",
     "attrs": {"Sun exposure": 20, "Heat accumulation": 18, "Frost safety": 18, "Drainage": 19, "Water holding": 5, "Low vigour": 18, "Rot safety": 17, "Mechanisation": 1, "Labour ease": 2},
     "hoursPerHa": 1600, "suit": {"Riesling": 5, "Chardonnay": 3, "Pinot Noir": 4, "Cabernet Sauvignon": 2},
     "mentor": "The best heat on the river. Everything is done by hand and the walls need care. Can you afford the labour?"},
]

glossary = [
    ("Estate", "Your wine business. It owns Plots and makes Wine from them."),
    ("Region", "A real wine region with its own climate, soils, hazards and wine law, such as the Mosel."),
    ("Plot", "A piece of land in a Region that the Estate can buy. It is divided into Blocks."),
    ("Block", "A zone within a Plot with its own soil and microclimate. It is planted, managed and harvested as a unit."),
    ("Classification", "A Plot's legal standing in its Region's appellation system. It caps the Legal category of its wine."),
    ("Variety", "A grape cultivar you can plant, such as Riesling. Any Variety can go anywhere; a poor match shows in the results."),
    ("Planting", "The one-off choices when vines go into bare land: Variety, clone, rootstock, density, row orientation, training system."),
    ("Establishment", "The young-vine years before the first full crop, about three. The game fast-forwards through them."),
    ("Vintage", "One growing season and the wine made from it, named by harvest year."),
    ("Programme", "A standing instruction for one area of work, set to Low, Medium or High. Staff carry it out daily."),
    ("Alert", "Something in the simulation that stops time and needs your attention."),
    ("Staff level", "Junior, Experienced or Senior. Higher levels work better and explain more; advice is correct at every level."),
    ("Mentor", "An expert about to retire who guides you through your first Vintage."),
    ("Lot", "The fruit of one Block in one Vintage, fermented and aged as its own batch."),
    ("Wine", "A finished, bottled product made from one Lot or a blend of Lots."),
    ("Legal category", "The designation a Wine qualifies for under its Region's rules, such as Mosel Kabinett. The main driver of price."),
    ("Tasting sheet", "The structured assessment of a Wine. Every descriptor is linked to the decision or condition that caused it."),
    ("°Oechsle (°Oe)", "German measure of must weight: how much denser than water the juice is. 1.084 g/mL = 84 °Oe."),
    ("°Brix", "Sugar content of juice as a percentage by weight. Roughly °Oe divided by 4.2 at typical must weights."),
    ("Titratable acidity (TA)", "Total acid in must or wine, reported here in g/L as tartaric acid."),
    ("pH", "How strong the acidity is. Lower pH means sharper acidity, better colour stability and more effective SO₂."),
    ("Stem water potential (Ψstem)", "How hard the vine has to pull water, in megapascals. More negative means more water stress."),
    ("YAN", "Yeast assimilable nitrogen, in mg N/L. Too little slows fermentation and can cause off-smells."),
    ("Malolactic conversion (MLF)", "Bacteria turn sharp malic acid into softer lactic acid. Lowers acidity, raises pH."),
    ("Botrytis cinerea", "A fungus. On healthy, ripe grapes in misty-then-dry weather it becomes noble rot; in wet weather it is grey rot."),
    ("Downy mildew", "A disease (Plasmopara viticola) spread by rain on warm days. Attacks leaves and young bunches."),
    ("Powdery mildew", "A fungal disease (Erysiphe necator) favoured by warm, shaded, humid conditions without rain."),
    ("Veraison", "The stage when berries soften and change colour. Sugar builds up and acidity falls from here on."),
    ("Prädikat", "German quality levels set by must weight at harvest: Kabinett, Spätlese, Auslese, Beerenauslese, Trockenbeerenauslese, Eiswein."),
    ("Feinherb", "A German label term for off-dry wines. It has no legal definition."),
    ("Einzelpfahl", "Single-stake training traditional on steep Mosel slopes: each vine tied to its own stake, with two canes bent into a heart shape."),
    ("Fuder", "The traditional Mosel oak cask, 1 000 litres."),
    ("Barrique", "A 225-litre oak barrel."),
    ("Growing degree days (GDD)", "Daily mean temperature above 10 °C, added up over the season. A measure of heat available for ripening."),
    ("Winkler index", "Growing degree days from April to October (Northern Hemisphere), grouped into Regions I–V."),
    ("Huglin index", "A heat index that weights daytime maximum temperatures and day length, often used in Europe."),
    ("Rootstock", "The root part of a grafted vine. Chosen for phylloxera resistance, vigour, and tolerance of drought or lime."),
]

data = {
    "note": "PROTOTYPE fake data: plausible Mosel values, not simulated and not yet checked against docs/science.",
    "estate": "Weingut Kellermann (prototype)", "date": "Mon 20 Oct 2025", "stage": "Harvest, Block E still hanging", "cash": 171850,
    "plot": {"name": "Schieferhang Südwest", "region": "Mosel", "ha": 1.4, "blocks": 5, "classification": "Mosel (Prädikat eligible)",
             "varieties": "Riesling, Spätburgunder", "leaf": "4th leaf (planted 2022)", "training": "Einzelpfahl"},
    "modes": {"mode": "Normal mode", "weather": "Historical weather: Mosel 2025"},
    "weeks": [fmt(w) for w in weeks], "blocks": blocks, "weather": weather, "programmes": programmes, "labourHours": labour_hours,
    "lots": lots, "choiceOptions": choice_options, "choiceWhy": choice_why,
    "blendLots": blend_lots, "wines": wines, "tasting": tasting,
    "pnl": pnl, "staff": staff, "inbox": inbox, "regions": regions, "plots": plots,
    "glossary": [{"term": t, "text": x} for t, x in glossary],
    "cashflow": [212000, 208500, 203900, 199300, 196400, 192800, 188100, 184300, 178200, 171850],
    "cashflowLabels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct"],
}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=1)
print("wrote", OUT, "blocks", len(blocks), "weekly weather", len(weekly), "risk days", len(risk))
