#!/usr/bin/env bash
# PROTOTYPE — round 2 capture: one Godot process per shot → ../shots/r2/godot_<shot>.png.
# Usage: ./shot_r2.sh [shot ...]   (default: all 11).  PERF=1 also measures 5 s per shot (don't run in parallel builds).
set -euo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
[ "${NOSYNC:-}" = 1 ] || ./sync_assets.sh
[ -d .godot ] || "$GD" --headless --path "$(wslpath -w .)" --import
mkdir -p ../shots/r2
SHOTS=("$@")
[ ${#SHOTS[@]} -gt 0 ] || SHOTS=(rain_row rain_close mist_valley sunrise_drone dusk_uphill cellar_aisle cellar_heads cellar_fuder hall_overview hall_panel dashboard)
for s in "${SHOTS[@]}"; do
  extra=(); [ "${PERF:-}" = 1 ] && extra+=(--perf)
  timeout 300 "$GD" --path "$(wslpath -w .)" -- --shot2 "$s" "${extra[@]}" 2>&1 | grep -E "saved|perf|ERROR|SCRIPT ERROR|at: |WARNING: .*res://" | head -20 || true
done
