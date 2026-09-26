#!/usr/bin/env bash
# PROTOTYPE — copy shared assets into res:// (Godot can't read outside the project).
# The folder gets a .gdignore: everything is loaded at runtime, nothing is imported.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p assets
for d in models models_r2 textures hdri polyhaven_models extra_godot; do
  [ -d "../assets/$d" ] || continue
  rm -rf "assets/$d"; cp -r "../assets/$d" "assets/$d"
done
touch assets/.gdignore
echo "synced assets"
