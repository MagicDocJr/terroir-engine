#!/usr/bin/env bash
# PROTOTYPE — opens the UI prototype window. Extra args pass through, e.g. ./run.sh --screen ripeness
set -euo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
[ -d .godot ] || timeout 180 "$GD" --headless --path "$(wslpath -w .)" --import > /dev/null 2>&1 || true
"$GD" --path "$(wslpath -w .)" -- "$@"
