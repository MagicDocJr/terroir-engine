@echo off
rem Build and start Terroir Engine (double-click from Windows Explorer).
rem Builds in WSL: Windows Application Control blocks Godot's source generators in Windows dotnet (see scripts/build-game.sh).
cd /d "%~dp0"
wsl.exe --cd "%CD%" bash scripts/build-game.sh || pause
start "" "C:\Users\Aleksander\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path game
