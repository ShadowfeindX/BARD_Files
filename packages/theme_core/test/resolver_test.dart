import 'dart:convert';

import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

import 'support.dart';

ThemeResolver resolverWith(
  Iterable<String> customSources, {
  ThemeLimits limits = const ThemeLimits(),
}) => ThemeResolver(
  builtIns: loadBuiltIns(),
  custom: [for (final s in customSources) decodeOk(s)],
  limits: limits,
);

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

String color(
  ThemeResolver r,
  String id,
  String token, [
  ThemeVariant v = ThemeVariant.normal,
]) => r.resolve(id, v).tokens[token]!.toHex();

void main() {
  group('value lookup', () {
    test('a built-in resolves to its own values', () {
      final r = resolverWith([]);
      final t = r.resolve('manila', ThemeVariant.highContrast);
      expect(t.tokens, hasLength(42));
      expect(t.sources.values.toSet(), {TokenSource.own});
      expect(t.chainBroken, isFalse);
      expect(t.outdatedTokens, isEmpty);
    });

    test('own value, then base, then base of base', () {
      final r = resolverWith([
        derivedJson(
          id: 'a',
          base: 'phosphor',
          overrides: {
            'normal': {'ink': '#111111'},
          },
        ),
        derivedJson(
          id: 'b',
          base: 'a',
          overrides: {
            'normal': {'desk': '#222222'},
          },
        ),
        derivedJson(
          id: 'c',
          base: 'b',
          overrides: {
            'normal': {'window': '#333333'},
          },
        ),
      ]);
      final t = r.resolve('c', ThemeVariant.normal);
      expect(t.tokens['window']!.toHex(), '#333333');
      expect(t.tokens['desk']!.toHex(), '#222222');
      expect(t.tokens['ink']!.toHex(), '#111111');
      expect(t.tokens['rule']!.toHex(), '#4F9356'); // Phosphor
      expect(t.sources['window'], TokenSource.own);
      expect(t.sources['ink'], TokenSource.inherited);
      expect(t.outdatedTokens, isEmpty, reason: 'base supplied every token');
    });

    test('an override for a variant the base lacks falls to the fallback', () {
      final r = resolverWith([
        derivedJson(
          id: 'a',
          base: 'phosphor',
          overrides: {
            'normal': {'ink': '#111111'},
          },
        ),
      ]);
      // Phosphor has highContrast; a custom full theme with only normal:
      final j = builtInJson('manila');
      j['id'] = 'only-normal';
      j['name'] = 'n';
      (j['variants'] as Map<String, dynamic>).removeWhere(
        (k, _) => k != 'normal',
      );
      final r2 = resolverWith([
        jsonEncode(j),
        derivedJson(
          id: 'd',
          base: 'only-normal',
          overrides: {
            'highContrast': {'ink': '#010101'},
          },
        ),
      ]);
      expect(r2.availableVariants('d'), {
        ThemeVariant.normal,
        ThemeVariant.highContrast,
      });
      final t = r2.resolve('d', ThemeVariant.highContrast);
      expect(t.tokens['ink']!.toHex(), '#010101');
      // Other tokens: base lacks the variant, so the brightness fallback (dark: Night Desk) fills.
      expect(t.tokens['success']!.toHex(), '#A2B270');
      expect(
        r.resolve('a', ThemeVariant.normal).tokens['ink']!.toHex(),
        '#111111',
      );
    });

    test('a base edit changes the derived result', () {
      final derived = derivedJson(
        id: 'd',
        base: 'copy',
        overrides: {
          'normal': {'ink': '#010101'},
        },
      );
      final before = resolverWith([fullCopy('copy'), derived]);
      final after = resolverWith([
        fullCopy('copy', patch: {'desk': '#ABCDEF'}),
        derived,
      ]);
      expect(color(before, 'd', 'desk'), '#010F02');
      expect(color(after, 'd', 'desk'), '#ABCDEF');
      expect(color(after, 'd', 'ink'), '#010101');
    });

    test('flattening gives the same resolved map as the derived theme', () {
      final r = resolverWith([
        derivedJson(
          id: 'd',
          base: 'manila',
          overrides: {
            'normal': {'ink': '#010101'},
            'highContrast': {},
          },
        ),
      ]);
      final flat = r.flatten('d');
      expect(flat.isDerived, isFalse);
      expect(flat.tokenSet, currentTokenSet);
      expect(flat.copiedFrom, 'manila');
      expect(
        flat.ownVariants,
        r.availableVariants('d').toList()
          ..sort((a, b) => a.index.compareTo(b.index)),
      );
      final flatResolver = ThemeResolver(
        builtIns: loadBuiltIns(),
        custom: [decodeOk(const ThemeCodec().encode(flat))],
      );
      for (final v in flat.ownVariants) {
        expect({
          for (final e in r.resolve('d', v).tokens.entries) e.key: e.value,
        }, flatResolver.resolve('d', v).tokens);
      }
    });
  });

  group('fallback built-in', () {
    test('derived from Phosphor falls back to Phosphor, not Night Desk', () {
      final r = resolverWith([derivedJson(id: 'd', base: 'phosphor')]);
      expect(r.fallbackFor('d').id, 'phosphor');
    });

    test('a duplicate of Phosphor falls back through copiedFrom', () {
      final r = resolverWith([fullCopy('copy')]);
      expect(r.fallbackFor('copy').id, 'phosphor');
      final r2 = resolverWith([
        fullCopy('copy'),
        derivedJson(id: 'on-copy', base: 'copy'),
      ]);
      expect(r2.fallbackFor('on-copy').id, 'phosphor');
    });

    test('brightness is the last resort only', () {
      final j = builtInJson('manila');
      j
        ..['id'] = 'plain'
        ..['name'] = 'plain'
        ..remove('copiedFrom');
      final dark = Map<String, dynamic>.from(j)
        ..['id'] = 'plain-dark'
        ..['brightness'] = 'dark';
      final r = resolverWith([jsonEncode(j), jsonEncode(dark)]);
      expect(r.fallbackFor('plain').id, 'manila');
      expect(r.fallbackFor('plain-dark').id, 'night-desk');
    });

    test('a failing anomaly in a Phosphor-derived theme gets Phosphor\'s', () {
      final r = resolverWith([derivedJson(id: 'd', base: 'missing-one')]);
      // Base missing: anomaly comes from the brightness fallback (dark).
      expect(color(r, 'd', 'anomaly'), '#7FD0B4');
      final r2 = resolverWith([derivedJson(id: 'd2', base: 'phosphor')]);
      expect(color(r2, 'd2', 'anomaly'), '#E58FD0');
    });
  });

  group('chain checks', () {
    test('a two-theme cycle flags both and resolves as base missing', () {
      final r = resolverWith([
        derivedJson(
          id: 'a',
          base: 'b',
          overrides: {
            'normal': {'ink': '#010101'},
          },
        ),
        derivedJson(
          id: 'b',
          base: 'a',
          overrides: {
            'normal': {'desk': '#020202'},
          },
        ),
      ]);
      expect(r.loopMembers, {'a', 'b'});
      final a = r.resolve('a', ThemeVariant.normal);
      expect(a.loop, isTrue);
      expect(a.tokens['ink']!.toHex(), '#010101');
      expect(a.tokens['desk']!.toHex(), isNot('#020202'));
      expect(r.resolve('b', ThemeVariant.normal).loop, isTrue);
      expect(a.outdatedTokens, isEmpty);
    });

    test('a self-referencing theme is a loop', () {
      final r = resolverWith([derivedJson(id: 'a', base: 'a')]);
      expect(r.loopMembers, {'a'});
      expect(r.resolve('a', ThemeVariant.normal).loop, isTrue);
    });

    test('a theme leading into a loop resolves without hanging', () {
      final r = resolverWith([
        derivedJson(id: 'a', base: 'b'),
        derivedJson(id: 'b', base: 'a'),
        derivedJson(id: 'tail', base: 'a'),
      ]);
      expect(r.loopMembers, isNot(contains('tail')));
      expect(r.resolve('tail', ThemeVariant.normal).loop, isTrue);
    });

    test('wouldCreateLoop refuses a cyclic base choice', () {
      final r = resolverWith([
        derivedJson(id: 'a', base: 'phosphor'),
        derivedJson(id: 'b', base: 'a'),
      ]);
      expect(r.wouldCreateLoop('a', 'b'), isTrue);
      expect(r.wouldCreateLoop('a', 'a'), isTrue);
      expect(r.wouldCreateLoop('b', 'manila'), isFalse);
    });

    test('a chain past the depth safeguard is flagged', () {
      final r = resolverWith([
        derivedJson(
          id: 't0',
          base: 'phosphor',
          overrides: {
            'normal': {'ink': '#010101'},
          },
        ),
        for (var i = 1; i <= 5; i++)
          derivedJson(id: 't$i', base: 't${i - 1}', overrides: {}),
      ], limits: const ThemeLimits(maxChainDepth: 3));
      final deep = r.resolve('t5', ThemeVariant.normal);
      expect(deep.depthExceeded, isTrue);
      expect(deep.tokens, hasLength(42));
      expect(r.resolve('t2', ThemeVariant.normal).depthExceeded, isFalse);
    });

    test(
      'a missing base falls back, keeps overrides, and restoring it heals',
      () {
        final derived = derivedJson(
          id: 'd',
          base: 'copy',
          overrides: {
            'normal': {'ink': '#010101'},
            'redGreenSafe': {},
          },
        );
        final without = resolverWith([derived]);
        final t = without.resolve('d', ThemeVariant.normal);
        expect(t.missingBaseId, 'copy');
        expect(t.chainBroken, isTrue);
        expect(t.tokens['ink']!.toHex(), '#010101');
        expect(t.tokens['desk']!.toHex(), '#00111B'); // dark → Night Desk
        expect(
          t.availableVariants,
          ThemeVariant.values.toSet(),
          reason: 'overrides keys plus the fallback built-in variants',
        );
        final with0 = resolverWith([fullCopy('copy'), derived]);
        final healed = with0.resolve('d', ThemeVariant.normal);
        expect(healed.missingBaseId, isNull);
        expect(healed.tokens['desk']!.toHex(), '#010F02');
      },
    );
  });

  group('outdated themes', () {
    test('tokens no theme in the chain supplies come from the fallback', () {
      // A full theme missing a set-1 token cannot be decoded, so build one
      // by decoding a derived-free doc and checking the report path: a
      // custom full theme whose map lacks a token.
      final fullMissing = ThemeDocument.full(
        id: 'old',
        name: 'old',
        brightness: ThemeBrightness.dark,
        tokenSet: 1,
        copiedFrom: 'phosphor',
        variants: {
          ThemeVariant.normal: {
            for (final e
                in loadBuiltIns()[0].mapFor(ThemeVariant.normal)!.entries)
              if (e.key != 'sceneTint') e.key: e.value,
          },
        },
      );
      final r = ThemeResolver(builtIns: loadBuiltIns(), custom: [fullMissing]);
      final t = r.resolve('old', ThemeVariant.normal);
      expect(t.outdatedTokens, ['sceneTint']);
      expect(t.tokens['sceneTint']!.toHex(), '#E58FD0');
      expect(t.outdatedSince, ['token set 1']);
    });

    test('a derived theme whose base supplies every token is not outdated', () {
      final r = resolverWith([derivedJson(id: 'd')]);
      expect(r.resolve('d', ThemeVariant.normal).outdatedTokens, isEmpty);
    });
  });
}
