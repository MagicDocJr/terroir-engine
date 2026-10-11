#!/usr/bin/env bash
# Record a harness run as a video with Godot's Movie Maker, then convert it to MP4 with the Windows ffmpeg.
# Usage: scripts/record.sh <harness> [frames-per-screen=36]   (harness: capture, scenarios, practice, learning, fuzz, intro)
# Output: game/shots/video/<harness>.mp4 (gitignored with the shots).
set -e
H="${1:?harness name}"; HOLD="${2:-36}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/game/shots/video"; mkdir -p "$OUT"
AVI="$OUT/$H.avi"; MP4="$OUT/$H.mp4"
# --quit-after: a hard cap of 3 minutes of frames (the recorder films every frame, also while a harness waits for a pour)
"$(dirname "$0")/godot.sh" --resolution 1920x1080 --write-movie "$(wslpath -w "$AVI")" --fixed-fps "${FPS:-30}" --quit-after "${MAX_FRAMES:-5400}" -- "--$H" "--hold=$HOLD" 2>&1 | grep -E "DONE|FAIL|SCRIPT ERROR" || true
FF="$(command -v ffmpeg || command -v ffmpeg.exe)"
# the intro keeps its sound (narration and music); the other harnesses are silent
AUDIO=(-an); [ "$H" = intro ] && AUDIO=(-c:a aac -b:a 192k)   # (FPS=60 scripts/record.sh intro for a smooth flight)
"$FF" -y -loglevel error -i "$(wslpath -w "$AVI")" "${AUDIO[@]}" -c:v libx264 -crf 23 -preset veryfast -pix_fmt yuv420p "$(wslpath -w "$MP4")"
rm -f "$AVI"
echo "video: $MP4 ($(du -h "$MP4" | cut -f1))"
