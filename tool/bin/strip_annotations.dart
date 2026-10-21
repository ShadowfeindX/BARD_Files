import 'dart:io';

import 'package:bard_tool/annotation_stripper.dart';

/// Strips authoring annotations from a rules pack before it ships.
///
/// `dart run tool/bin/strip_annotations.dart <packDir> <outDir>`
///
/// Writes the stripped `.json` files to `<outDir>` and prints what changed.
/// Objects emptied by stripping and annotation-like keys that are not in the
/// spec list are reported so they can be reviewed; neither is removed silently.
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: strip_annotations <packDir> <outDir>');
    exitCode = 64;
    return;
  }
  final source = Directory(args[0]);
  if (!source.existsSync()) {
    stderr.writeln('pack folder not found: ${source.path}');
    exitCode = 66;
    return;
  }
  final reports = stripPack(source, Directory(args[1]));
  var removed = 0;
  for (final MapEntry(key: file, value: report) in reports.entries) {
    removed += report.removed;
    for (final path in report.emptied) {
      stdout.writeln('$file: $path is empty after stripping');
    }
    for (final path in report.suspected) {
      stdout.writeln('$file: $path looks like an annotation but was kept');
    }
  }
  stdout.writeln('${reports.length} files, $removed annotation keys removed');
}
