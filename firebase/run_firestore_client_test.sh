#!/usr/bin/env bash
# Runs the Firestore REST client against the Firestore emulator.
# Needs: firebase-tools (npm), Java, Flutter. Run from Git Bash or any bash shell.
#
# On Windows the emulator's java.exe can outlive `firebase emulators:exec`
# (seen with firebase-tools 15.34.0, emulator 1.22.0). This script therefore
# refuses to start when the port is busy, stops a leftover emulator after the
# run, and fails if the port is still busy afterwards.
cd "$(dirname "$0")" || exit 1
# Everything here talks to localhost, so proxy variables are cleared; a
# proxy in the environment would otherwise intercept the emulator calls.
for v in $(env | grep -i proxy | cut -d= -f1); do unset "$v"; done

PORT=8080 # keep in step with firebase.json

# True when something accepts connections on the emulator port.
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; }

# Windows only: the PID listening on the port, if it is a java process.
leftover_java_pid() {
  command -v netstat >/dev/null && command -v tasklist >/dev/null || return 0
  local pid
  pid=$(netstat -ano | tr -d '\r' | grep LISTENING | grep -E "127\.0\.0\.1:$PORT " |
    awk '{print $NF}' | head -n1)
  [ -n "$pid" ] || return 0
  tasklist //FI "PID eq $pid" 2>/dev/null | grep -qi '^java' && echo "$pid"
}

if port_busy; then
  echo "Port $PORT is already in use; stop that process first." >&2
  exit 1
fi

# emulators:exec sets FIRESTORE_EMULATOR_HOST for the command and should stop
# the emulator when the command ends.
firebase emulators:exec --only firestore --project demo-bard \
  "cd ../packages/backend && flutter test test/firestore_emulator_test.dart"
status=$?

# Give a clean shutdown a moment, then stop a leftover emulator.
for _ in 1 2 3 4 5; do port_busy || break; sleep 1; done
if port_busy; then
  pid=$(leftover_java_pid)
  if [ -n "$pid" ]; then
    echo "Emulator java process $pid is still running; stopping it." >&2
    taskkill //PID "$pid" //F >/dev/null
    sleep 2
  fi
fi
if port_busy; then
  echo "Port $PORT is still in use after the run; stop the emulator by hand." >&2
  exit 1
fi
exit $status
