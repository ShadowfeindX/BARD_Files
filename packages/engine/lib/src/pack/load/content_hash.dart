import 'dart:convert';

import '../../expr/evaluate.dart' show normalizeNumber;
import 'sha256.dart';

/// Computes a pack's content hash: what an operation pins (02 §Manifest).
///
/// [files] maps each pack-relative path to its decoded JSON. The hash covers
/// every file in path order, each written in a canonical form (object keys
/// sorted, whole numbers as integers, no whitespace), so reformatting a file
/// or reordering its keys does not change the hash. The manifest's own
/// `contentHash` key is left out, so tooling can write the hash into the
/// manifest afterwards.
///
/// Returns `sha256:<64 hex digits>`. Proposed format.
String computeContentHash(Map<String, Object?> files) {
  final buffer = StringBuffer();
  for (final path in files.keys.toList()..sort()) {
    var json = files[path];
    if (path == 'manifest.json' && json is Map<String, Object?>) {
      json = {...json}..remove('contentHash');
    }
    buffer
      ..write(path)
      ..write('\n')
      ..write(canonicalJson(json))
      ..write('\n');
  }
  return 'sha256:${sha256Hex(utf8.encode(buffer.toString()))}';
}

/// [json] encoded with sorted object keys and normalized numbers.
String canonicalJson(Object? json) => jsonEncode(_canonical(json));

Object? _canonical(Object? json) => switch (json) {
  Map<String, Object?>() => {
    for (final key in json.keys.toList()..sort()) key: _canonical(json[key]),
  },
  List<Object?>() => [for (final item in json) _canonical(item)],
  num() => normalizeNumber(json),
  _ => json,
};
