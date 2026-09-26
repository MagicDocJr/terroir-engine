#!/usr/bin/env bash
# PROTOTYPE — captures every screen at 1920×1080 into shots/.   ./shot.sh [--only inbox,plot]
set -uo pipefail
cd "$(dirname "$0")"
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
[ -d .godot ] || timeout 180 "$GD" --headless --path "$(wslpath -w .)" --import > /dev/null 2>&1 || true
timeout 240 "$GD" --path "$(wslpath -w .)" -- --capture "$@" 2>&1 | grep -E "saved|ERROR|SCRIPT ERROR|at: |Parse Error|Invalid|Cannot" | head -60
