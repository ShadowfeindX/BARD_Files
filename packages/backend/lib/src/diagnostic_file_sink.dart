import 'dart:io';

import 'package:session/session.dart';

/// Appends each [DiagnosticEntry] to a `.jsonl` file as it is recorded, so
/// the diagnostic log survives a crash and is kept per episode beside its
/// store file (R, 2026-11-06). Separate from the game log.
///
/// A write error is swallowed after the first: the diagnostic log must never
/// break play. [failed] says whether one happened.
final class DiagnosticFileSink implements DiagnosticSink {
  /// Appends to [file], creating it and its folder when needed.
  DiagnosticFileSink(this.file) {
    try {
      file.parent.createSync(recursive: true);
    } on FileSystemException {
      failed = true;
    }
  }

  /// The log file.
  final File file;

  /// Whether the folder or a write has failed. The in-memory log is unaffected.
  bool failed = false;

  @override
  void write(DiagnosticEntry entry) {
    if (failed) return;
    try {
      file.writeAsStringSync(
        '${entry.toJsonLine()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException {
      failed = true;
    }
  }
}
