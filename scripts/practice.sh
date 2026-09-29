#!/usr/bin/env bash
# Tasting practice harness: pours, answers and marks through the real screens (Tasting practice, Wine Fair, Cellar book),
# leaves mid-pour, checks for double pours and the study record file. Screenshots in game/shots/practice_*.png.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --practice 2>&1 | grep -E "PRACTICE|SCRIPT ERROR|ERROR|at: res|saved"
