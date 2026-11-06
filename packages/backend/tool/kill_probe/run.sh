#!/usr/bin/env bash
# Kill-test for SembastEventStore (V-31): kills a looping writer with SIGKILL
# at random moments and checks the file after every kill.
# Run from the repository root:  bash packages/backend/tool/kill_probe/run.sh [runs]
# Needs only Dart. Verified on Linux and on Windows under Git Bash (process
# kill only: no OS-crash or power-loss test).
set -euo pipefail

runs="${1:-25}"
here="packages/backend/tool/kill_probe"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ext=""
[ "${OS:-}" = "Windows_NT" ] && ext=".exe"
# One native process per side, so the PID that gets killed is the writer.
dart compile exe "$here/writer.dart" -o "$work/writer$ext" >/dev/null
dart compile exe "$here/checker.dart" -o "$work/checker$ext" >/dev/null

fails=0
for i in $(seq 1 "$runs"); do
  "$work/writer$ext" "$work/db" >"$work/out.txt" 2>/dev/null &
  pid=$!
  sleep "$(awk 'BEGIN { srand(); printf "%.2f", 1 + rand() * 2 }')"
  kill -9 "$pid" 2>/dev/null || kill -f "$pid" 2>/dev/null || true
  # Wait up to 10 s for the writer to go; a kill that failed must stop the run
  # instead of hanging it.
  for _ in $(seq 1 100); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "run $i: the writer (pid $pid) survived the kill" >&2
    exit 2
  fi
  last="$(grep DONE "$work/out.txt" | tail -1 | awk '{print $2}')"
  if result="$("$work/checker$ext" "$work/db" "${last:-0}" 2>&1)"; then
    echo "run $i: $result"
  else
    echo "run $i: $result"
    fails=$((fails + 1))
  fi
done
echo "kills=$runs failures=$fails"
[ "$fails" -eq 0 ]
