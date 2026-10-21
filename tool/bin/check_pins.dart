import 'dart:io';

import 'package:bard_tool/pin_check.dart';
import 'package:bard_tool/workspace.dart';

/// Fails when a hosted dependency is not an exact version (F5).
///
/// Run from the repository root: `dart run tool/bin/check_pins.dart`.
void main() {
  final members = readWorkspace('.');
  final problems = checkExactPins(members);
  if (problems.isEmpty) {
    stdout.writeln('Exact pins: ${members.length} members OK');
    return;
  }
  problems.forEach(stderr.writeln);
  exitCode = 1;
}
