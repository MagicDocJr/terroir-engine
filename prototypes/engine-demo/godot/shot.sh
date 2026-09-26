#!/usr/bin/env bash
# PROTOTYPE — capture: screenshots of the 5 presets + perf json into ../shots/, then quit.
set -euo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
[ "${NOSYNC:-}" = 1 ] || ./sync_assets.sh
[ -d .godot ] || "$GD" --headless --path "$(wslpath -w .)" --import
"$GD" --path "$(wslpath -w .)" -- --shot "$@"
