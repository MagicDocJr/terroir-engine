#!/usr/bin/env bash
# One command for everything: build, the sim tests, the layout self-test and every harness, in parallel, then a summary
# table, the layout issues found on any screen, and the visual change report against the approved baseline.
# Usage: scripts/check.sh [--approve]   (--approve: after a green run, take these screenshots as the new baseline)
# Logs: $CHECK_LOGS (default /tmp/terroir-check). Exit code 0 only if every step passed and no layout issue was found.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
LOGS="${CHECK_LOGS:-/tmp/terroir-check}"; rm -rf "$LOGS"; mkdir -p "$LOGS"
DOTNET="${DOTNET:-$HOME/.dotnet/dotnet}"
T0=$(date +%s)
step() { local name="$1"; shift; local s=$(date +%s); ( "$@" ) > "$LOGS/$name.log" 2>&1; echo "$? $(( $(date +%s) - s ))" > "$LOGS/$name.status"; }

# 1. build the game (it builds the sim core too) and compile the tests, so nothing builds while things run in parallel
step build bash scripts/build-game.sh
step compile bash -c "cd sim && $DOTNET build -v q"
grep -q "0 Error(s)" "$LOGS/build.log" || { echo "BUILD FAILED — see $LOGS/build.log"; tail -20 "$LOGS/build.log"; exit 1; }

# 2. everything else at once: each harness has its own study record and save folder
G="scripts/godot.sh --resolution 1920x1080 --"
step tests bash -c "cd sim && $DOTNET test --no-build -v q" &
step layoutcheck bash -c "$G --layoutcheck" &
step scenarios bash -c "$G --scenarios" &
step practice bash -c "$G --practice" &
step learning bash -c "$G --learning" &
step capture bash -c "$G --capture --plot mosel-blauschiefer --year 2015" &
step fuzz bash -c "$G --fuzz" &
wait

# 3. verdicts: each step's own success line, any script error, any layout issue
ok_line() { case "$1" in
  tests) grep -aq "Passed!" "$LOGS/tests.log" && ! grep -aq "Failed!" "$LOGS/tests.log" ;;
  layoutcheck) grep -q "LAYOUTCHECK DONE ok=true" "$LOGS/$1.log" ;;
  scenarios) grep -q "SCENARIOS DONE ok=true" "$LOGS/$1.log" ;;
  practice) grep -q "PRACTICE DONE ok=true" "$LOGS/$1.log" ;;
  learning) grep -q "LEARNING DONE ok=true" "$LOGS/$1.log" ;;
  capture) grep -q "SAVE/LOAD ok" "$LOGS/$1.log" ;;
  fuzz) grep -q "FUZZ DONE" "$LOGS/$1.log" ;;
  *) true ;;
esac; }
FAIL=0
printf "\n%-12s %-6s %6s  %s\n" STEP RESULT TIME NOTES
for s in build compile tests layoutcheck scenarios practice learning capture fuzz; do
  read code secs < "$LOGS/$s.status"
  notes=""; result=ok
  if ! ok_line "$s"; then result=FAIL; FAIL=1; fi
  errs=$(grep -c "SCRIPT ERROR" "$LOGS/$s.log" 2>/dev/null); [ "${errs:-0}" -gt 0 ] && { result=FAIL; FAIL=1; notes="$errs script error(s)"; }
  lay=$(grep -c "LAYOUT FAIL" "$LOGS/$s.log" 2>/dev/null); [ "${lay:-0}" -gt 0 ] && { result=FAIL; FAIL=1; notes="$notes $lay layout issue(s)"; }
  [ "$s" = tests ] && notes="$(grep -ao 'Passed: *[0-9]*' "$LOGS/tests.log" | head -1)"
  [ "$s" = capture ] && notes="$notes $(grep -c '^saved' "$LOGS/capture.log") screens"
  printf "%-12s %-6s %5ss  %s\n" "$s" "$result" "$secs" "$notes"
done
grep -h "LAYOUT FAIL" "$LOGS"/*.log | sort -u | head -20

# 4. what changed on screen since the approved baseline
echo
uv run --quiet --with pillow tools/shots_diff.py diff 2>&1 | tail -2
[ "$FAIL" = 0 ] && [ "${1:-}" = "--approve" ] && uv run --quiet --with pillow tools/shots_diff.py approve
echo "TOTAL $(( $(date +%s) - T0 ))s · logs in $LOGS · $([ "$FAIL" = 0 ] && echo ALL GREEN || echo FAILURES)"
exit $FAIL
