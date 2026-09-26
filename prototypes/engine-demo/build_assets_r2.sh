#!/usr/bin/env bash
# PROTOTYPE — round-2 shared assets (winery, barrels, tanks, tree impostors, presets, dashboard data).
set -euo pipefail
cd "$(dirname "$0")"
BL="/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
mkdir -p assets/models_r2
"$BL" -b --factory-startup -P "$(wslpath -w blender/build_assets_r2.py)" -- "$(wslpath -w assets/models_r2)" 2>&1 \
  | grep -E "exported|layout_r2|DONE|Error|Traceback|line [0-9]+|Warning: " || true
