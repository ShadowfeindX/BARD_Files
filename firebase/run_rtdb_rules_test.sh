#!/usr/bin/env bash
# Runs the RTDB rules checks against the Realtime Database emulator.
# Needs: firebase-tools (npm), Java, Dart. Run from Git Bash or any bash shell.
cd "$(dirname "$0")" || exit 1
# Everything here talks to localhost, so proxy variables are cleared; a
# proxy in the environment would otherwise intercept the emulator calls.
for v in $(env | grep -i proxy | cut -d= -f1); do unset "$v"; done
(cd rtdb_rules_test && dart pub get >/dev/null) || exit 1
firebase emulators:exec --only database --project demo-bard \
  "dart run rtdb_rules_test/bin/rtdb_rules_test.dart"
