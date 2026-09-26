#!/usr/bin/env bash
# PROTOTYPE — copy shared assets into res:// (Godot can't read outside the project).
# The folder gets a .gdignore: everything is loaded at runtime, nothing is imported.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p assets
for d in models textures hdri; do
  rm -rf "assets/$d"; cp -r "../assets/$d" "assets/$d"
done
touch assets/.gdignore
echo "synced assets"
