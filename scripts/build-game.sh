#!/usr/bin/env bash
# Build the C# sim core + Godot bridge with Windows dotnet (output lands in game/.godot/mono/temp/bin/Debug, where Godot loads it).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"/mnt/c/Program Files/dotnet/dotnet.exe" build "$(wslpath -w "$ROOT/game/TerroirGame.csproj")" -nologo -v q 2>&1 | tr -d '\r' | grep -E "error|warn|Warn|Error|Elapsed|Build succeeded" | grep -v "warning CS8" | tail -n 30
