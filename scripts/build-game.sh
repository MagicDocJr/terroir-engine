#!/usr/bin/env bash
# Build the C# sim core + Godot bridge (output lands in game/.godot/mono/temp/bin/Debug, where Godot loads it).
# Uses the WSL dotnet: Windows Application Control blocks the unsigned Godot.SourceGenerators.dll inside Windows csc
# (warning CS8034), which silently drops the generated script bindings and breaks exported builds.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
"$HOME/.dotnet/dotnet" build "$ROOT/game/TerroirGame.csproj" -nologo -v q -c "$CONFIG" -p:GodotTargetPlatform=windows 2>&1 | grep -E "error|warn|Warn|Error|Elapsed|Build succeeded" | grep -v "CS0169" | tail -n 30
