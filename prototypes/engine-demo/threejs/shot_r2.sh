#!/usr/bin/env bash
# PROTOTYPE — round 2 capture: starts Vite, launches Windows Chrome (real GPU, vsync off) with CDP, runs shot_r2.mjs.
# Usage: SHOTS=cellar_aisle,dashboard ./shot_r2.sh      (PERF=1 to measure — parent only)
set -uo pipefail
cd "$(dirname "$0")"
CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null
(timeout 1800 npx vite --host 127.0.0.1 --port 5173 --strictPort > /tmp/vite-r2.log 2>&1 &) ; sleep 3
(timeout 1800 "$CHROME" --headless=new --remote-debugging-port=9222 --user-data-dir='C:\Temp\engine-demo-chrome-r2' \
  --disable-gpu-vsync --disable-frame-rate-limit --enable-unsafe-webgpu --enable-features=Vulkan \
  --window-size=1920,1080 --no-first-run about:blank > /dev/null 2>&1 &)
for i in $(seq 1 30); do curl -s http://127.0.0.1:9222/json/version > /dev/null && break; sleep 1; done
timeout 1500 node shot_r2.mjs; rc=$?
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*engine-demo-chrome-r2*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" > /dev/null 2>&1
pkill -f "vite --host 127.0.0.1 --port 5173" 2>/dev/null; exit $rc
