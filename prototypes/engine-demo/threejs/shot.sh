#!/usr/bin/env bash
# PROTOTYPE — starts Vite, launches Windows Chrome (real GPU, vsync off) with CDP, captures shots.
set -uo pipefail
cd "$(dirname "$0")"
CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
(npx vite --host 127.0.0.1 --port 5173 --strictPort > /tmp/vite-demo.log 2>&1 &) ; sleep 3
"$CHROME" --headless=new --remote-debugging-port=9222 --user-data-dir='C:\Temp\engine-demo-chrome' \
  --disable-gpu-vsync --disable-frame-rate-limit --enable-unsafe-webgpu --enable-features=Vulkan \
  --window-size=1920,1080 --no-first-run about:blank > /dev/null 2>&1 &
for i in $(seq 1 30); do curl -s http://127.0.0.1:9222/json/version > /dev/null && break; sleep 1; done
node shot.mjs "$@"; rc=$?
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -like '*engine-demo-chrome*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" > /dev/null 2>&1
pkill -f "vite --host 127.0.0.1 --port 5173" ; exit $rc
