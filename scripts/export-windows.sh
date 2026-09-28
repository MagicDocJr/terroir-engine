#!/usr/bin/env bash
# Build a standalone Windows version into build/TerroirEngine/ (double-click TerroirEngine.exe; no Godot or dotnet needed).
# Needs the Godot 4.7.2 .NET export templates in %APPDATA%\Godot\export_templates\4.7.2.stable.mono\ and the 3D assets
# (game/tools/sync_assets3d.sh). Also writes build/TerroirEngine.zip.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/TerroirEngine"
mkdir -p "$OUT"
"$ROOT/scripts/build-game.sh" ExportRelease >/dev/null
GD="/mnt/c/Users/Aleksander/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
"$GD" --headless --path "$(wslpath -w "$ROOT/game")" --export-release "Windows Desktop" "$(wslpath -w "$OUT/TerroirEngine.exe")" 2>&1 | grep -Ei "error|export|warn" | grep -v "^$" | tail -n 20 || true
# Godot's export compiles with Windows dotnet, where Application Control blocks Godot's source generators (see
# build-game.sh). Swap in the WSL-built assemblies, which carry the generated GodotPlugins initializer.
cp "$ROOT/game/.godot/mono/temp/bin/ExportRelease/TerroirGame.dll" "$ROOT/game/.godot/mono/temp/bin/ExportRelease/TerroirEngine.Core.dll" "$OUT/data_TerroirGame_windows_x86_64/"
strings "$OUT/data_TerroirGame_windows_x86_64/TerroirGame.dll" | grep -q InitializeFromGameProject || { echo "TerroirGame.dll lacks the GodotPlugins initializer" >&2; exit 1; }
# runtime files the game reads from next to the .exe
cp -r "$ROOT/data" "$OUT/"
cp "$ROOT/CONTEXT.md" "$OUT/"
cp -r "$ROOT/game/assets3d/." "$OUT/assets3d/" 2>/dev/null || mkdir -p "$OUT/assets3d"
rm -f "$OUT/assets3d/.gdignore"
printf 'Terroir Engine\n\nDouble-click TerroirEngine.exe to play. Saves go to %%APPDATA%%\\Godot\\app_userdata\\Terroir Engine\\saves.\nKeep the data, assets3d and data_* folders next to the .exe.\n' > "$OUT/README.txt"
( cd "$ROOT/build" && rm -f TerroirEngine.zip && python3 -c "import shutil; shutil.make_archive('TerroirEngine', 'zip', '.', 'TerroirEngine')" )
du -sh "$OUT" "$ROOT/build/TerroirEngine.zip"
