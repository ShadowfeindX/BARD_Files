import 'dart:io';

import 'package:bard_tool/diagnostic_pack.dart';

/// Generates the diagnostic pack (example and diagnostic content, never part
/// of the final demo).
///
/// `dart run tool/bin/build_diagnostic_pack.dart GENERATED_CORE OVERLAY OUT
/// [--check]`
///
/// Needs the generated core pack (`bash tool/build_pack.sh`). With `--check`
/// it writes nothing and exits 1 when OUT is missing, stale or has extra
/// files.
void main(List<String> args) {
  final check = args.contains('--check');
  final paths = args.where((a) => a != '--check').toList();
  if (paths.length != 3) {
    stderr.writeln(
      'usage: build_diagnostic_pack <generatedCore> <overlay> <outDir> '
      '[--check]',
    );
    exitCode = 64;
    return;
  }
  final core = Directory(paths[0]);
  final overlay = Directory(paths[1]);
  final target = Directory(paths[2]);
  if (!core.existsSync() || !overlay.existsSync()) {
    stderr.writeln(
      'missing folder: ${core.existsSync() ? overlay.path : core.path} '
      '(run `bash tool/build_pack.sh` first)',
    );
    exitCode = 66;
    return;
  }
  final Map<String, String> files;
  try {
    files = diagnosticPackFiles(core, overlay);
  } on ArgumentError catch (e) {
    stderr.writeln('${e.message}');
    exitCode = 65;
    return;
  } on FormatException catch (e) {
    stderr.writeln('malformed JSON: ${e.message}');
    exitCode = 65;
    return;
  }
  if (check) {
    final problems = checkDiagnosticPack(files, target);
    if (problems.isEmpty) {
      stdout.writeln('${target.path} is current');
      return;
    }
    problems.forEach(stderr.writeln);
    stderr.writeln('Rebuild with: bash tool/build_diagnostic_pack.sh');
    exitCode = 1;
    return;
  }
  writeDiagnosticPack(files, target);
  stdout.writeln('${files.length} files written to ${target.path}');
}
