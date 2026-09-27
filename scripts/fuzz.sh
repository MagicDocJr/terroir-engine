#!/usr/bin/env bash
# UI smoke test: presses every button on every screen through a whole Vintage; prints any SCRIPT ERROR.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --fuzz 2>&1 | grep -E "FUZZ|SCRIPT ERROR|at: res" | uniq -c
