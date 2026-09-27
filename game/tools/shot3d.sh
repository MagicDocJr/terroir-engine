#!/usr/bin/env bash
# Captures the 3D view screenshots (game/shots/3d_*.png) from real simulated games.
#   game/tools/shot3d.sh                      # all shots
#   game/tools/shot3d.sh mosel_budburst,hall  # a subset
#   game/tools/shot3d.sh all --perf           # also measure fps (vsync off) → game/shots/3d_perf.json
#   game/tools/shot3d.sh hall,cellar --perf --breakdown   # fps with features switched off one by one
# Walk test / LOD probe: see game/src/view3d/README.md (view3d_test.tscn --walktest, --trellis).
# Needs the 3D assets (game/tools/sync_assets3d.sh) and a built C# solution (--build-solutions, done here).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(cd "$HERE/.." && pwd)"
GODOT="${GODOT:-/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe}"
SHOTS="${1:-all}"
shift || true
[[ -f "$GAME/assets3d/models/winery.json" ]] || "$HERE/sync_assets3d.sh"
"$GODOT" --headless --path "$(wslpath -w "$GAME")" --build-solutions --quit >/dev/null 2>&1 || true
ARGS=(--capture3d)
[[ "$SHOTS" != "all" ]] && ARGS+=("$SHOTS")
"$GODOT" --path "$(wslpath -w "$GAME")" --resolution 1920x1080 res://src/view3d/view3d_test.tscn -- "${ARGS[@]}" "$@" 2>&1 \
  | grep -vE "^\s*$|Godot Engine v|Vulkan|OpenGL|^WASAPI" || true
ls -1 "$GAME"/shots/3d_*.png 2>/dev/null
