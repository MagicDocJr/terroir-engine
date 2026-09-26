#!/usr/bin/env bash
# Play a scripted game through the real UI and screenshot every screen into game/shots/. Usage: scripts/capture.sh [plot-id] [planting-year]
PLOT="${1:-mosel-blauschiefer}"; YEAR="${2:-2015}"
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --capture --plot "$PLOT" --year "$YEAR" 2>&1 | grep -Ev "^\s*$" | tail -n 60
