import 'dart:io';

import 'package:bard_tool/annotation_stripper.dart';

/// Strips authoring annotations from a rules pack before it ships.
///
/// `dart run tool/bin/strip_annotations.dart <packDir> <outDir> [--check]`
///
/// Without `--check` it replaces `<outDir>` with the stripped `.json` files
/// and prints what changed. With `--check` it writes nothing and exits 1 when
/// `<outDir>` is missing, stale or has extra files (CI uses this to prove the
/// generated pack is current).
///
/// Objects that held only annotations become `null`, the single pending-D
/// signal, and are listed. Keys that look like annotations but are not in the
/// spec's list are listed too, and kept.
void main(List<String> args) {
  final check = args.contains('--check');
  final paths = args.where((a) => a != '--check').toList();
  if (paths.length != 2) {
    stderr.writeln('usage: strip_annotations <packDir> <outDir> [--check]');
    exitCode = 64;
    return;
  }
  final source = Directory(paths[0]);
  if (!source.existsSync()) {
    stderr.writeln('pack folder not found: ${source.path}');
    exitCode = 66;
    return;
  }
  final target = Directory(paths[1]);
  if (check) {
    final List<String> problems;
    try {
      problems = checkPack(source, target);
    } on FormatException catch (e) {
      stderr.writeln('malformed JSON: ${e.message}');
      exitCode = 65;
      return;
    }
    if (problems.isEmpty) {
      stdout.writeln('${target.path} is current');
      return;
    }
    problems.forEach(stderr.writeln);
    stderr.writeln(
      'Rebuild with: dart run tool/bin/strip_annotations.dart '
      '${source.path} ${target.path}',
    );
    exitCode = 1;
    return;
  }
  final Map<String, StripReport> reports;
  try {
    reports = stripPack(source, target);
  } on ArgumentError catch (e) {
    stderr.writeln('${e.message}');
    exitCode = 64;
    return;
  } on FormatException catch (e) {
    stderr.writeln('malformed JSON: ${e.message}');
    exitCode = 65;
    return;
  }
  var removed = 0;
  var pending = 0;
  for (final MapEntry(key: file, value: report) in reports.entries) {
    removed += report.removed;
    pending += report.pending.length;
    for (final path in report.pending) {
      stdout.writeln('$file: $path is pending D (null)');
    }
    for (final path in report.markers) {
      stdout.writeln('$file: $path is an annotation marker and was removed');
    }
    for (final path in report.suspected) {
      stdout.writeln('$file: $path looks like an annotation but was kept');
    }
  }
  stdout.writeln(
    '${reports.length} files, $removed annotation keys removed, '
    '$pending pending-D values set to null',
  );
}
