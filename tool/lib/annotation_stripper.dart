import 'dart:convert';
import 'dart:io';

/// Authoring annotation keys named in
/// `docs/architecture/02-rules-packs.md#authoring-annotations-fixed`.
/// Every key ending in `Note` is also an annotation, and so is every key that
/// starts with `_` (R, 2026-10-21).
const annotationKeys = {'note', 'source', 'openItems', 'placeholder', 'gap'};

/// Whether [key] is an authoring annotation.
bool isAnnotationKey(String key) =>
    annotationKeys.contains(key) || key.endsWith('Note') || key.startsWith('_');

/// Keys whose value is a deprecation record (`since`, `replacedBy`,
/// `removeIn`, `note`; 01-engine.md#deprecation-fixed). Its `note` is data,
/// not an annotation, so records under these keys are left alone.
const _deprecationKeys = {'deprecated', 'deprecatedFields'};

/// What stripping one file removed and left behind.
class StripReport {
  /// JSON paths of objects that held only annotations, such as a
  /// `{placeholder, gap, note}` marker, and became `null`: the single
  /// pending-D signal (R, 2026-10-21).
  final pending = <String>[];

  /// JSON paths of keys that look like annotations but are not in the spec
  /// list, so they were kept. Review these by hand.
  final suspected = <String>[];

  /// JSON paths of annotation keys whose value was an object that held only
  /// annotations (a `_...Placeholder` marker). They are removed with the key,
  /// not turned into `null`; the sibling value already is `null`. Listed so
  /// the build never drops a marker silently.
  final markers = <String>[];

  /// Number of keys removed.
  int removed = 0;
}

final _looksLikeAnnotation = RegExp(
  r'note|placeholder|gap|openitems',
  caseSensitive: false,
);

/// Returns [json] without annotation keys and records what happened in
/// [report]. [path] is the JSON path of [json], used in the report.
///
/// An object that held only annotations becomes `null`, the pending-D
/// marker, and is listed in [StripReport.pending]. An object that was empty to
/// begin with stays `{}`.
Object? stripAnnotations(
  Object? json,
  StripReport report, [
  String path = r'$',
]) {
  if (json is List) {
    return [
      for (var i = 0; i < json.length; i++)
        stripAnnotations(json[i], report, '$path[$i]'),
    ];
  }
  if (json is! Map) return json;
  final result = <String, Object?>{};
  for (final entry in json.entries) {
    final key = entry.key as String;
    if (_deprecationKeys.contains(key)) {
      result[key] = entry.value;
      continue;
    }
    if (isAnnotationKey(key)) {
      report.removed++;
      if (entry.value case Map(isNotEmpty: true)) {
        report.markers.add('$path.$key');
      }
      continue;
    }
    if (_looksLikeAnnotation.hasMatch(key)) report.suspected.add('$path.$key');
    result[key] = stripAnnotations(entry.value, report, '$path.$key');
  }
  if (result.isEmpty && json.isNotEmpty) {
    report.pending.add(path);
    return null;
  }
  return result;
}

/// One stripped `.json` file: the text to ship and what stripping changed.
class StrippedFile {
  /// Creates a result.
  const StrippedFile(this.text, this.report);

  /// The file content to write, two-space indented with a final newline.
  final String text;

  /// What stripping removed and left.
  final StripReport report;
}

/// Strips every `.json` file under [source] in memory. Other files (such as a
/// README) are not shipped. Keys of the result are paths relative to
/// [source], with forward slashes, in sorted order.
Map<String, StrippedFile> stripPackFiles(Directory source) {
  const encoder = JsonEncoder.withIndent('  ');
  // Trailing separators would shift the relative-path offset below.
  final root = source.path.replaceAll(RegExp(r'[\\/]+$'), '');
  final files = <String, StrippedFile>{};
  final entities = source.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entity in entities) {
    if (!entity.path.endsWith('.json')) continue;
    final relative = entity.path
        .substring(root.length + 1)
        .replaceAll(r'\', '/');
    final report = StripReport();
    final Object? decoded;
    try {
      decoded = jsonDecode(entity.readAsStringSync());
    } on FormatException catch (e) {
      throw FormatException('$relative: ${e.message}');
    }
    final stripped = stripAnnotations(decoded, report);
    files[relative] = StrippedFile('${encoder.convert(stripped)}\n', report);
  }
  return files;
}

/// Writes the stripped pack from [source] into [target], replacing what was
/// there, so files removed from the source disappear from the output.
/// Returns one report per file, keyed by path relative to [source].
Map<String, StripReport> stripPack(Directory source, Directory target) {
  final src = source.absolute.path.replaceAll(r'\', '/');
  final dst = target.absolute.path.replaceAll(r'\', '/');
  // The target is deleted first, so it must never be, hold or sit inside the
  // authoring source.
  if (_inside(src, dst) || _inside(dst, src)) {
    throw ArgumentError(
      'output folder ${target.path} overlaps the source ${source.path}',
    );
  }
  final files = stripPackFiles(source);
  if (target.existsSync()) target.deleteSync(recursive: true);
  for (final MapEntry(key: relative, value: file) in files.entries) {
    File('${target.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(file.text);
  }
  return {for (final e in files.entries) e.key: e.value.report};
}

/// Compares [target] with what stripping [source] would write and returns one
/// message per difference: a missing, stale or extra file. Empty means the
/// generated pack is current.
List<String> checkPack(Directory source, Directory target) {
  final expected = stripPackFiles(source);
  if (!target.existsSync()) {
    return ['${target.path} does not exist; run the build step'];
  }
  final root = target.path.replaceAll(RegExp(r'[\\/]+$'), '');
  final actual = <String, String>{};
  for (final entity in target.listSync(recursive: true).whereType<File>()) {
    final relative = entity.path
        .substring(root.length + 1)
        .replaceAll(r'\', '/');
    actual[relative] = entity.readAsStringSync();
  }
  return [
    for (final MapEntry(key: relative, value: file) in expected.entries)
      if (!actual.containsKey(relative))
        '$relative is missing from ${target.path}'
      else if (actual[relative] != file.text)
        '$relative is out of date',
    for (final relative in actual.keys)
      if (!expected.containsKey(relative))
        '$relative is not in the source pack',
  ];
}

/// Whether [inner] is [outer] or lies inside it (forward-slash paths).
bool _inside(String outer, String inner) {
  final a = outer.endsWith('/') ? outer : '$outer/';
  final b = inner.endsWith('/') ? inner : '$inner/';
  return b.startsWith(a);
}
