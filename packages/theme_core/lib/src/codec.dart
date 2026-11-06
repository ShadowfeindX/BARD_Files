import 'dart:convert';

import 'colour.dart';
import 'limits.dart';
import 'theme_document.dart';
import 'tokens.dart';
import 'variant.dart';

/// One reason an import was rejected, with the JSON path it concerns.
class ThemeProblem {
  /// Creates a problem.
  const ThemeProblem(this.path, this.message);

  /// JSON path such as `$.variants.normal.desk`.
  final String path;

  /// Human-readable reason.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Result of decoding a theme file: a document, or every problem found.
class ThemeDecodeResult {
  /// Creates a result.
  const ThemeDecodeResult(this.document, this.problems);

  /// The valid document; null whenever [problems] is not empty.
  final ThemeDocument? document;

  /// All problems found in one pass. Empty means valid.
  final List<ThemeProblem> problems;

  /// Whether the file was accepted.
  bool get isValid => document != null;
}

/// Reads and writes theme files and validates imports. Invalid themes are
/// rejected, never repaired (R, T7 c).
class ThemeCodec {
  /// Creates a codec using [limits].
  const ThemeCodec({this.limits = const ThemeLimits()});

  /// Technical safeguards applied on decode.
  final ThemeLimits limits;

  static const _topLevel = {
    'format',
    'schemaVersion',
    'tokenSet',
    'id',
    'name',
    'copiedFrom',
    'brightness',
    'variants',
    'base',
    'overrides',
  };

  /// Decodes [source] (a theme file's text) and validates it in the order of
  /// 07-apps.md, Import and export. Every problem is reported at once.
  ThemeDecodeResult decode(String source) {
    if (utf8.encode(source).length > limits.maxImportBytes) {
      return ThemeDecodeResult(null, [
        ThemeProblem(
          r'$',
          'file is larger than ${limits.maxImportBytes} bytes',
        ),
      ]);
    }
    final Object? parsed;
    try {
      parsed = jsonDecode(source);
    } on FormatException catch (e) {
      return ThemeDecodeResult(null, [
        ThemeProblem(r'$', 'not valid JSON: ${e.message}'),
      ]);
    }
    if (parsed is! Map<String, dynamic>) {
      return const ThemeDecodeResult(null, [
        ThemeProblem(r'$', 'must be a JSON object'),
      ]);
    }
    return _validate(parsed);
  }

  ThemeDecodeResult _validate(Map<String, dynamic> json) {
    final problems = <ThemeProblem>[];
    void fail(String path, String message) =>
        problems.add(ThemeProblem(path, message));

    for (final key in json.keys) {
      if (!_topLevel.contains(key)) fail('\$.$key', 'unknown field');
    }
    if (json['format'] != 'bard-theme') {
      fail(r'$.format', 'must be "bard-theme"');
    }
    final schema = json['schemaVersion'];
    if (schema is! int) {
      fail(r'$.schemaVersion', 'must be an integer');
    } else if (schema > currentSchemaVersion) {
      fail(r'$.schemaVersion', 'made by a newer version; update the app');
    } else if (schema < 1) {
      fail(r'$.schemaVersion', 'unknown version');
    }
    final tokenSet = _tokenSet(json['tokenSet'], r'$.tokenSet', fail);
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      fail(r'$.id', 'must be a non-empty string');
    } else if (id == systemThemeId) {
      fail(r'$.id', '"$systemThemeId" is reserved');
    }
    final name = json['name'] is String
        ? sanitizeName(json['name'] as String)
        : '';
    if (name.isEmpty) fail(r'$.name', 'must not be empty');
    final brightness = switch (json['brightness']) {
      'dark' => ThemeBrightness.dark,
      'light' => ThemeBrightness.light,
      _ => null,
    };
    if (brightness == null) fail(r'$.brightness', 'must be "dark" or "light"');
    final copiedFrom = json['copiedFrom'];
    if (json.containsKey('copiedFrom') &&
        (copiedFrom is! String || copiedFrom.isEmpty)) {
      fail(r'$.copiedFrom', 'must be a non-empty string');
    }

    final hasVariants = json.containsKey('variants');
    final hasDerived =
        json.containsKey('base') || json.containsKey('overrides');
    Map<ThemeVariant, TokenMap>? maps;
    ThemeBase? base;
    if (hasVariants == hasDerived) {
      fail(r'$', 'needs exactly one of "variants" or "base" with "overrides"');
    } else if (hasVariants) {
      maps = _readMaps(
        json['variants'],
        r'$.variants',
        fail,
        requiredTokens: tokenSet == null ? null : tokenNamesOfSet(tokenSet),
      );
    } else {
      if (!json.containsKey('base') || !json.containsKey('overrides')) {
        fail(r'$', 'a derived theme needs both "base" and "overrides"');
      }
      if (json.containsKey('copiedFrom')) {
        fail(r'$.copiedFrom', 'only a full theme has copiedFrom');
      }
      base = _readBase(json['base'], fail);
      maps = _readMaps(json['overrides'], r'$.overrides', fail);
    }

