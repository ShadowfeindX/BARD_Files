import 'dart:convert';
import 'dart:io';

/// Authoring annotation keys named in
/// `docs/architecture/02-rules-packs.md#authoring-annotations-fixed`.
/// Every key ending in `Note` is also an annotation.
const annotationKeys = {'note', 'source', 'openItems', 'placeholder', 'gap'};

/// Whether [key] is an authoring annotation.
bool isAnnotationKey(String key) =>
    annotationKeys.contains(key) || key.endsWith('Note');

/// Keys whose value is a deprecation record (`since`, `replacedBy`,
/// `removeIn`, `note`; 01-engine.md#deprecation-fixed). Its `note` is data,
/// not an annotation, so records under these keys are left alone.
const _deprecationKeys = {'deprecated', 'deprecatedFields'};

/// What stripping one file removed and left behind.
class StripReport {
  /// JSON paths of objects that became empty because every key was an
  /// annotation, such as a `{placeholder, gap, note}` marker.
  final emptied = <String>[];

  /// JSON paths of keys that look like annotations but are not in the spec
  /// list, so they were kept. Review these by hand.
  final suspected = <String>[];

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
/// An object that held only annotations is kept as `{}` and reported in
/// [StripReport.emptied], so a value that is pending D is never silently
/// dropped.
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
      continue;
    }
    if (_looksLikeAnnotation.hasMatch(key)) report.suspected.add('$path.$key');
    result[key] = stripAnnotations(entry.value, report, '$path.$key');
  }
  if (result.isEmpty && json.isNotEmpty) report.emptied.add(path);
  return result;
}

/// Copies the pack folder [source] to [target] with every `.json` file
/// stripped. Other files (such as a README) are not shipped. Returns one
/// report per file, keyed by path relative to [source].
Map<String, StripReport> stripPack(Directory source, Directory target) {
  final reports = <String, StripReport>{};
  const encoder = JsonEncoder.withIndent('  ');
  // Trailing separators would shift the relative-path offset below.
  final root = source.path.replaceAll(RegExp(r'[\\/]+$'), '');
  for (final entity in source.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
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
    final out = File('${target.path}/$relative')..createSync(recursive: true);
    out.writeAsStringSync('${encoder.convert(stripped)}\n');
    reports[relative] = report;
  }
  return reports;
}
