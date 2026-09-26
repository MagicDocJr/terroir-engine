#!/usr/bin/env python3
"""Source of truth for data/plots.json (Regions -> Plots -> Blocks).

Run from the repo root:  python3 tools/gen_plots.py
Writes data/plots.json and prints the Markdown tables used in docs/science/regions-and-plots.md
(pipe to a file with --tables PATH).

TAW (total available water in the root zone) is derived, not typed:
    TAW = rootingDepth[m] * (1 - stones%) * AWC(texture)[mm per m]
AWC values are mid-points of the FAO-56 Table 19 ranges (field capacity minus wilting point),
cited from memory in docs/science/regions-and-plots.md.
"""
import json
import os
import sys

AWC = {"sand": 80, "loamy sand": 90, "sandy loam": 130, "loam": 155, "silt loam": 160, "clay loam": 155,
       "silty clay loam": 155, "silty clay": 160, "clay": 160, "gravelly loam": 150, "slate loam": 140}


def blk(id, name, area, texture, sand, silt, clay, stones, depth, pH, lime, om, drainage, aspect, slope, elev,
        frost, fog, wind, heat, notes):
    taw = round(depth / 100 * (1 - stones / 100) * AWC[texture])
    return {"id": id, "name": name, "areaHa": area,
            "soil": {"texture": texture, "sandPct": sand, "siltPct": silt, "clayPct": clay, "stonesPctVol": stones,
                     "rootingDepthCm": depth, "tawMm": taw, "pH": pH, "activeLimePct": lime,
                     "organicMatterPct": om, "drainage": drainage},
            "topography": {"aspectDeg": aspect, "slopePct": slope, "elevationM": elev},
            "microclimate": {"frostPocket": frost, "fogFrequency": fog, "windExposure": wind,
                             "radiativeHeat": heat},
            "notes": notes}


def plot(id, name, tier, lat, lon, elev, slope, aspect, area, classification, price, mech, training, summary,
         blocks):
    return {"id": id, "name": name, "tier": tier, "lat": lat, "lon": lon, "elevationM": elev, "slopePct": slope,
            "aspectDeg": aspect, "areaHa": area, "classification": classification, "pricePerHaEur": price,
            "mechanisation": mech, "trainingAllowed": training, "summary": summary, "blocks": blocks}


