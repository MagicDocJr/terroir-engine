#!/usr/bin/env bash
# PROTOTYPE — regenerates all models + layout with headless Windows Blender.
set -euo pipefail
cd "$(dirname "$0")"
BL="/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
mkdir -p assets/models
"$BL" -b --factory-startup -P "$(wslpath -w blender/build_assets.py)" -- "$(wslpath -w assets/models)" 2>&1 \
  | grep -E "exported|layout:|DONE|Error|Traceback|line [0-9]+" || true
