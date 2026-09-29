# Time-lapse and state-of-the-art visuals — design

Status: approved by the owner in conversation 2026-09-29 ("go ahead"; "as long as stable over 80 fps I'm happy"; "if you spot something that could be improved, feel free to just improve it"). Vocabulary follows `CONTEXT.md`. Look only: nothing here changes a simulated value (ADR 0001).

## 1. Goal

The 3D world looks like a current game and lets the player watch the Vintage unfold.

**Success looks like**
- In the 3D view, Space starts a time-lapse: days pass at a chosen speed, the sun crosses a real sky, clouds follow each day's weather, the canopy grows and colours, and play stops at the same Alerts as on the 2D screens.
- Dawn, dusk and night exist: sunsets, blue hour, stars, lit winery windows and lanterns.
- Vine leaves are textured, variety-shaped leaves (ampelography you can learn from), bunches carry the berry bloom, the ground between rows is living grass, and one wind moves everything.
- **Performance:** every vineyard, estate and hall view keeps a low-1 % frame rate ≥ 80 fps on the owner's PC (`--perf` harnesses). Each feature is measured on and off; a feature that breaks the floor gets a cheaper version or is dropped.

**Non-goals** (backlog): continuous leaf growth between growth-stage meshes (a stage change still swaps the mesh), a moon with phases, snow, player-placed lights.

## 2. Time-lapse

- **Controls (3D view):** Space = play / pause. `[` and `]` step the speed: **Day** (one day ≈ 8 s, full sun cycle 05:00 → 23:00 with night compressed), **Days** (one day per second, afternoon light), **Weeks** (7 days per second, afternoon light). A strip at the top shows the date, the weather, the speed and the key hint. Starting the time-lapse captures the mouse release (the walker can keep walking).
- **Who decides:** the view emits `advance_requested(days)`; the shell calls its existing `advance(days, stop = true, quiet = true)` (the sim decides everything, an Alert stops time) and hands the snapshot back with `apply_snapshot`. While the 3D view is open the shell skips rebuilding the hidden 2D screen on each day (rebuilt when the view closes). An Alert pauses the time-lapse and shows its subject in the strip; Tab opens the Inbox as today.
- **Smooth between days:** the sun position, cloud cover, wetness and wind blend towards the new day's values over ~0.6 s; the autumn colour and berry colour already follow the snapshot every day.
- **Budget:** a day's `Sim.Advance(1)` + snapshot + `apply_snapshot` must not stutter below the fps floor at Weeks speed; the harness measures the frame times during a time-lapse.

## 3. Sky and light

- **Atmosphere:** a sky shader with single-scattering Rayleigh + Mie (a few samples per pixel), driven by the true sun direction (`_solar` from the Plot's latitude, day of year and hour). Sunset reds, blue hour, dark night with stars (hashed, twinkle-free) and a faint Milky-Way band.
- **Clouds:** a 2D cloud layer projected on a dome (fbm noise with domain warp), lit from the sun (forward scattering and dark bases), coverage and darkness from the day's weather (clear 0.1, cloudy 0.7, rain 1.0 dark, fog = low haze), drifting with the day's wind. Rendered in the sky's quarter-resolution pass; the radiance cubemap updates incrementally.
- **Light by hour:** sun colour and energy from elevation (warm and weak near the horizon), a dim cool moonlight directional at night, ambient and exposure following the sky, volumetric sun shafts only at low sun with mist.
- **Night:** the winery's windows glow and the Winery-look lanterns and hall lights switch on after sunset.
- The fixed HDRI panoramas are retired (they only showed one afternoon per weather type).

## 4. Vineyard detail

- **Leaves:** each leaf becomes a textured card: alpha-tested silhouette, veins in a normal map, colour variation, translucency. One texture cell per Variety, shaped by its ampelography (sources in `docs/science/`): Riesling small, round, three-lobed with shallow sinuses; Chardonnay round, almost entire, open petiolar sinus; Pinot Noir small, round, three-lobed; Cabernet Sauvignon deeply five-lobed with overlapping lobes leaving holes. Cards use fewer triangles than today's outline blades. Autumn, disease, water-stress and wetness effects in `leaf.gdshader` stay.
- **Bunches:** fuller cone shape and the waxy bloom (a pale, rough, view-angle sheen) on berries; colour change at véraison stays driven by the snapshot.
- **Grass:** GPU grass blades near the camera (a moving ring around the eye, fading out by ~22 m), dense where the ground is grassed (inter-row cover, verges), none on bare soil or tracks; tinted by the season like the terrain grass.
- **Wind:** a shared gust function (global uniforms) used by leaves, grass, ground cover and near trees, with strength from the day's wind speed.
- **Near trees:** autumn colour in the weeks before leaf fall.

## 5. Improve-as-you-go

The owner asked for opportunistic fixes: anything noticed while working that could be better is fixed if small (with its check) or written into `docs/backlog.md`.

## 6. Testing

- `view3d_test.gd --timelapse`: runs the time-lapse at each speed, checks it pauses on an Alert, measures frame times while days pass, renders dawn / noon / dusk / night and cloudy / rainy skies.
- `--capture3d … --perf` and `--worldtest --perf` before/after every visual feature; low-1 % ≥ 80 fps on all views.
- Screenshot review of every feature; sim tests, fuzz, tasktest, winerylook and capture stay green.

## 7. Documentation

`game/src/view3d/README.md` (time-lapse keys and contract, sky, leaves, grass, wind, perf table); `docs/science/` note for the leaf shapes with sources; backlog follow-ups.
