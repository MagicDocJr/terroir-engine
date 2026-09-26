#!/usr/bin/env bash
# Run the Godot .NET editor binary (Windows) from WSL against the game project. Usage: scripts/godot.sh [godot args...]
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$GD" --path "$(wslpath -w "$ROOT/game")" "$@"
