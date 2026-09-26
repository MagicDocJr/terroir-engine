#!/usr/bin/env bash
# PROTOTYPE — interactive run. F1 vineyard · F2 cellar · F3 hall · F4 dashboard.
# Vineyard: WASD + mouse, Shift run, 1-5 cameras, P weather preset (5 s transition), T +30 min, R rain on/off, F fps.
# Optional: ./run.sh --scene cellar
set -euo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
[ "${NOSYNC:-}" = 1 ] || ./sync_assets.sh
[ -d .godot ] || "$GD" --headless --path "$(wslpath -w .)" --import
"$GD" --path "$(wslpath -w .)" -- "$@"
