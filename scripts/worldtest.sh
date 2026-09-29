#!/usr/bin/env bash
# A more immersive world (view3d_test.gd --worldtest): ground cover, yard props and near trees per Region, with checks and
# screenshots in game/shots/3d_world_*.png. Add --checks to skip the screenshots.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 res://src/view3d/view3d_test.tscn -- --worldtest "$@" 2>&1 | tr -d '\r' | grep -E "WORLDTEST|SCRIPT ERROR|at: res|saved"
