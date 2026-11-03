import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// A minimal valid standalone pack, as decoded JSON per file. Round-tripped
/// through JSON so tests can edit it like `jsonDecode` output.
Map<String, Object?> minimalPack() =>
    (jsonDecode(jsonEncode(_minimalPack)) as Map<String, Object?>);

const _minimalPack = {
  'manifest.json': {
    'id': 'mini',
    'name': 'Mini',
    'version': '1.2.0',
    'engineApi': engineApi,
    'publisher': 'test',
    'tier': 'campaign',
    'requires': <Object?>[],
    'verification': 'pending',
  },
  'attributes.json': {
    'attributes': [
      {'key': 'STR', 'name': 'Strength'},
      {'key': 'LCK', 'name': 'Luck'},
    ],
    'creation': {'points': 4, 'minPerAttribute': 1, 'maxPerAttribute': 3},
  },
  'proficiency.json': {
    'tiers': [
      {'key': 'untrained', 'name': 'Untrained', 'bonus': null},
      {
        'key': 'proficient',
        'name': 'Proficient',
        'bonus': {'type': 'dice', 'count': 1, 'sides': 4, 'explode': false},
      },
    ],
  },
  'skills.json': {
    'categories': [
      {'key': 'physical', 'name': 'Physical'},
    ],
    'skills': [
      {
        'id': 'climb',
        'name': 'Climb',
        'description': 'Up.',
        'category': 'physical',
        'attribute': 'STR',
      },
    ],
  },
  'derived.json': {
    'derived': [
      {
        'key': 'health',
        'name': 'Health',
        'formula': {
          'type': 'op',
          'op': 'mul',
          'args': [
            {'type': 'attr', 'key': 'STR'},
            {'type': 'attr', 'key': 'LCK'},
          ],
        },
      },
    ],
  },
  'difficulty.json': {
    'categories': [
      {'key': 'D', 'name': 'Cat-D', 'dc': 7},
    ],
    'checkRules': {
      'primaryDie': {'type': 'dice', 'count': 1, 'sides': 6, 'explode': true},
      'partialSuccess': {'withinPointsBelowDc': 2},
      'fumble': {'atOrBelowFractionOfDc': 0.25},
      'luckAdvantage': {'extraPrimaryDiceFrom': 'LCK', 'keep': 'bestTotal'},
      'assistance': {
        'gateCategory': 'D',
        'bonus': {
          'type': 'sum',
          'terms': [
            {'type': 'dice', 'count': 1, 'sides': 6, 'explode': false},
            {'type': 'var', 'key': 'helperSkillBonus'},
          ],
        },
      },
    },
  },
};

PackLoadResult load(Map<String, Object?> files) => loadPack({
  for (final MapEntry(:key, :value) in files.entries) key: jsonEncode(value),
});

/// Applies [edit] to the decoded [file] of a fresh minimal pack and loads it.
PackLoadResult loadEdited(String file, void Function(dynamic json) edit) {
  final files = minimalPack();
  edit(files[file]);
  return load(files);
}

Matcher hasError(String file, String path, String fragment) =>
    isA<PackLoadResult>()
        .having((r) => r.ok, 'ok', isFalse)
        .having(
          (r) => r.errors.map((e) => '${e.file}|${e.path}|${e.message}'),
          'errors',
          contains(allOf(startsWith('$file|$path|'), contains(fragment))),
        );