    if (problems.isNotEmpty || maps == null || brightness == null) {
      return ThemeDecodeResult(null, problems);
    }
    final doc = base == null
        ? ThemeDocument.full(
            id: id as String,
            name: name,
            brightness: brightness,
            tokenSet: tokenSet!,
            variants: maps,
            copiedFrom: copiedFrom as String?,
          )
        : ThemeDocument.derived(
            id: id as String,
            name: name,
            brightness: brightness,
            tokenSet: tokenSet!,
            base: base,
            overrides: maps,
          );
    return ThemeDecodeResult(doc, const []);
  }

  int? _tokenSet(
    Object? value,
    String path,
    void Function(String, String) fail,
  ) {
    if (value is! int) {
      fail(path, 'must be an integer');
      return null;
    }
    if (value > currentTokenSet) {
      fail(path, 'made by a newer version; update the app');
      return null;
    }
    if (value < 1) {
      fail(path, 'unknown token set');
      return null;
    }
    return value;
  }

  ThemeBase? _readBase(Object? value, void Function(String, String) fail) {
    if (value is! Map<String, dynamic>) {
      fail(r'$.base', 'must be an object with "id" and "tokenSet"');
      return null;
    }
    for (final key in value.keys) {
      if (key != 'id' && key != 'tokenSet') {
        fail('\$.base.$key', 'unknown field');
      }
    }
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      fail(r'$.base.id', 'must be a non-empty string');
    }
    final set = _tokenSet(value['tokenSet'], r'$.base.tokenSet', fail);
    if (id is! String || id.isEmpty || set == null) return null;
    return ThemeBase(id: id, tokenSet: set);
  }

  /// Reads a variant-to-token-map object. With [requiredTokens] the map is a
  /// full theme: `normal` and every listed token are required.
  Map<ThemeVariant, TokenMap>? _readMaps(
    Object? value,
    String path,
    void Function(String, String) fail, {
    List<String>? requiredTokens,
  }) {
    if (value is! Map<String, dynamic>) {
      fail(path, 'must be an object');
      return null;
    }
    final out = <ThemeVariant, TokenMap>{};
    for (final entry in value.entries) {
      final variant = ThemeVariant.fromJsonKey(entry.key);
      final vPath = '$path.${entry.key}';
      if (variant == null) {
        fail(vPath, 'unknown variant');
        continue;
      }
      final tokens = entry.value;
      if (tokens is! Map<String, dynamic>) {
        fail(vPath, 'must be an object of colours');
        continue;
      }
      final map = <String, ThemeColor>{};
      for (final t in tokens.entries) {
        final token = tokenNamed(t.key);
        final tPath = '$vPath.${t.key}';
        if (token == null) {
          fail(tPath, 'unknown token');
          continue;
        }
        final color = _readColor(t.value, token, tPath, fail);
        if (color != null) map[t.key] = color;
      }
      if (requiredTokens != null) {
        for (final name in requiredTokens) {
          if (!tokens.containsKey(name)) fail('$vPath.$name', 'missing token');
        }
      }
      out[variant] = map;
    }
    if (requiredTokens != null && !value.containsKey('normal')) {
      fail('$path.normal', 'a full theme must provide "normal"');
    }
    return out;
  }

  ThemeColor? _readColor(
    Object? value,
    ThemeToken token,
    String path,
    void Function(String, String) fail,
  ) {
    final color = value is String ? ThemeColor.tryParse(value) : null;
    if (color == null) {
      fail(
        path,
        'must be #RRGGBB'
        '${token.alphaCapable ? ' or #RRGGBBAA' : ''}',
      );
      return null;
    }
    if (color.hasAlpha && !token.alphaCapable) {
      fail(path, 'transparency is not allowed on ${token.name}');
      return null;
    }
    return color;
  }

  /// Trims [name] and removes control and bidirectional-override characters.
  static String sanitizeName(String name) =>
      name.replaceAll(_unsafe, '').trim();

  static final _unsafe = RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
    unicode: true,
  );

  /// Writes [doc] as a theme file. Tokens are in registry order and each
  /// colour keeps the format it was stored in.
  String encode(ThemeDocument doc) {
    final maps = <String, Object?>{
      for (final v in doc.ownVariants) v.jsonKey: _encodeMap(doc.mapFor(v)!),
    };
    final json = <String, Object?>{
      'format': 'bard-theme',
      'schemaVersion': currentSchemaVersion,
      'tokenSet': doc.tokenSet,
      'id': doc.id,
      'name': doc.name,
      'brightness': doc.brightness.name,
      if (doc.copiedFrom != null) 'copiedFrom': doc.copiedFrom,
      if (doc.base case final base?)
        'base': {'id': base.id, 'tokenSet': base.tokenSet},
      doc.isDerived ? 'overrides' : 'variants': maps,
    };
    return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
  }

  Map<String, String> _encodeMap(TokenMap map) => {
    for (final token in themeTokens)
      if (map.containsKey(token.name)) token.name: map[token.name]!.toHex(),
  };
}
