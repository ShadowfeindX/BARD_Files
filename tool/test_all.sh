#!/usr/bin/env bash
# Runs the tests of every workspace member that has a test/ folder.
# Flutter members use `flutter test`, pure-Dart members use `dart test`.
# Run from the repository root: bash tool/test_all.sh
set -euo pipefail

failed=0
for dir in packages/* apps/* tool; do
  [ -d "$dir/test" ] || continue
  echo "== $dir"
  if grep -q 'sdk: flutter' "$dir/pubspec.yaml"; then
    (cd "$dir" && flutter test) || failed=1
  else
    (cd "$dir" && dart test) || failed=1
  fi
done
exit $failed
