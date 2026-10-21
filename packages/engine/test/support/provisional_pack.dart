import 'dart:convert';
import 'dart:io';

/// The provisional pack in `packages/content_core/assets/example-core/`,
/// stripped the way it will ship, as `loadPack` input.
///
/// Stripping mirrors `tool/lib/annotation_stripper.dart` (the spec's
/// annotation keys and any key ending in `Note`; deprecation records kept),
/// plus the stripper change recommended to R and still awaiting a ruling: a
/// key starting with `_` is an annotation, and an object that held only
/// annotations becomes `null`, the pending-D marker. When R rules, this
/// helper follows the stripper.
Map<String, String> provisionalPackFiles() {
  final root = Directory('../content_core/assets/example-core');
  final files = <String, String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll(r'\', '/');
    final json = jsonDecode(entity.readAsStringSync());
    files[relative] = jsonEncode(_strip(json));
  }
  return files;
}

const _annotationKeys = {'note', 'source', 'openItems', 'placeholder', 'gap'};
const _deprecationKeys = {'deprecated', 'deprecatedFields'};

bool _isAnnotation(String key) =>
    _annotationKeys.contains(key) ||
    key.endsWith('Note') ||
    key.startsWith('_');

Object? _strip(Object? json) {
  if (json is List) return [for (final item in json) _strip(item)];
  if (json is! Map<String, Object?>) return json;
  final result = <String, Object?>{};
  for (final MapEntry(:key, :value) in json.entries) {
    if (_deprecationKeys.contains(key)) {
      result[key] = value;
    } else if (!_isAnnotation(key)) {
      result[key] = _strip(value);
    }
  }
  return result.isEmpty && json.isNotEmpty ? null : result;
}
