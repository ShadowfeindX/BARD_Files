import 'dart:io';

import 'package:bard_tool/spec_wording.dart';

/// Checks that chapters 00 to 08, the developer guide and `docs/ui-kit.md`
/// carry no decision or provenance wording (see `tool/lib/spec_wording.dart`).
///
/// Run from the repository root: `dart run tool/bin/check_spec_wording.dart`.
void main() {
  final files = specWordingFiles('.');
  final findings = [
    for (final path in files)
      ...checkSpecWording(path, File(path).readAsStringSync()),
  ];
  if (findings.isEmpty) {
    stdout.writeln('Spec wording: ${files.length} files OK');
    return;
  }
  findings.forEach(stderr.writeln);
  stderr.writeln(
    'Rulings belong in docs/architecture/decision-record.md; '
    'describe the design only in these files.',
  );
  exitCode = 1;
}
