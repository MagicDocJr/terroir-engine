#!/usr/bin/env bash
# Famous-vintages harness: the list and briefing, a scenario game's goals, the scripted player to bottling, the debrief and
# the medal kept in the study record. Screenshots in game/shots/scenarios_*.png.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --scenarios 2>&1 | grep -E "SCENARIOS|LAYOUT|SCRIPT ERROR|ERROR|at: res|saved"
