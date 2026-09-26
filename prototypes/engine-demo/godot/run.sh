#!/usr/bin/env bash
# PROTOTYPE — interactive run (WASD, mouse, 1-5 presets, F fps).
set -euo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
./sync_assets.sh
[ -d .godot ] || "$GD" --headless --path "$(wslpath -w .)" --import
"$GD" --path "$(wslpath -w .)" "$@"
