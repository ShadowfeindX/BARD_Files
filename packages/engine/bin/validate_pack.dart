import 'dart:io';

import 'package:engine/engine.dart';

/// Checks a rules pack folder without running the app (02 §Loading and
/// validation; Proposed).
///
/// `dart run engine:validate_pack <packDir>`
///
/// The pack must be stripped of authoring annotations first
/// (`dart run tool/bin/strip_annotations.dart <source> <packDir>`), because
/// unknown keys are errors. Prints every error and warning, then a summary.
/// Exit code 0 when the pack loads, 1 when it has errors, 64 on bad usage.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run engine:validate_pack <packDir>');
    exitCode = 64;
    return;
  }
  final root = Directory(args.single);
  if (!root.existsSync()) {
    stderr.writeln('pack folder not found: ${root.path}');
    exitCode = 64;
    return;
  }
  final base = root.absolute.path.replaceAll(RegExp(r'[\\/]+$'), '');
  final files = <String, String>{
    for (final entity in root.absolute.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.json'))
        entity.path.substring(base.length + 1).replaceAll(r'\', '/'): entity
            .readAsStringSync(),
  };
  final result = loadPack(files);
  for (final issue in result.issues) {
    stdout.writeln(issue);
  }
  final errors = result.errors.length;
  final pending = result.warnings.where((w) => w.pendingD).length;
  final other = result.warnings.length - pending;
  stdout.writeln(
    '${files.length} files: $errors errors, $pending pending D, '
    '$other other warnings.',
  );
  final pack = result.pack;
  if (pack == null) {
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'OK ${pack.ref.id} ${pack.ref.version} ${pack.ref.contentHash}',
  );
}
