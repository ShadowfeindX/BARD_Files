import 'dart:convert';
import 'dart:io';

/// Builds the generated diagnostic pack: the shipped example-core pack with a
/// small, labelled PLACEHOLDER scenario laid over it.
///
/// This is example and diagnostic content that R approved as an exception to
/// the no-invented-content rule (CLAUDE.md section 9). It is never part of
/// the final demo. Everything that makes it up lives in
/// `packages/content_core/diagnostic/`, so deleting that folder, this file,
/// its tests and the `build_diagnostic_pack.*` scripts removes it.
///
/// Rules of the overlay:
/// * `manifest.json` replaces the core manifest.
/// * A `strings/<language>.json` that also exists in the core pack is merged
///   into it; a repeated key is an error.
/// * Any other file is added; one that already exists in the core pack is an
///   error, so the overlay can never silently change a rule.
Map<String, String> diagnosticPackFiles(Directory core, Directory overlay) {
  const encoder = JsonEncoder.withIndent('  ');
  final files = _readJsonFiles(core);
  if (files.isEmpty) {
    throw ArgumentError('no pack files found in ${core.path}');
  }
  for (final MapEntry(key: path, value: text) in _readJsonFiles(
    overlay,
  ).entries) {
    if (path == 'manifest.json') {
      files[path] = text;
    } else if (!files.containsKey(path)) {
      files[path] = text;
    } else if (path.startsWith('strings/')) {
      final merged = <String, Object?>{
        ...jsonDecode(files[path]!) as Map<String, Object?>,
      };
      for (final entry in (jsonDecode(text) as Map<String, Object?>).entries) {
        if (entry.key == 'language' && entry.value != merged['language']) {
          throw ArgumentError('$path: language differs from the core file');
        }
        if (entry.key != 'language' && merged.containsKey(entry.key)) {
          throw ArgumentError('$path: "${entry.key}" is already in the core');
        }
        merged[entry.key] = entry.value;
      }
      files[path] = '${encoder.convert(merged)}\n';
    } else {
      throw ArgumentError('$path already exists in the core pack');
    }
  }
  return files;
}

/// Writes [files] under [target], replacing what was there.
void writeDiagnosticPack(Map<String, String> files, Directory target) {
  if (target.existsSync()) target.deleteSync(recursive: true);
  for (final MapEntry(key: path, value: text) in files.entries) {
    File('${target.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
}

/// One message per missing, stale or extra file in [target] compared with
/// [expected]. Empty means the generated pack is current.
List<String> checkDiagnosticPack(
  Map<String, String> expected,
  Directory target,
) {
  if (!target.existsSync()) {
    return ['${target.path} does not exist; run the build step'];
  }
  final actual = _readJsonFiles(target);
  return [
    for (final MapEntry(key: path, value: text) in expected.entries)
      if (!actual.containsKey(path))
        '$path is missing from ${target.path}'
      else if (actual[path] != text)
        '$path is out of date',
    for (final path in actual.keys)
      if (!expected.containsKey(path)) '$path is not in the source',
  ];
}

Map<String, String> _readJsonFiles(Directory dir) {
  if (!dir.existsSync()) return {};
  final root = dir.path.replaceAll(RegExp(r'[\\/]+$'), '');
  final entities = dir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return {
    for (final file in entities)
      if (file.path.endsWith('.json'))
        file.path.substring(root.length + 1).replaceAll(r'\', '/'): file
            .readAsStringSync(),
  };
}
