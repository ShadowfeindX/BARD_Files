import 'dart:io';

import 'package:session/session.dart';

/// Writes a [ReportBundle] into a local folder the tester sends by hand
/// (R, 2026-11-06: no upload in the demo).
///
/// Creates `<parent>/<bundle.folderName>/` and one file per entry of
/// [ReportBundle.files], so each kind of log stays its own file. Returns the
/// folder. Never overwrites: a second report in the same second gets a
/// numeric suffix.
Future<Directory> writeReportBundle(
  ReportBundle bundle,
  Directory parent,
) async {
  await parent.create(recursive: true);
  var folder = Directory(
    '${parent.path}${Platform.pathSeparator}'
    '${bundle.folderName}',
  );
  for (var n = 2; await folder.exists(); n++) {
    folder = Directory(
      '${parent.path}${Platform.pathSeparator}'
      '${bundle.folderName}-$n',
    );
  }
  await folder.create();
  for (final entry in bundle.files.entries) {
    // Names are fixed by the builder; refuse anything that could leave the
    // folder rather than trust it.
    if (entry.key.contains('/') || entry.key.contains(r'\')) {
      throw ArgumentError.value(entry.key, 'file name', 'must be a plain name');
    }
    await File('${folder.path}${Platform.pathSeparator}${entry.key}')
        .writeAsString(entry.value, flush: true);
  }
  return folder;
}
