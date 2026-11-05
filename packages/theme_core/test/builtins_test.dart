import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

import 'support.dart';

void main() {
  final builtIns = loadBuiltIns();

  test(
    'registry has 42 tokens of set 1, alpha only on highlight/sceneTint',
    () {
      expect(themeTokens, hasLength(42));
      expect({for (final t in themeTokens) t.name}, hasLength(42));
      expect(tokenNamesOfSet(1), hasLength(42));
      expect([
        for (final t in themeTokens)
          if (t.alphaCapable) t.name,
      ], unorderedEquals(['highlight', 'sceneTint']));
    },
  );

  for (final doc in builtIns) {
    group(doc.name, () {
      test('is full, with all four variants of all 42 tokens', () {
        expect(doc.isDerived, isFalse);
        expect(doc.ownVariants, ThemeVariant.values);
        for (final v in ThemeVariant.values) {
          expect(doc.mapFor(v)!.keys, unorderedEquals(tokenNamesOfSet(1)));
        }
      });

      test('encodes back to the exact file text', () {
        expect(const ThemeCodec().encode(doc), builtInSource(doc.id));
      });

      test('windowEdge is the same in every variant and reaches 3:1', () {
        for (final v in ThemeVariant.values) {
          final m = doc.mapFor(v)!;
          for (final surface in ['desk', 'window', 'windowRaised']) {
            expect(
              m['windowEdge']!.contrastWith(m[surface]!),
              greaterThanOrEqualTo(3.0),
              reason: '${doc.id} $v vs $surface',
            );
          }
          expect(
            m['windowEdge'],
            doc.mapFor(ThemeVariant.normal)!['windowEdge'],
          );
        }
      });

      test('chip text reaches 4.5:1 and fills reach 3:1 on window', () {
        for (final v in ThemeVariant.values) {
          final m = doc.mapFor(v)!;
          for (final chip in [
            'success',
            'partial',
            'failure',
            'warning',
            'locked',
          ]) {
            final on = 'on${chip[0].toUpperCase()}${chip.substring(1)}';
            expect(
              m[chip]!.contrastWith(m[on]!),
              greaterThanOrEqualTo(4.5),
              reason: '${doc.id} $v $chip text',
            );
            expect(
              m[chip]!.contrastWith(m['window']!),
              greaterThanOrEqualTo(3.0),
              reason: '${doc.id} $v $chip fill',
            );
          }
        }
      });
    });
  }

  test('windowEdge values are the proposed ones (T11, open)', () {
    String edge(String id) => builtIns
        .firstWhere((d) => d.id == id)
        .mapFor(ThemeVariant.normal)!['windowEdge']!
        .toHex();
    expect(edge('phosphor'), '#C0D8C2');
    expect(edge('manila'), '#5F5348');
    expect(edge('night-desk'), '#B8D8E9');
  });

  test('only the five state chips differ between variants', () {
    for (final doc in builtIns) {
      final normal = doc.mapFor(ThemeVariant.normal)!;
      final chipTokens = {
        for (final c in [
          'success',
          'partial',
          'failure',
          'warning',
          'locked',
        ]) ...[c, 'on${c[0].toUpperCase()}${c.substring(1)}'],
      };
      for (final v in ThemeVariant.values) {
        final m = doc.mapFor(v)!;
        for (final name in tokenNamesOfSet(1)) {
          if (!chipTokens.contains(name)) {
            expect(m[name], normal[name], reason: '${doc.id} $v $name');
          }
        }
      }
    }
  });
}
