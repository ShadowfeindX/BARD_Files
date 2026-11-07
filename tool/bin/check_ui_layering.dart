import 'dart:io';

import 'package:bard_tool/ui_layering.dart';

/// Checks that no view or panel under the app's `lib/ui` imports
/// `data/services` (see `tool/lib/ui_layering.dart`).
///
/// Run from the repository root: `dart run tool/bin/check_ui_layering.dart`.
void main() {
  final files = uiLayeringFiles('.');
  final findings = [
    for (final path in files)
      ...checkUiLayering(path, File(path).readAsStringSync()),
  ];
  if (findings.isEmpty) {
    stdout.writeln('UI layering: ${files.length} files OK');
    return;
  }
  findings.forEach(stderr.writeln);
  stderr.writeln(
    'A view reads the episode through its view model, and shared types '
    'through data/models.dart.',
  );
  exitCode = 1;
}
