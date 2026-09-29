#!/usr/bin/env bash
# The Winery look in 3D (view3d_test.gd --winerylook): each Region's default and two mixes rendered to game/shots/3d_look_*.png,
# plus checks (a choice before the first open, unknown keys, restyling without duplicates). Add --perf for the frame-time check.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 res://src/view3d/view3d_test.tscn -- --winerylook "$@" 2>&1 | tr -d '\r' | grep -E "WINERYLOOK|SCRIPT ERROR|at: res|saved|ERROR: [^2-9]"
