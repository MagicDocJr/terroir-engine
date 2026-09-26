#!/usr/bin/env bash
# Build and start Terroir Engine (from WSL). The game window opens on Windows.
set -e
DIR="$(dirname "$0")"
"$DIR/build-game.sh"
"$DIR/godot.sh" "$@"
