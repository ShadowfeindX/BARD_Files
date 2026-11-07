import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

import 'support.dart';

ThemeResolver resolverWith(Iterable<String> custom) => ThemeResolver(
  builtIns: loadBuiltIns(),
  custom: [for (final s in custom) decodeOk(s)],
);

void main() {
  // full: a custom theme with no base. onBuiltIn: derived from a built-in.
  // deep: derived from onBuiltIn (two links).
  final full = fullCopy('full');
  final onBuiltIn = derivedJson(id: 'on-builtin', base: 'phosphor');
  final deep = derivedJson(id: 'deep', base: 'on-builtin');

  group('eligible bases', () {
    test('built-in, derived-from-built-in and full themes are eligible', () {
      final r = resolverWith([full, onBuiltIn]);
      expect(r.isEligibleBase('manila'), isTrue);
      expect(r.isEligibleBase('full'), isTrue);
      expect(r.isEligibleBase('on-builtin'), isTrue);
      expect(r.isEligibleBase('nope'), isFalse);
    });

    test('a theme with a custom base is not eligible: chains stop at two', () {
      final r = resolverWith([onBuiltIn, deep]);
      expect(r.isEligibleBase('deep'), isFalse);
      expect(r.baseProblem('new', 'deep'), BaseProblem.notEligible);
    });

    test('a missing base theme is reported, not eligible', () {
      final r = resolverWith([onBuiltIn]);
      expect(r.baseProblem('x', 'gone'), BaseProblem.notInstalled);
      expect(r.baseProblem('x', null), isNull);
    });

    test('a theme is never its own base', () {
      final r = resolverWith([onBuiltIn]);
      expect(r.baseProblem('on-builtin', 'on-builtin'), BaseProblem.loop);
    });

    test('a theme with dependants takes only a built-in base or none', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      expect(r.dependantsOf('on-builtin').map((d) => d.id), ['deep']);
      expect(
        r.baseProblem('on-builtin', 'full'),
        BaseProblem.dependantsNeedBuiltIn,
      );
      expect(r.baseProblem('on-builtin', 'manila'), isNull);
      expect(r.baseProblem('on-builtin', null), isNull);
      // Without dependants the same choice is fine.
      expect(r.baseProblem('deep', 'full'), isNull);
    });

    test('the editor lists only eligible bases, built-ins first', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      expect(r.eligibleBasesFor('new').map((d) => d.id), [
        'phosphor',
        'manila',
        'night-desk',
        'full',
        'on-builtin',
      ]);
      expect(r.eligibleBasesFor('on-builtin').map((d) => d.id), [
        'phosphor',
        'manila',
        'night-desk',
      ]);
    });
  });

  group('import', () {
    test('full theme, eligible base, missing base and ineligible base', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      expect(
        r.importBaseOutcome(decodeOk(fullCopy('in-full'))),
        ImportBaseOutcome.noBase,
      );
      expect(
        r.importBaseOutcome(decodeOk(derivedJson(id: 'a', base: 'full'))),
        ImportBaseOutcome.ok,
      );
      expect(
        r.importBaseOutcome(decodeOk(derivedJson(id: 'a', base: 'gone'))),
        ImportBaseOutcome.baseNotInstalled,
      );
      expect(
        r.importBaseOutcome(decodeOk(derivedJson(id: 'a', base: 'deep'))),
        ImportBaseOutcome.offerFlatten,
      );
    });

    test('Flatten on an ineligible base keeps the resolved look', () {
      final r = resolverWith([
        derivedJson(
          id: 'mid',
          base: 'phosphor',
          overrides: {
            'normal': {'desk': '#111111'},
          },
        ),
        deep,
      ]);
      final incoming = decodeOk(
        derivedJson(
          id: 'imp',
          base: 'deep',
          overrides: {
            'normal': {'ink': '#222222'},
          },
        ),
      );
      final flat = r.flattenImport(incoming);
      expect(flat.isDerived, isFalse);
      final after = ThemeResolver(builtIns: loadBuiltIns(), custom: [flat]);
      final before = r.withTheme(incoming);
      for (final v in flat.ownVariants) {
        expect(after.resolve('imp', v).tokens, before.resolve('imp', v).tokens);
      }
      expect(
        after.resolve('imp', ThemeVariant.normal).tokens['ink']!.toHex(),
        '#222222',
      );
    });
  });

  group('Replace', () {
    test('is refused for an ineligible base, a self base, and a derived base '
        'when the theme has dependants', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      // 'deep' is ineligible; replacing 'full' with a theme based on it.
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'full', base: 'deep'))),
        ReplaceRefusal.baseNotEligible,
      );
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'full', base: 'full'))),
        ReplaceRefusal.loop,
      );
      // 'on-builtin' has dependants: a custom base is refused, a built-in ok.
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'on-builtin', base: 'full'))),
        ReplaceRefusal.dependantsNeedBuiltIn,
      );
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'on-builtin', base: 'manila'))),
        isNull,
      );
    });

    test('is allowed for a full theme or an uninstalled base', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      expect(r.checkReplace(decodeOk(fullCopy('on-builtin'))), isNull);
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'deep', base: 'gone'))),
        isNull,
      );
    });

    test('a theme with dependants refuses an uninstalled base too', () {
      final r = resolverWith([full, onBuiltIn, deep]);
      expect(
        r.checkReplace(decodeOk(derivedJson(id: 'on-builtin', base: 'gone'))),
        ReplaceRefusal.dependantsNeedBuiltIn,
      );
      expect(
        r.baseProblem('on-builtin', 'gone'),
        BaseProblem.dependantsNeedBuiltIn,
      );
    });

    test('a theme naming itself as base on import is offered Flatten', () {
      final r = resolverWith([full]);
      expect(
        r.importBaseOutcome(decodeOk(derivedJson(id: 'full', base: 'full'))),
        ImportBaseOutcome.offerFlatten,
      );
      expect(
        r.importBaseOutcome(decodeOk(derivedJson(id: 'new', base: 'new'))),
        ImportBaseOutcome.offerFlatten,
      );
    });

    test(
      'an import whose id has orphaned dependants needs a built-in base',
      () {
        // d derives from b, but b is not installed (deleted with "Delete anyway").
        final r = resolverWith([full, derivedJson(id: 'd', base: 'b')]);
        expect(
          r.importBaseOutcome(decodeOk(derivedJson(id: 'b', base: 'full'))),
          ImportBaseOutcome.offerFlatten,
        );
        expect(
          r.importBaseOutcome(decodeOk(derivedJson(id: 'b', base: 'manila'))),
          ImportBaseOutcome.ok,
        );
        expect(
          r.importBaseOutcome(decodeOk(fullCopy('b'))),
          ImportBaseOutcome.noBase,
        );
      },
    );

    test('a built-in id is never replaced', () {
      expect(
        () =>
            resolverWith([]).checkReplace(decodeOk(derivedJson(id: 'manila'))),
        throwsArgumentError,
      );
      final r = resolverWith([]);
      expect(
        () => r.withTheme(decodeOk(derivedJson(id: 'manila'))),
        throwsArgumentError,
      );
    });
  });

  group('deleting a base', () {
    test('flattening its dependants first leaves their look unchanged', () {
      final r = resolverWith([
        derivedJson(
          id: 'b',
          base: 'phosphor',
          overrides: {
            'normal': {'desk': '#111111'},
          },
        ),
        derivedJson(
          id: 'd1',
          base: 'b',
          overrides: {
            'normal': {'ink': '#222222'},
          },
        ),
        derivedJson(id: 'd2', base: 'b'),
      ]);
      final flat = r.flattenedDependants('b');
      expect(flat.map((d) => d.id), ['d1', 'd2']);
      expect(flat.every((d) => !d.isDerived), isTrue);
      final after = ThemeResolver(
        builtIns: loadBuiltIns(),
        custom: flat, // base 'b' deleted
      );
      for (final id in ['d1', 'd2']) {
        for (final v in ThemeVariant.values) {
          expect(after.resolve(id, v).tokens, r.resolve(id, v).tokens);
        }
        expect(after.resolve(id, ThemeVariant.normal).chainBroken, isFalse);
      }
    });
  });
}
