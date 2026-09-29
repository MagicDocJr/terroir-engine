#!/usr/bin/env bash
# Builds everything the 3D view loads at runtime into game/assets3d/ (gitignored, has a .gdignore so Godot
# never imports it; view3d loads GLB/PNG/JPG/HDR files directly with GLTFDocument / Image.load_from_file).
#
#   game/tools/sync_assets3d.sh            # download CC0 textures/skies/props + build all models (idempotent)
#   game/tools/sync_assets3d.sh fetch      # only the downloads (skips files that already exist)
#   game/tools/sync_assets3d.sh vineyard [misc|einzelpfahl|guyot|cordon]   # only the vineyard models
#   game/tools/sync_assets3d.sh winery     # only the winery models + winery.json
#   game/tools/sync_assets3d.sh groundcover  # only the decimated ground-cover plants (gc_*.glb)
#   game/tools/sync_assets3d.sh trees      # only the near trees (tree3d_*_lod*.glb, thinned scans)
#   game/tools/sync_assets3d.sh leaves     # only the variety leaf atlas (leaf_atlas.png, leaf_normal.png)
#   game/tools/sync_assets3d.sh audio      # only the ambience/one-shot WAVs + audio.json + CREDITS.md
#
# Needs: python3 (WSL), Windows Blender 5.2 LTS (headless). Everything downloaded is CC0 (Poly Haven;
# sounds from BigSoundBank and Wikimedia Commons, credited in assets3d/audio/CREDITS.md).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$(cd "$HERE/.." && pwd)/assets3d"
BLENDER="/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
STEP="${1:-all}"
mkdir -p "$DEST/models" "$DEST/textures" "$DEST/hdri" "$DEST/props" "$DEST/audio"
touch "$DEST/.gdignore"

blender_run() {  # script out_dir [extra args]
  local script="$1" out="$2"; shift 2
  "$BLENDER" -b --factory-startup -P "$(wslpath -w "$HERE/blender/$script")" -- "$(wslpath -w "$out")" "$@" 2>&1 \
    | grep -E "exported|DONE|Error|Traceback|line [0-9]+|layout" || true
}

if [[ "$STEP" == "all" || "$STEP" == "fetch" ]]; then
  python3 "$HERE/fetch_assets3d.py" "$DEST"
fi
if [[ "$STEP" == "all" || "$STEP" == "vineyard" ]]; then
  blender_run build_vineyard.py "$DEST/models" "${2:-}"
fi
if [[ "$STEP" == "all" || "$STEP" == "groundcover" ]]; then
  blender_run build_groundcover.py "$DEST/models" "$(wslpath -w "$DEST/props")"
fi
if [[ "$STEP" == "all" || "$STEP" == "leaves" ]]; then
  blender_run build_leaf_atlas.py "$DEST/models"
fi
if [[ "$STEP" == "all" || "$STEP" == "trees" ]]; then
  blender_run build_trees3d.py "$DEST/models" "$(wslpath -w "$DEST/props")"
fi
if [[ "$STEP" == "all" || "$STEP" == "winery" ]]; then
  blender_run build_winery.py "$DEST/models"
fi
if [[ "$STEP" == "all" || "$STEP" == "audio" ]]; then
  python3 "$HERE/fetch_audio.py" "$DEST/audio"
fi
echo "assets3d: $(find "$DEST" -type f | wc -l) files, $(du -sh "$DEST" | cut -f1) in $DEST"
