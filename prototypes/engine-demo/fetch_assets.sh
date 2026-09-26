#!/usr/bin/env bash
# PROTOTYPE — downloads CC0 textures and sky from Poly Haven (polyhaven.com, CC0).
set -euo pipefail
cd "$(dirname "$0")/assets"
mkdir -p textures hdri
PH=https://dl.polyhaven.org/file/ph-assets
get() { [ -s "$2" ] || curl -sfL -o "$2" "$1"; echo "ok $2"; }
get "$PH/HDRIs/hdr/4k/qwantani_afternoon_puresky_4k.hdr" hdri/sky.hdr
for t in rock_ground bark_willow_02 grass_ground; do
  mkdir -p "textures/$t"
  for m in diff nor_gl rough ao; do
    get "$PH/Textures/jpg/2k/$t/${t}_${m}_2k.jpg" "textures/$t/$m.jpg"
  done
done
