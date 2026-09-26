@echo off
rem Build and start Terroir Engine (double-click from Windows Explorer).
cd /d "%~dp0"
dotnet build game\TerroirGame.csproj -nologo -v q || pause
start "" "C:\Users\Aleksander\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path game
