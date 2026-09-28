#!/usr/bin/env bash
# 3D staff-task walk-through (view3d_test.gd --tasktest): marker → E → choose → confirm → sim, with close-up screenshots in game/shots/.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 res://src/view3d/view3d_test.tscn -- --tasktest 2>&1 | tr -d '\r' | grep -E "TASKTEST|SCRIPT ERROR|at: res|saved"
