#!/usr/bin/env bash
# Runs the Firestore REST client against the Firestore emulator.
# Needs: firebase-tools (npm), Java, Flutter. Run from Git Bash or any bash shell.
cd "$(dirname "$0")" || exit 1
# Everything here talks to localhost, so proxy variables are cleared; a
# proxy in the environment would otherwise intercept the emulator calls.
for v in $(env | grep -i proxy | cut -d= -f1); do unset "$v"; done
# emulators:exec sets FIRESTORE_EMULATOR_HOST for the command and stops the
# emulator when the command ends.
firebase emulators:exec --only firestore --project demo-bard \
  "cd ../packages/backend && flutter test test/firestore_emulator_test.dart"
