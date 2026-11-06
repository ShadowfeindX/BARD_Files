import 'dart:convert';

import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

import 'support.dart';

List<String> paths(String source, {ThemeCodec codec = const ThemeCodec()}) => [
  for (final p in codec.decode(source).problems) p.path,
];

void main() {
  group('valid files', () {
    test('a derived theme with sparse overrides decodes and round-trips', () {
      final doc = decodeOk(derivedJson());
      expect(doc.isDerived, isTrue);
      expect(doc.base!.id, 'phosphor');
      expect(doc.mapFor(ThemeVariant.normal)!.keys, ['ink']);
      expect(decodeOk(const ThemeCodec().encode(doc)).id, 'mine');
    });

    test('an empty override map declares the variant', () {
      final doc = decodeOk(derivedJson(overrides: {'highContrast': {}}));
      expect(doc.ownVariants, [ThemeVariant.highContrast]);
    });

    test('alpha on sceneTint and highlight is valid and unchanged', () {
      final doc = decodeOk(
        derivedJson(
          overrides: {
            'normal': {'sceneTint': '#aabbcc80', 'highlight': '#112233FF'},
          },
        ),
      );
      final m = doc.mapFor(ThemeVariant.normal)!;
      expect(m['sceneTint']!.toHex(), '#AABBCC80');
      expect(m['highlight']!.toHex(), '#112233FF');
      final again = decodeOk(const ThemeCodec().encode(doc));
      expect(
        again.mapFor(ThemeVariant.normal)!['sceneTint']!.toHex(),
        '#AABBCC80',
      );
    });

    test('lower-case hex is stored upper-case', () {
      final doc = decodeOk(
        derivedJson(
          overrides: {
            'normal': {'ink': '#abcdef'},
          },
        ),
      );
      expect(doc.mapFor(ThemeVariant.normal)!['ink']!.toHex(), '#ABCDEF');
    });
  });

  group('rejections, each with its JSON path', () {
    test('oversize is checked before parsing', () {
      const codec = ThemeCodec(limits: ThemeLimits(maxImportBytes: 10));
      expect(paths('{"a":"aaaaaaaaaaaaaaaaaaa"}', codec: codec), [r'$']);
    });

    test('bad JSON and non-objects', () {
      expect(paths('{nope'), [r'$']);
      expect(paths('[]'), [r'$']);
    });

    test('wrong format, newer schemaVersion, newer tokenSet', () {
      final j = builtInJson('manila');
      expect(paths(jsonEncode({...j, 'format': 'x'})), [r'$.format']);
      final newer = const ThemeCodec().decode(
        jsonEncode({...j, 'schemaVersion': 2}),
      );
      expect(newer.problems.single.message, contains('newer version'));
      expect(paths(jsonEncode({...j, 'tokenSet': 2})), [r'$.tokenSet']);
      expect(paths(jsonEncode({...j, 'tokenSet': 0})), [r'$.tokenSet']);
    });

    test('newer base.tokenSet', () {
      final j = jsonDecode(derivedJson()) as Map<String, dynamic>;
      j['base'] = {'id': 'phosphor', 'tokenSet': 9};
      expect(paths(jsonEncode(j)), [r'$.base.tokenSet']);
    });

    test('unknown fields, including a URL or script, are rejected', () {
      final j = builtInJson('manila');
      j['url'] = 'https://example.com/x.js';
      j['script'] = 'alert(1)';
      expect(paths(jsonEncode(j)), [r'$.url', r'$.script']);
    });

    test('both forms, or neither', () {
      final j = builtInJson('manila');
      j['base'] = {'id': 'phosphor', 'tokenSet': 1};
      j['overrides'] = <String, dynamic>{};
      expect(paths(jsonEncode(j)), contains(r'$'));
      j
        ..remove('variants')
        ..remove('base')
        ..remove('overrides');
      expect(paths(jsonEncode(j)), [r'$']);
    });

    test('a full theme needs normal and every token of its set', () {
      final j = builtInJson('manila');
      final variants = Map<String, dynamic>.from(j['variants'] as Map);
      variants.remove('normal');
      expect(paths(jsonEncode({...j, 'variants': variants})), [
        r'$.variants.normal',
      ]);
      final high = Map<String, dynamic>.from(variants['highContrast'] as Map)
        ..remove('desk');
      variants['highContrast'] = high;
      expect(paths(jsonEncode({...j, 'variants': variants})), [
        r'$.variants.highContrast.desk',
        r'$.variants.normal',
      ]);
    });

    test('unknown token and unknown variant', () {
      expect(
        paths(
          derivedJson(
            overrides: {
              'normal': {'glow': '#FFFFFF'},
            },
          ),
        ),
        [r'$.overrides.normal.glow'],
      );
      expect(paths(derivedJson(overrides: {'sepia': {}})), [
        r'$.overrides.sepia',
      ]);
    });

    test('empty base.id', () {
      final j = jsonDecode(derivedJson()) as Map<String, dynamic>;
      j['base'] = {'id': '', 'tokenSet': 1};
      expect(paths(jsonEncode(j)), [r'$.base.id']);
    });

    test('non-hex, 3-digit and non-string colours', () {
      for (final bad in ['red', '#fff', '#12345', '#GGGGGG', '#1234567']) {
        expect(
          paths(
            derivedJson(
              overrides: {
                'normal': {'ink': bad},
              },
            ),
          ),
          [r'$.overrides.normal.ink'],
          reason: bad,
        );
      }
      final j = jsonDecode(derivedJson()) as Map<String, dynamic>;
      j['overrides'] = {
        'normal': {'ink': 5},
      };
      expect(paths(jsonEncode(j)), [r'$.overrides.normal.ink']);
    });

    test(
      'alpha on a token that is not alpha-capable is rejected, not stripped',
      () {
        final r = const ThemeCodec().decode(
          derivedJson(
            overrides: {
              'normal': {'desk': '#00000080'},
            },
          ),
        );
        expect(r.isValid, isFalse);
        expect(r.problems.single.path, r'$.overrides.normal.desk');
      },
    );

    test('empty, whitespace-only or control-only names; reserved id', () {
      expect(paths(derivedJson(name: '')), [r'$.name']);
      expect(paths(derivedJson(name: '   ')), [r'$.name']);
      expect(paths(derivedJson(name: '\t\n')), [r'$.name']);
      expect(paths(derivedJson(id: 'system')), [r'$.id']);
      expect(paths(derivedJson(id: '')), [r'$.id']);
    });

    test('every problem is reported in one pass', () {
      final j = jsonDecode(derivedJson()) as Map<String, dynamic>;
      j['name'] = '';
      j['format'] = 'x';
      j['extra'] = 1;
      j['overrides'] = {
        'normal': {'ink': 'bad', 'desk': '#00000080'},
      };
      expect(paths(jsonEncode(j)), hasLength(5));
    });
  });

  group('names', () {
    test('are trimmed and lose control and bidi-override characters', () {
      final rlo = String.fromCharCode(0x202E);
      final bell = String.fromCharCode(7);
      final doc = decodeOk(derivedJson(name: '  A${rlo}B${bell}C  '));
      expect(doc.name, 'ABC');
    });

    test('keep any length', () {
      final long = 'x' * 5000;
      expect(decodeOk(derivedJson(name: long)).name, long);
    });
  });
}
