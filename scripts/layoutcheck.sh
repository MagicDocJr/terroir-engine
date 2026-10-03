#!/usr/bin/env bash
# Self-test of the layout check every harness screenshot runs (a broken row must be flagged, the fixed one must not).
"$(dirname "$0")/godot.sh" --resolution 1920x1080 -- --layoutcheck 2>&1 | grep -E "LAYOUTCHECK|SCRIPT ERROR|ERROR"
