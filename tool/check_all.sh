#!/usr/bin/env bash
# The same checks CI runs, in the same order. Run from the repository root:
# bash tool/check_all.sh
set -euo pipefail

flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/bin/check_dependency_rules.dart
dart run tool/bin/check_pins.dart
bash tool/test_all.sh