REGIONS = [
    {"id": "mosel", "name": "Mosel", "country": "DE", "euZone": "A",
     "appellationSystem": "German PDO Mosel (Prädikat)", "weatherReference": "ERA5 cell near Bernkastel-Kues",
     "plots": [
         plot("mosel-uferflur", "Uferflur", "cheap", 49.912, 7.020, 112, 2, 180, 1.6,
              "Mosel PDO (Qualitätswein / Prädikat eligible; flat land)", 20000, "direct tractor (flat)",
              ["Guyot", "Cordon"],
              "Flat riverbank alluvium just above the flood line: fertile, vigorous, a cold-air and fog trap.",
              [blk("A", "Riverside sand", 0.6, "loamy sand", 70, 20, 10, 10, 140, 6.6, 0, 1.5, "excessive",
                   180, 1, 111, 0.8, 0.8, 0.3, 0.3,
                   "Deep river sand: warms fast but holds little water in dry spells."),
               blk("B", "Gravel terrace", 0.5, "gravelly loam", 45, 35, 20, 35, 110, 6.4, 0, 1.8, "good",
                   180, 2, 113, 0.6, 0.7, 0.3, 0.4, "Old river-terrace gravels: the best-drained Block on the Plot."),
               blk("C", "Silty hollow", 0.5, "silt loam", 20, 60, 20, 5, 130, 6.8, 0, 2.5, "poor",
                   180, 1, 111, 0.9, 0.9, 0.2, 0.2,
                   "Lowest point: waterlogs after heavy rain; worst frost and botrytis risk.")]),
         plot("mosel-seitental", "Seitental", "mid-low", 49.925, 7.085, 190, 18, 95, 1.4,
              "Mosel PDO (Prädikat eligible)", 22000, "direct tractor across the slope", ["Guyot", "Cordon"],
              "Gentle east-facing side valley, loess over slate: morning sun, cool afternoons, late ripening.",
              [blk("A", "Deep loess", 0.4, "silt loam", 15, 65, 20, 5, 120, 6.2, 0, 2.0, "moderate",
                   95, 14, 175, 0.4, 0.5, 0.3, 0.3, "Loess cap: good water, vigorous vines, softer acidity."),
               blk("B", "Loess over slate", 0.4, "slate loam", 30, 45, 25, 35, 90, 5.8, 0, 1.8, "good",
                   95, 18, 190, 0.3, 0.4, 0.4, 0.4, "Transition zone, balanced vigour."),
               blk("C", "Upper slate rib", 0.3, "slate loam", 35, 40, 25, 60, 70, 5.5, 0, 1.5, "excessive",
                   100, 24, 210, 0.2, 0.3, 0.6, 0.5,
                   "Shallow, stony, windy: small berries, drought stress in hot years."),
               blk("D", "Valley floor edge", 0.3, "silt loam", 20, 60, 20, 10, 110, 6.4, 0, 2.2, "moderate",
                   90, 8, 165, 0.7, 0.6, 0.2, 0.2, "Cold-air drainage from the side valley collects here.")]),
         plot("mosel-blauschiefer", "Blauschiefer-Hang", "mid-high", 49.943, 7.045, 170, 55, 215, 1.2,
              "Mosel PDO (Prädikat eligible; single-vineyard name needs ≥85 % Riesling or Pinot Noir)", 45000,
              "winch (Seilzug)", ["Einzelpfahl", "Guyot"],
              "Steep SW-facing blue Devonian slate: the classic Middle Mosel Riesling slope.",
              [blk("A", "Top edge", 0.2, "slate loam", 35, 40, 25, 65, 80, 5.4, 0, 1.4, "excessive",
                   215, 50, 235, 0.1, 0.2, 0.7, 0.6, "Windy, below the forest edge: coolest part of the slope."),
               blk("B", "Upper core", 0.3, "slate loam", 35, 40, 25, 60, 90, 5.5, 0, 1.5, "excessive",
                   215, 58, 200, 0.1, 0.3, 0.5, 0.8, "Classic flaky blue slate, heat-storing."),
               blk("C", "Rocky rib", 0.2, "slate loam", 40, 35, 25, 75, 70, 5.3, 0, 1.2, "excessive",
                   205, 65, 185, 0.1, 0.3, 0.5, 1.0,
                   "Bare rock ribs: highest radiation, earliest ripening, drought-prone."),
               blk("D", "Lower core", 0.3, "slate loam", 30, 45, 25, 50, 110, 5.7, 0, 1.8, "good",
                   215, 55, 155, 0.2, 0.5, 0.4, 0.7, "Colluvium collects here: a little more water and vigour."),
               blk("E", "Foot of slope", 0.2, "loam", 30, 45, 25, 35, 130, 6.0, 0, 2.0, "good",
                   210, 30, 125, 0.4, 0.7, 0.2, 0.4,
                   "Near the road and river: morning fog lingers and botrytis comes early.")]),
         plot("mosel-terrassen", "Terrassen-Steilstlage", "expensive", 49.981, 7.022, 190, 70, 180, 0.8,
              "Mosel PDO (Prädikat eligible; single-vineyard name needs ≥85 % Riesling or Pinot Noir)", 80000,
              "hand only (monorack for transport)", ["Einzelpfahl"],
              "Very steep south-facing slate terraces with dry-stone walls: the most heat and the most labour.",
              [blk("A", "Red slate terraces", 0.2, "slate loam", 40, 35, 25, 65, 80, 5.9, 0, 1.3, "excessive",
                   180, 72, 170, 0.0, 0.3, 0.4, 0.9,
                   "Iron-rich red slate: warm, spicy style (UNVERIFIED sensory link)."),
               blk("B", "Blue slate terraces", 0.25, "slate loam", 35, 40, 25, 65, 80, 5.4, 0, 1.3, "excessive",
                   180, 70, 190, 0.0, 0.3, 0.4, 0.9, "Classic blue slate."),
               blk("C", "Wall-foot heat trap", 0.15, "slate loam", 40, 35, 25, 70, 60, 5.5, 0, 1.0, "excessive",
                   175, 75, 160, 0.0, 0.3, 0.2, 1.0,
                   "Right under south-facing dry-stone walls: radiant heat, sunburn risk in heatwaves."),
               blk("D", "Upper terrace, forest edge", 0.2, "slate loam", 35, 40, 25, 55, 90, 5.2, 0, 1.6,
                   "excessive", 185, 65, 245, 0.1, 0.2, 0.6, 0.6, "Cooler, later, more acidity.")]),
     ]},
    {"id": "cote-dor", "name": "Côte d'Or", "country": "FR", "euZone": "C I (UNVERIFIED)",
     "appellationSystem": "AOC (regional / village / premier cru / grand cru)",
     "weatherReference": "ERA5 cell near Beaune",
     "plots": [
         plot("cotedor-plaine", "Plaine des Bas", "cheap", 46.975, 4.790, 215, 1, 110, 1.0,
              "Bourgogne AOC (regional)", 150000, "straddle tractor", ["Guyot", "Cordon"],
              "Flat land below the slope: deep clay, fertile, frost-prone. Bourgogne AOC only.",
              [blk("A", "Heavy clay", 0.35, "clay", 20, 30, 50, 5, 140, 7.8, 4, 2.2, "poor",
                   110, 1, 214, 0.7, 0.4, 0.2, 0.3, "Cold, wet clay: late budburst but high frost and rot risk."),
               blk("B", "Silty clay", 0.35, "silty clay", 15, 45, 40, 5, 130, 7.9, 5, 2.0, "moderate",
                   110, 1, 215, 0.6, 0.4, 0.2, 0.3, "Vigorous; big crops unless you prune hard."),
               blk("C", "Gravel lens", 0.3, "gravelly loam", 40, 35, 25, 30, 100, 8.0, 6, 1.6, "good",
                   110, 2, 217, 0.5, 0.3, 0.3, 0.4, "Old stream gravels: best-drained Block on the flats.")]),
         plot("cotedor-hautes", "Plateau des Hautes", "mid-low", 47.030, 4.735, 420, 6, 150, 1.2,
              "Bourgogne Hautes-Côtes de Beaune AOC (regional)", 70000, "straddle tractor", ["Guyot", "Cordon"],
              "Hautes-Côtes plateau at ~400 m: cool, windy, late-ripening limestone.",
              [blk("A", "Thin rendzina", 0.3, "clay loam", 25, 40, 35, 45, 45, 8.2, 18, 3.0, "excessive",
                   150, 8, 430, 0.2, 0.3, 0.7, 0.3,
                   "Very high active lime: severe chlorosis risk unless a lime-tolerant rootstock is used."),
               blk("B", "Marly clay", 0.35, "clay loam", 20, 40, 40, 20, 90, 8.0, 10, 2.5, "moderate",
                   150, 5, 420, 0.3, 0.3, 0.5, 0.3, "Water-holding marls: the steadiest Block."),
               blk("C", "Wind-exposed edge", 0.25, "clay loam", 25, 40, 35, 35, 60, 8.1, 14, 2.6, "good",
                   170, 7, 435, 0.1, 0.2, 0.9, 0.2, "Dries fast after rain (less rot) but ripens last."),
               blk("D", "Sheltered combe", 0.3, "clay loam", 20, 45, 35, 15, 100, 7.9, 8, 2.4, "moderate",
                   140, 4, 405, 0.5, 0.4, 0.3, 0.4,
                   "Warmest spot, but cold air pools on clear spring nights.")]),
         plot("cotedor-village", "Mi-Côte Villages", "mid-high", 46.992, 4.765, 290, 9, 120, 0.5,
              "Village AOC (Côte de Beaune village; fictional commune permitting red and white)", 900000,
              "straddle tractor", ["Guyot", "Cordon"],
              "Village-level mid-slope on marl and limestone, ESE-facing.",
              [blk("A", "Marl-rich", 0.15, "clay loam", 20, 40, 40, 20, 100, 8.0, 10, 2.2, "moderate",
                   120, 8, 285, 0.2, 0.2, 0.3, 0.5, "Marl gives body; watch vigour in wet years."),
               blk("B", "Limestone scree", 0.12, "clay loam", 30, 35, 35, 50, 70, 8.1, 6, 1.8, "good",
                   115, 11, 300, 0.1, 0.2, 0.4, 0.6,
                   "Stony, well-drained: finer, more mineral style (UNVERIFIED sensory link)."),
               blk("C", "Brown calcareous", 0.13, "loam", 30, 40, 30, 15, 120, 7.8, 5, 2.0, "good",
                   120, 7, 280, 0.2, 0.2, 0.3, 0.5, "The deepest, most balanced soil."),
               blk("D", "Upper stony", 0.1, "clay loam", 30, 35, 35, 55, 55, 8.2, 8, 1.6, "excessive",
                   115, 13, 310, 0.1, 0.1, 0.5, 0.6,
                   "Thin soil near the hill forest; drought stress in hot years.")]),
         plot("cotedor-premiercru", "Clos du Premier", "expensive", 47.005, 4.770, 275, 12, 110, 0.5,
              "Premier Cru AOC (fictional climat)", 2500000, "straddle tractor", ["Guyot", "Cordon"],
              "Premier Cru mid-slope: thin limestone rubble facing E/SE, the sweet spot of the Côte.",
              [blk("A", "Thin rubble on limestone", 0.15, "clay loam", 30, 35, 35, 55, 60, 8.1, 8, 1.8, "good",
                   110, 13, 285, 0.1, 0.1, 0.3, 0.7, "Classic 1er Cru soil: low vigour, small berries."),
               blk("B", "Red iron clay pocket", 0.12, "clay", 20, 30, 50, 25, 90, 7.7, 4, 2.2, "moderate",
                   110, 10, 275, 0.1, 0.1, 0.3, 0.6,
                   "Iron-rich clay: firmer tannin in Pinot Noir (UNVERIFIED sensory link)."),
               blk("C", "Mid-slope core", 0.13, "clay loam", 25, 40, 35, 40, 80, 8.0, 6, 2.0, "good",
                   110, 12, 270, 0.1, 0.1, 0.3, 0.7, "Balanced."),
               blk("D", "Lower colluvium", 0.1, "loam", 30, 40, 30, 20, 110, 7.8, 5, 2.2, "moderate",
                   105, 8, 260, 0.3, 0.2, 0.2, 0.5, "Deeper and richer: more yield, less concentration.")]),
     ]},
    {"id": "napa", "name": "Napa Valley", "country": "US", "euZone": None,
     "appellationSystem": "AVA (Napa Valley + sub-AVAs)", "weatherReference": "ERA5 cell near Oakville",
     "plots": [
         plot("napa-floor", "Valley Floor Loam", "cheap", 38.370, -122.330, 25, 1, 180, 1.0,
              "Napa Valley AVA", 330000, "tractor, machine harvest possible", ["Cordon", "Guyot"],
              "Heavy valley-floor loam: vigorous, frost in low spots, irrigation available.",
              [blk("A", "Clay loam", 0.4, "clay loam", 30, 35, 35, 5, 150, 6.8, 0, 2.2, "moderate",
                   180, 1, 26, 0.6, 0.4, 0.3, 0.4, "Deep, fertile: high vigour and yield."),
               blk("B", "Low swale", 0.3, "silty clay", 15, 45, 40, 5, 150, 7.0, 0, 2.5, "poor",
                   180, 1, 23, 0.9, 0.5, 0.2, 0.3, "Frost pocket: needs the wind machine in April."),
               blk("C", "Loam rise", 0.3, "loam", 40, 40, 20, 10, 130, 6.7, 0, 2.0, "good",
                   180, 2, 28, 0.4, 0.4, 0.3, 0.5, "Slightly raised, better drained.")]),
         plot("napa-carneros", "Carneros Clay", "mid-low", 38.255, -122.300, 20, 4, 200, 1.2,
              "Los Carneros AVA (label must also say Napa Valley)", 270000, "tractor", ["Guyot", "Cordon"],
              "Carneros: cool, foggy, windy, shallow clay over claypan. Better for Pinot Noir and "
              "Chardonnay than for Cabernet.",
              [blk("A", "Shallow clay over claypan", 0.35, "clay loam", 25, 35, 40, 10, 60, 6.5, 0, 2.0, "poor",
                   200, 3, 18, 0.3, 0.8, 0.7, 0.3,
                   "Claypan limits roots: low vigour, water stress late season."),
               blk("B", "Windy knoll", 0.3, "clay loam", 30, 35, 35, 20, 50, 6.6, 0, 1.8, "moderate",
                   210, 6, 30, 0.1, 0.7, 0.9, 0.3, "Afternoon bay wind: thick skins, slow ripening."),
               blk("C", "Swale", 0.3, "clay", 20, 30, 50, 5, 100, 6.8, 0, 2.4, "poor",
                   190, 2, 15, 0.5, 0.8, 0.5, 0.3, "Deeper clay: more water, more vigour, more mildew."),
               blk("D", "Bay-facing slope", 0.25, "clay loam", 25, 35, 40, 15, 70, 6.6, 0, 2.0, "moderate",
                   180, 5, 22, 0.2, 0.9, 0.7, 0.3, "Fog sits here longest each morning.")]),
         plot("napa-mountain", "Mountain Volcanic", "mid-high", 38.380, -122.410, 420, 28, 120, 0.8,
              "Mountain sub-AVA (e.g. Mount Veeder-type), Napa Valley", 300000,
              "small tracked tractor, hand harvest", ["Cordon", "Guyot"],
              "Hillside above the fog line: thin volcanic and sedimentary soils, low yields, firm tannin.",
              [blk("A", "Volcanic tuff", 0.25, "loam", 40, 40, 20, 40, 60, 6.0, 0, 1.8, "excessive",
                   120, 25, 410, 0.0, 0.1, 0.5, 0.6, "Thin tuff: tiny berries, intense colour."),
               blk("B", "Rocky ridge", 0.2, "gravelly loam", 45, 35, 20, 60, 50, 5.9, 0, 1.5, "excessive",
                   110, 35, 450, 0.0, 0.0, 0.8, 0.7, "Most exposed: sun and wind, lowest yield."),
               blk("C", "Colluvial bench", 0.2, "loam", 35, 40, 25, 25, 100, 6.2, 0, 2.2, "good",
                   125, 15, 400, 0.1, 0.1, 0.4, 0.5, "Deeper pocket: the most generous Block up here."),
               blk("D", "North-facing shoulder", 0.15, "loam", 40, 40, 20, 35, 80, 6.1, 0, 2.0, "good",
                   20, 20, 430, 0.1, 0.1, 0.5, 0.2, "Cooler, later: freshness in hot years.")]),
         plot("napa-bench", "Rutherford Bench", "expensive", 38.458, -122.425, 60, 3, 90, 1.0,
              "Rutherford AVA (Napa Valley)", 510000, "tractor", ["Cordon", "Guyot"],
              "Gravelly alluvial fan (the 'bench'): the benchmark Cabernet Sauvignon site.",
              [blk("A", "Gravelly fan", 0.3, "gravelly loam", 45, 35, 20, 35, 120, 6.5, 0, 1.8, "good",
                   90, 3, 62, 0.2, 0.3, 0.3, 0.5, "Classic bench gravel: moderate vigour, ripe tannin."),
               blk("B", "Cobbly apex", 0.25, "gravelly loam", 50, 30, 20, 50, 100, 6.4, 0, 1.6, "excessive",
                   90, 5, 70, 0.1, 0.3, 0.3, 0.6, "Coarsest, driest: most concentrated fruit."),
               blk("C", "Fine loam toe", 0.25, "loam", 40, 40, 20, 15, 140, 6.7, 0, 2.0, "good",
                   90, 2, 55, 0.3, 0.4, 0.3, 0.4, "Finer, deeper: more yield."),
               blk("D", "Creek-side gravel", 0.2, "gravelly loam", 50, 30, 20, 40, 110, 6.6, 0, 1.8, "good",
                   95, 2, 52, 0.4, 0.4, 0.2, 0.4, "Near the creek: cooler nights, some frost risk.")]),
     ]},
]

