#!/usr/bin/env bash
# Learning-core harness: today's session through the real screen (chain, Wine and contrast entries, Confidence, the four-case
# reveal, the recap), the record's Cause states and the Progress view. Screenshots in game/shots/learning_*.png.
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --learning 2>&1 | grep -E "LEARNING|LAYOUT|SCRIPT ERROR|ERROR|at: res|saved"
