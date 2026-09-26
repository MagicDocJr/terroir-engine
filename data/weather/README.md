# Historical weather (daily), 1990–2025

Daily weather for one representative coordinate per Region. This is the **Historical weather** of the Timeline (spec §3.4, ADR 0002). Regenerate with `python3 tools/weather/fetch_weather.py`; validate with `python3 tools/weather/validate.py` (see `docs/science/weather-validation.md`).

| File | Region | Requested coordinate | Grid cell used (lat, lon, elevation) | Local timezone |
|---|---|---|---|---|
| `mosel.csv.gz` | Mosel: Middle Mosel near Bernkastel-Kues | 49.92 N, 7.07 E | 49.90, 7.10, 106 m | Europe/Berlin |
| `cote_dor.csv.gz` | Côte d'Or: near Beaune | 47.03 N, 4.83 E | 47.00, 4.80, 224 m | Europe/Paris |
| `napa.csv.gz` | Napa Valley: Oakville | 38.43 N, 122.40 W | 38.40, −122.40, 45 m | America/Los_Angeles |

Each file covers 13,149 days (1990-01-01 to 2025-12-31) with **no missing values**. It is gzipped CSV, one row per local calendar day. Units are in `meta.json`.

| Column | Meaning | Unit |
|---|---|---|
| `tmin`, `tmax`, `tmean` | 2 m air temperature: daily minimum, maximum, mean | °C |
| `precip` | Precipitation sum | mm |
| `rh_mean`, `rh_min`, `rh_max` | 2 m relative humidity | % |
| `dewpoint` | 2 m dew point, daily mean | °C |
| `wind_mean`, `wind_max` | 10 m wind speed | km/h |
| `sw_rad` | Shortwave radiation sum | MJ/m² |
| `et0` | FAO-56 Penman–Monteith reference evapotranspiration | mm |

## Source and model
- **API:** Open-Meteo Historical Weather API (`archive-api.open-meteo.com/v1/archive`), with `timezone=auto`, so days are local calendar days.
- **Model:** `era5_seamless`. This uses **ERA5-Land** (0.1°, ~9 km) for the variables it provides (temperatures, humidity, dew point) and fills the rest from **ERA5** (0.25°, ~28 km): precipitation, wind, radiation and ET₀. Open-Meteo corrects temperature to the elevation of the requested point with a 90 m terrain model; that is the elevation shown above. `era5_land` alone returns nulls for precipitation, wind, radiation and ET₀ on this API, so it can't be used by itself.

## Licence and attribution (required)
- Weather data by **Open-Meteo.com**, licensed **CC BY 4.0** (https://open-meteo.com/).
- Contains modified **Copernicus Climate Change Service** information (ERA5 and ERA5-Land; Hersbach et al. 2020, *Q. J. R. Meteorol. Soc.* 146:1999–2049; Muñoz-Sabater et al. 2021, *Earth Syst. Sci. Data* 13:4349–4383). Neither the European Commission nor ECMWF is responsible for any use of this information.

The game must show this attribution (e.g. in the credits and the Weather screen).

## Known limitations (read before simulating)
- **Grid scale.** One cell represents a whole Region. The cells sit near the valley floors (106 m, 224 m, 45 m), while real vineyards sit on slopes at 120–400 m. **Every Block must adjust** for elevation (≈ −0.6 °C per 100 m for Tmax; the night lapse is weaker or inverted), slope and aspect (radiation), cold-air drainage and frost pockets, as spec §3.4 requires.
- **Napa runs warm.** Napa Oakville comes out as Winkler Region V; the published classification is Region II–III. See the validation document. A Region-level bias correction is needed before simulating.
- **Radiative frost is badly underestimated.** The April 2021 Burgundy frost shows as −1.7 °C here, against −7 to −8 °C reported in vineyards. Frost-pocket Blocks need an explicit clear, calm-night cooling model.
- **Heavy rain events are underestimated in hilly terrain.** Napa's October 2011 storm shows 32 mm against about 127 mm reported. Timing is right; amounts are too low.
- These are reanalysis values, not station observations. They are consistent with the historical record in timing and ranking of years, but not exact.
- After the archive ends (2025), the Timeline switches to Synthetic weather (ADR 0002). The generator should be calibrated against these files *after* bias correction.