DOC = {"schemaVersion": 1,
       "note": "Fictional Plots at real representative locations. Soil and microclimate values are design values "
               "(UNVERIFIED per Plot); TAW = rootingDepth x (1 - stones) x AWC(texture). "
               "See docs/science/regions-and-plots.md.",
       "units": {"price": "EUR per ha, bare plantable land, 2026 levels (game simplification)",
                 "tawMm": "total available water in the root zone, mm",
                 "microclimate": "0..1 relative indices used by the simulation",
                 "activeLimePct": "% active CaCO3"},
       "startingCapitalEur": 600000,
       "regions": REGIONS}


def validate():
    for r in REGIONS:
        assert len(r["plots"]) == 4, r["id"]
        for p in r["plots"]:
            s = sum(b["areaHa"] for b in p["blocks"])
            assert abs(s - p["areaHa"]) < 1e-6, (p["id"], s, p["areaHa"])
            assert 3 <= len(p["blocks"]) <= 6, p["id"]
            assert 0.5 <= p["areaHa"] <= 2.0, p["id"]


def tables():
    out = []
    for r in REGIONS:
        out.append(f"\n### {r['name']} Plots\n")
        out.append("| Tier | Plot | Location (lat, lon, elev) | Slope / aspect | Area | Classification | Land price | Work |")
        out.append("|---|---|---|---|---|---|---|---|")
        for p in r["plots"]:
            out.append(f"| {p['tier']} | **{p['name']}**: {p['summary']} | {p['lat']}, {p['lon']}, {p['elevationM']} m "
                       f"| {p['slopePct']} % / {p['aspectDeg']}° | {p['areaHa']} ha | {p['classification']} "
                       f"| €{p['pricePerHaEur']:,}/ha | {p['mechanisation']} |")
        for p in r["plots"]:
            out.append(f"\n**{p['name']}: Blocks**\n")
            out.append("| Block | Area | Texture (sand/silt/clay %) | Stones | Depth | TAW | pH | Active lime | Drainage "
                       "| Frost / fog / wind / heat | Notes |")
            out.append("|---|---|---|---|---|---|---|---|---|---|---|")
            for b in p["blocks"]:
                s, m = b["soil"], b["microclimate"]
                out.append(f"| {b['id']} {b['name']} | {b['areaHa']} ha | {s['texture']} ({s['sandPct']}/{s['siltPct']}/"
                           f"{s['clayPct']}) | {s['stonesPctVol']} % | {s['rootingDepthCm']} cm | {s['tawMm']} mm "
                           f"| {s['pH']} | {s['activeLimePct']} % | {s['drainage']} | {m['frostPocket']} / "
                           f"{m['fogFrequency']} / {m['windExposure']} / {m['radiativeHeat']} | {b['notes']} |")
    return "\n".join(out)


if __name__ == "__main__":
    validate()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "data", "plots.json"), "w", encoding="utf-8") as fh:
        json.dump(DOC, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    if "--tables" in sys.argv:
        with open(sys.argv[sys.argv.index("--tables") + 1], "w", encoding="utf-8") as fh:
            fh.write(tables())
    # Refresh the generated section of the Markdown doc (between the BEGIN/END markers).
    md_path = os.path.join(root, "docs", "science", "regions-and-plots.md")
    if os.path.exists(md_path):
        begin, end = "<!-- BEGIN GENERATED PLOT TABLES (tools/gen_plots.py) -->", "<!-- END GENERATED PLOT TABLES -->"
        text = open(md_path, encoding="utf-8").read()
        if begin in text and end in text:
            head, rest = text.split(begin, 1)
            _, tail = rest.split(end, 1)
            with open(md_path, "w", encoding="utf-8") as fh:
                fh.write(head + begin + "\n" + tables() + "\n\n" + end + tail)
    print("ok:", sum(len(p["blocks"]) for r in REGIONS for p in r["plots"]), "blocks")
