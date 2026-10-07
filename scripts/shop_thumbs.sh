#!/usr/bin/env bash
# Render the Shop's item pictures (view3d_test.gd --shopthumbs) into game/shop_thumbs/*.jpg: one per look, on Côte d'Or's
# regional look with only that item changed. Commit the results. THUMB_KEY=walls renders one section only.
export WSLENV="${WSLENV:+$WSLENV:}THUMB_KEY"
"$(dirname "$0")/godot.sh" --resolution 1920x1080 res://src/view3d/view3d_test.tscn -- --shopthumbs 2>&1 | tr -d '\r' | grep -E "SHOPTHUMB|SCRIPT ERROR|at: res|ERROR: [^2-9]"