void main() {
  test('the minimal pack loads with no issues', () {
    final result = load(minimalPack());
    expect(result.issues, isEmpty);
    expect(result.pack!.ref.id, 'mini');
    expect(result.pack!.ref.version, '1.2.0');
    expect(result.pack!.manifest!.tier, PackTier.campaign);
  });

  group('files', () {
    test('missing required file', () {
      final files = minimalPack()..remove('derived.json');
      expect(
        load(files),
        hasError('derived.json', '', 'Missing required file'),
      );
    });

    test('unknown file', () {
      final files = minimalPack()..['spells.json'] = <String, Object?>{};
      expect(load(files), hasError('spells.json', '', 'Not a pack file'));
    });

    test('nested folders are not pack files', () {
      final files = minimalPack()..['items/sub/x.json'] = <String, Object?>{};
      expect(load(files), hasError('items/sub/x.json', '', 'Not a pack file'));
    });

    test('invalid JSON', () {
      final files = {
        for (final MapEntry(:key, :value) in minimalPack().entries)
          key: jsonEncode(value),
      };
      files['skills.json'] = '{"skills": [';
      expect(loadPack(files), hasError('skills.json', '', 'Not valid JSON'));
    });

    test('a file that is not an object', () {
      final files = minimalPack()..['derived.json'] = <Object?>[];
      expect(load(files), hasError('derived.json', '', 'JSON object'));
    });
  });

  group('manifest', () {
    test('wrong engine API', () {
      expect(
        loadEdited('manifest.json', (m) => m['engineApi'] = engineApi + 1),
        hasError('manifest.json', 'engineApi', 'targets engine API'),
      );
    });

    test('requires is not supported yet', () {
      expect(
        loadEdited(
          'manifest.json',
          (m) => m['requires'] = [
            {'id': 'core', 'range': '^1.0.0'},
          ],
        ),
        hasError('manifest.json', 'requires', 'not supported yet'),
      );
    });

    test('bad version and tier', () {
      expect(
        loadEdited('manifest.json', (m) => m['version'] = '1.2'),
        hasError('manifest.json', 'version', 'Expected a version'),
      );
      expect(
        loadEdited('manifest.json', (m) => m['tier'] = 'premium'),
        hasError('manifest.json', 'tier', 'Expected one of'),
      );
    });

    test('a written contentHash must match', () {
      final hash = load(minimalPack()).pack!.ref.contentHash;
      expect(
        loadEdited('manifest.json', (m) => m['contentHash'] = hash).ok,
        isTrue,
      );
      expect(
        loadEdited('manifest.json', (m) => m['contentHash'] = 'sha256:00'),
        hasError('manifest.json', 'contentHash', 'Does not match'),
      );
    });
  });

  group('unknown keys are errors', () {
    test('at the top of a file', () {
      expect(
        loadEdited('skills.json', (s) => s['note'] = 'x'),
        hasError('skills.json', 'note', 'Unknown key'),
      );
    });

    test('inside an entry', () {
      expect(
        loadEdited('skills.json', (s) => s['skills'][0]['uses'] = <Object?>[]),
        hasError('skills.json', 'skills[0].uses', 'Unknown key'),
      );
    });

    test('inside an expression', () {
      expect(
        loadEdited(
          'derived.json',
          (d) => d['derived'][0]['formula']['comment'] = 'x',
        ),
        hasError('derived.json', '', 'unknown key "comment"'),
      );
    });
  });

  group('cross-references', () {
    test('skill attribute and category', () {
      expect(
        loadEdited('skills.json', (s) => s['skills'][0]['attribute'] = 'OCC'),
        hasError('skills.json', 'skills[climb].attribute', 'Unknown attribute'),
      );
      expect(
        loadEdited('skills.json', (s) => s['skills'][0]['category'] = 'magic'),
        hasError(
          'skills.json',
          'skills[climb].category',
          'Unknown skill category',
        ),
      );
    });

    test('formula attribute', () {
      expect(
        loadEdited(
          'derived.json',
          (d) => d['derived'][0]['formula']['args'][0]['key'] = 'END',
        ),
        hasError(
          'derived.json',
          'derived[health].formula',
          'Unknown attribute',
        ),
      );
    });

    test('assistance gate category and advantage attribute', () {
      expect(
        loadEdited(
          'difficulty.json',
          (d) => d['checkRules']['assistance']['gateCategory'] = 'Z',
        ),
        hasError('difficulty.json', 'checkRules.assistance.gateCategory', 'Z'),
      );
      expect(
        loadEdited(
          'difficulty.json',
          (d) => d['checkRules']['luckAdvantage']['extraPrimaryDiceFrom'] = 'X',
        ),
        hasError(
          'difficulty.json',
          'checkRules.luckAdvantage.extraPrimaryDiceFrom',
          'Unknown attribute',
        ),
      );
    });

    test('duplicate keys', () {
      expect(
        loadEdited(
          'attributes.json',
          (a) => a['attributes'].add({'key': 'STR', 'name': 'Again'}),
        ),
        hasError('attributes.json', 'attributes', 'Duplicate key "STR"'),
      );
    });

    test('item damage category and NPC threat class', () {
      final files = minimalPack()
        ..['damage.json'] = {
          'categories': [
            {
              'key': 'D',
              'name': 'Cat-D',
              'dice': {
                'type': 'dice',
                'count': 1,
                'sides': 10,
                'explode': false,
              },
              'min': 2,
            },
          ],
        }
        ..['items/gun.json'] = {
          'id': 'gun',
          'name': 'Gun',
          'kind': 'weapon',
          'description': 'x',
          'damageCategory': 'Q',
        }
        ..['npcs/thug.json'] = {
          'id': 'thug',
          'name': 'Thug',
          'description': 'x',
          'threatClass': 'human:E',
          'attributes': null,
        };
      final result = load(files);
      expect(
        result,
        hasError('items/gun.json', 'damageCategory', 'Unknown damage'),
      );
      expect(result, hasError('npcs/thug.json', 'threatClass', 'human:E'));
    });
  });

  group('expressions', () {
    test('a var outside its placement', () {
      expect(
        loadEdited(
          'derived.json',
          (d) =>
              d['derived'][0]['formula'] = {'type': 'var', 'key': 'newScore'},
        ),
        hasError('derived.json', '', 'var "newScore" is not allowed'),
      );
    });

    test('a formula that rolls dice', () {
      expect(
        loadEdited(
          'derived.json',
          (d) => d['derived'][0]['formula'] = {
            'type': 'dice',
            'count': 1,
            'sides': 6,
          },
        ),
        hasError('derived.json', 'derived[0].formula', 'may not roll dice'),
      );
    });
  });

  group('pending D', () {
    test('a null skill attribute is a warning and the pack loads', () {
      final result = loadEdited(
        'skills.json',
        (s) => s['skills'][0]['attribute'] = null,
      );
      expect(result.ok, isTrue);
      expect(result.pack!.skill('climb')!.attribute, isNull);
      expect(result.pack!.pendingPaths, {'skills.json: skills[0].attribute'});
      expect(result.warnings.single.pendingD, isTrue);
    });

    test('dice with no explode ruling are pending D and still load', () {
      final result = loadEdited(
        'proficiency.json',
        (p) => (p['tiers'][1]['bonus'] as Map).remove('explode'),
      );
      expect(result.ok, isTrue);
      expect(result.pack!.pendingPaths, {
        'proficiency.json: tiers[1].bonus.explode',
      });
    });

    test('a pending slot with a value is an error', () {
      expect(
        loadEdited(
          'difficulty.json',
          (d) => d['checkRules']['fumble']['basis'] = 'total',
        ),
        hasError(
          'difficulty.json',
          'checkRules.fumble.basis',
          'pending marker',
        ),
      );
    });

    test('a pending slot holding the marker is a warning', () {
      final result = loadEdited(
        'difficulty.json',
        (d) => d['checkRules']['fumble']['basis'] = null,
      );
      expect(result.ok, isTrue);
      expect(result.pack!.pendingPaths, {
        'difficulty.json: checkRules.fumble.basis',
      });
    });
  });

  group('deprecation (P11)', () {
    Map<String, Object?> record({int removeIn = 2, String? replacedBy}) => {
      'since': '1.1.0',
      'removeIn': removeIn,
      'note': 'Use the other one.',
      'replacedBy': ?replacedBy,
    };

    test('a deprecated entry is a warning', () {
      final result = loadEdited(
        'skills.json',
        (s) => s['skills'][0]['deprecated'] = record(),
      );
      expect(result.ok, isTrue);
      expect(result.warnings.single.path, 'skills[0].deprecated');
      expect(result.warnings.single.message, contains('removed in 2'));
      expect(
        result.pack!.skill('climb')!.deprecated,
        const Deprecation(
          since: '1.1.0',
          removeIn: 2,
          note: 'Use the other one.',
        ),
      );
    });

    test('removeIn must be a later major than the pack', () {
      expect(
        loadEdited(
          'skills.json',
          (s) => s['skills'][0]['deprecated'] = record(removeIn: 1),
        ),
        hasError('skills.json', 'skills[0].deprecated.removeIn', 'later major'),
      );
    });

    test('replacedBy must name an existing entry', () {
      expect(
        loadEdited(
          'skills.json',
          (s) =>
              s['skills'][0]['deprecated'] = record(replacedBy: 'skill:jump'),
        ),
        hasError(
          'skills.json',
          'skills[climb].deprecated',
          'missing skill "jump"',
        ),
      );
    });

    test('deprecatedFields must name a field of the entry', () {
      final ok = loadEdited(
        'skills.json',
        (s) => s['skills'][0]['deprecatedFields'] = {'attribute': record()},
      );
      expect(ok.ok, isTrue);
      expect(ok.pack!.skill('climb')!.deprecatedFields.keys, ['attribute']);
      expect(
        loadEdited(
          'skills.json',
          (s) => s['skills'][0]['deprecatedFields'] = {'uses': record()},
        ),
        hasError(
          'skills.json',
          'skills[0].deprecatedFields.uses',
          'No field "uses"',
        ),
      );
    });

    test('a deprecated field may only be replaced by another field', () {
      final ok = loadEdited(
        'skills.json',
        (s) => s['skills'][0]['deprecatedFields'] = {
          'attribute': record(replacedBy: 'category'),
        },
      );
      expect(ok.ok, isTrue);
      expect(
        loadEdited(
          'skills.json',
          (s) => s['skills'][0]['deprecatedFields'] = {
            'attribute': record(replacedBy: 'governs'),
          },
        ),
        hasError(
          'skills.json',
          'skills[0].deprecatedFields.attribute.replacedBy',
          'No other field "governs"',
        ),
      );
    });

    test('a record needs since, removeIn and note', () {
      expect(
        loadEdited(
          'skills.json',
          (s) => s['skills'][0]['deprecated'] = {'since': '1.1.0'},
        ),
        hasError('skills.json', 'skills[0].deprecated.removeIn', 'Missing'),
      );
    });
  });

  test('numbers outside the web-safe range are errors anywhere', () {
    final files = minimalPack()
      ..['occult.json'] = {'anything': 9007199254740992};
    expect(
      load(files),
      hasError('occult.json', 'anything', 'outside the range'),
    );
  });

  test('cross-checks still run when an entry fails to parse', () {
    final result = loadEdited('skills.json', (s) {
      s['skills'][0]['deprecated'] = {
        'since': '1.1.0',
        'removeIn': 2,
        'note': 'Gone.',
        'replacedBy': 'skill:jump',
      };
      (s['skills'] as List).add({
        'id': 'swim',
        'name': 'Swim',
        'description': 'Wet.',
        'category': 'physical',
        'attribute': 7,
      });
    });
    expect(result, hasError('skills.json', 'skills[1].attribute', ''));
    expect(
      result,
      hasError('skills.json', 'skills[climb].deprecated', 'missing skill'),
    );
  });

  test('every problem is reported, not just the first', () {
    final files = minimalPack();
    (files['skills.json']! as Map)['skills'][0]['attribute'] = 7;
    (files['derived.json']! as Map)['extra'] = true;
    final result = load(files);
    expect(result.errors.length, greaterThanOrEqualTo(2));
  });

  group('random tables (R-B2)', () {
    Map<String, Object?> table({
      Object? dice = const {
        'type': 'dice',
        'count': 1,
        'sides': 6,
        'explode': false,
      },
      List<Object?>? rows,
    }) => {
      'id': 'wild',
      'name': 'Wild',
      'dice': dice,
      'rows':
          rows ??
          [
            {'from': 1, 'to': 3, 'text': 'Low.'},
            {'from': 4, 'to': 6, 'text': 'High.'},
          ],
    };

    PackLoadResult withTable(Map<String, Object?> json) =>
        load(minimalPack()..['tables/wild.json'] = json);

    test('a table that covers every total loads', () {
      final result = withTable(table());
      expect(result.issues, isEmpty);
      final loaded = result.pack!.randomTable('wild')!;
      expect(loaded.dice, Dice(count: 1, sides: 6, explode: false));
      expect(loaded.rowFor(5)!.text, 'High.');
      expect(loaded.lead, isNull);
      final led = withTable({...table(), 'lead': 'It stirs.'});
      expect(led.pack!.randomTable('wild')!.lead, 'It stirs.');
    });

    test('a gap, an overlap and a row out of range are errors', () {
      final result = withTable(
        table(
          rows: [
            {'from': 1, 'to': 2, 'text': 'A'},
            {'from': 2, 'to': 4, 'text': 'B'},
            {'from': 6, 'to': 7, 'text': 'C'},
          ],
        ),
      );
      expect(result, hasError('tables/wild.json', 'rows', 'No row covers 5'));
      expect(
        result,
        hasError('tables/wild.json', 'rows', 'More than one row covers 2'),
      );
      expect(result, hasError('tables/wild.json', 'rows', 'outside 1-6'));
    });

    test('two dice cover their sum range', () {
      final result = withTable(
        table(
          dice: const {
            'type': 'dice',
            'count': 2,
            'sides': 6,
            'explode': false,
          },
          rows: [
            {'from': 2, 'to': 7, 'text': 'A'},
            {'from': 8, 'to': 12, 'text': 'B'},
          ],
        ),
      );
      expect(result.issues, isEmpty);
    });

    test('from above to is an error', () {
      expect(
        withTable(
          table(
            rows: [
              {'from': 4, 'to': 1, 'text': 'A'},
            ],
          ),
        ),
        hasError('tables/wild.json', 'rows[0].to', 'lower than "from"'),
      );
    });

    test('dice must be a plain dice node without explode', () {
      expect(
        withTable(table(dice: const {'type': 'const', 'value': 3})),
        hasError('tables/wild.json', 'dice', 'plain dice node'),
      );
      expect(
        withTable(
          table(
            dice: const {
              'type': 'dice',
              'count': 1,
              'sides': 6,
              'explode': true,
            },
          ),
        ),
        hasError('tables/wild.json', 'dice', 'plain dice node'),
      );
    });

    test('effects must stay empty until they have engine meaning', () {
      expect(
        withTable(
          table(
            rows: [
              {
                'from': 1,
                'to': 6,
                'text': 'A',
                'effects': ['stun'],
              },
            ],
          ),
        ),
        hasError('tables/wild.json', 'rows[0].effects', 'empty list'),
      );
      expect(
        withTable(
          table(
            rows: [
              {'from': 1, 'to': 6, 'text': 'A', 'effects': <Object?>[]},
            ],
          ),
        ).issues,
        isEmpty,
      );
    });

    test('pending dice are a warning; the table loads but is not checked', () {
      final result = withTable(table(dice: null, rows: []));
      expect(result.ok, isTrue);
      expect(result.pack!.randomTable('wild')!.dice, isNull);
      expect(result.pack!.pendingPaths, {'tables/wild.json: dice'});
      expect(result.warnings.single.pendingD, isTrue);
    });

    test('a deprecated table must point at an existing table', () {
      Map<String, Object?> deprecated(String target) => {
        ...table(),
        'deprecated': {
          'since': '1.1.0',
          'removeIn': 2,
          'note': 'Use the other one.',
          'replacedBy': target,
        },
      };
      expect(
        withTable(deprecated('table:missing')),
        hasError('tables/wild.json', 'deprecated', 'missing table "missing"'),
      );
      expect(withTable(deprecated('table:wild')).ok, isTrue);
    });

    test('duplicate table ids', () {
      final files = minimalPack()
        ..['tables/a.json'] = table()
        ..['tables/b.json'] = table();
      expect(load(files), hasError('tables/', 'id', 'Duplicate key "wild"'));
    });
  });
}
