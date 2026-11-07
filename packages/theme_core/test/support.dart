import 'dart:convert';
import 'dart:io';

import 'package:theme_core/theme_core.dart';

/// Reads a built-in theme file; `dart test` runs from the package directory.
String builtInSource(String id) =>
    File('assets/themes/$id.json').readAsStringSync();

/// The three built-in themes, decoded with the real codec.
List<ThemeDocument> loadBuiltIns() => [
  for (final id in BuiltInIds.all)
    const ThemeCodec().decode(builtInSource(id)).document!,
];

/// Decodes [source] and returns the document, failing loudly on problems.
ThemeDocument decodeOk(String source) {
  final result = const ThemeCodec().decode(source);
  if (!result.isValid) throw StateError('${result.problems}');
  return result.document!;
}

/// A derived-theme file as JSON text.
String derivedJson({
  String id = 'mine',
  String name = 'Mine',
  String base = 'phosphor',
  Map<String, Map<String, String>> overrides = const {
    'normal': {'ink': '#FFFFFF'},
  },
}) => jsonEncode({
  'format': 'bard-theme',
  'schemaVersion': 1,
  'tokenSet': 1,
  'id': id,
  'name': name,
  'brightness': 'dark',
  'base': {'id': base, 'tokenSet': 1},
  'overrides': overrides,
});

/// Decoded built-in as a JSON map, for building invalid variants of it.
Map<String, dynamic> builtInJson(String id) =>
    jsonDecode(builtInSource(id)) as Map<String, dynamic>;

/// A full custom theme copied from [from], with [patch] applied to `normal`.
String fullCopy(
  String id, {
  String from = 'phosphor',
  Map<String, String>? patch,
}) {
  final j = builtInJson(from);
  j['id'] = id;
  j['name'] = id;
  j['copiedFrom'] = from;
  if (patch != null) {
    final variants = j['variants'] as Map<String, dynamic>;
    variants['normal'] = {
      ...variants['normal'] as Map<String, dynamic>,
      ...patch,
    };
  }
  return jsonEncode(j);
}
