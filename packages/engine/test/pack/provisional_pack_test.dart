@TestOn('vm')
library;

import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '../support/provisional_pack.dart';

void main() {
  late PackLoadResult result;
  late RulesPack pack;

  setUpAll(() {
    result = loadPack(provisionalPackFiles());
    pack = result.pack!;
  });

  test('the provisional pack loads with no errors', () {
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(result.ok, isTrue);
  });

  test('every pending-D value is a warning and listed on the pack', () {
    expect(pack.pendingPaths, {
      'advancement.json: costs[4].effect',
      'advancement.json: costs[5].repeat',
      'advancement.json: costs[6].repeat',
      'advancement.json: costs[7].repeat',
      'damage.json: categories[0].min',
      'damage.json: categories[7].dice',
      'derived.json: derived[5].armorModifierAdded',
      'difficulty.json: checkRules.fumble.basis',
      'difficulty.json: checkRules.luckAdvantage.grantedBy',
      'difficulty.json: checkRules.assistance.cap',
      'disorders.json: rollDie',
      'items/armor_vest.json: drModifier',
      'items/pistol_cat_d.json: rangeBands',
      'npcs/cult_footsoldier.json: attributes',
      'occult.json',
      'sanity_events.json: valueChoice',
      'sanity_events.json: fumble',
      'skills.json: skills[9].attribute',
      'skills.json: skills[12].category',
      'threats.json: perClassNumbersForAttackAndDefense',
      'vehicles.json: performance[7].drivingModifier',
      'vehicles.json: durability[7].hp',
      // Dice whose explode flag is not ruled (G3).
      'proficiency.json: tiers[1].bonus.explode',
      'proficiency.json: tiers[2].bonus.explode',
      'difficulty.json: checkRules.assistance.bonus.terms[0].explode',
      'damage.json: categories[0].dice.explode',
      'damage.json: categories[1].dice.explode',
      'damage.json: categories[2].dice.explode',
      'damage.json: categories[3].dice.explode',
      'damage.json: categories[4].dice.explode',
      'damage.json: categories[5].dice.explode',
      'damage.json: categories[6].dice.explode',
      'advancement.json: costs[0].grants.explode',
      'advancement.json: costs[1].grants.explode',
      'threats.json: supernatural[0].damage.dice.explode',
      'threats.json: supernatural[1].damage.dice.explode',
      'threats.json: supernatural[2].damage.dice.explode',
    });
    expect(
      result.warnings.where((w) => w.pendingD).length,
      pack.pendingPaths.length,
    );
  });

  test(
    'the illustrative deprecated skill is a warning naming its successor',
    () {
      final warning = result.warnings.singleWhere(
        (w) => w.path == 'skills[13].deprecated',
      );
      expect(warning.message, contains('removed in 1'));
      expect(warning.message, contains('skill:persuasion'));
    },
  );

  test('values come through as the pack wrote them', () {
    expect(pack.ref.id, 'example-core');
    expect(pack.manifest!.tier, PackTier.core);
    expect(pack.attributes.map((a) => a.key), [
      'STR', 'DEX', 'END', 'PER', 'INT', 'WIS', 'CHA', 'WIL', 'LCK', //
    ]);
    expect(pack.attributeCreation.points, 20);
    expect(pack.advancementCap, 10);
    expect(pack.proficiencyCreation!.counts.asMap(), {
      'proficient': 3,
      'expert': 1,
    });
    expect(pack.proficiencyTier('expert')!.bonus, Dice(count: 1, sides: 6));
    expect(pack.skill('insight')!.attribute, isNull);
    expect(pack.skill('mind_shielding')!.category, isNull);
    expect(pack.difficultyCategories.map((c) => '${c.key}=${c.dc}'), [
      'F=3',
      'E=5',
      'D=7',
      'C=10',
      'B=13',
      'A=17',
      'S=21',
      'OMEGA=25',
    ]);
    final rules = pack.checkRules!;
    expect(rules.primaryDie, Dice(count: 1, sides: 6, explode: true));
    expect(rules.partialSuccessWithin, 2);
    expect(
      evaluate(
        rules.assistanceBonus,
        vars: {VarKeys.helperSkillBonus: 2},
        rng: ScriptedRng([6]),
      ).value,
      8,
    );
    expect(pack.items.map((i) => i.id), ['armor_vest', 'pistol_cat_d']);
    expect(pack.npcs.single.threatClass, 'human:E');
    expect(pack.strings['en']!.entries['category.OMEGA'], 'Cat-Ω');
    expect(pack.occultPending, isA<Map<String, Object?>>());
  });

  test('Health and Sanity formulas evaluate (F1)', () {
    final scores = {'END': 3, 'WIS': 2, 'LCK': 3};
    expect(
      evaluateFormula(pack.derivedStat('health')!.formula, attributes: scores),
      9,
    );
    expect(
      evaluateFormula(pack.derivedStat('sanity')!.formula, attributes: scores),
      6,
    );
  });

  test('attribute purchase XP uses var(newScore)', () {
    final cost = pack.advancementCosts.singleWhere(
      (c) => c.key == 'attribute_plus_one',
    );
    expect(evaluateFormula(cost.xp, vars: {VarKeys.newScore: 4}), 40);
    final fixed = pack.advancementCosts.first;
    expect(evaluateFormula(fixed.xp), 10);
  });

  test('the content hash ignores formatting and key order', () {
    final files = provisionalPackFiles();
    final reformatted = {
      for (final MapEntry(:key, :value) in files.entries)
        key: const JsonEncoder.withIndent('    ')
            .convert(_reverseKeys(jsonDecode(value))),
    };
    expect(pack.ref.contentHash, startsWith('sha256:'));
    expect(loadPack(reformatted).pack!.ref.contentHash, pack.ref.contentHash);
  });

  test('a changed value changes the hash', () {
    final files = provisionalPackFiles();
    files['difficulty.json'] = files['difficulty.json']!.replaceFirst(
      '"dc":21',
      '"dc":22',
    );
    expect(loadPack(files).pack!.ref.contentHash, isNot(pack.ref.contentHash));
  });

  test('an engine runs on the loaded pack', () {
    final engine = Engine(pack);
    final ids = SequentialIdSource();
    final started = engine.replay(const OperationState.initial(), [
      ...(engine.decide(
        const OperationState.initial(),
        const StartOperation(operationId: 'op'),
        ScriptedRng([]),
        ids,
      ) as Accepted).events,
    ]);
    expect(started.meta!.packRef, pack.ref);
    final decision = engine.decide(
      started,
      CreateAgent(
        name: 'Hall',
        attributes: {for (final a in pack.attributes) a.key: 2},
        skills: {'firearms': 'proficient', 'research': 'expert'},
      ),
      ScriptedRng([]),
      ids,
    );
    expect(decision, isA<Accepted>());
  });
}

Object? _reverseKeys(Object? json) => switch (json) {
  Map<String, Object?>() => {
    for (final key in json.keys.toList().reversed) key: _reverseKeys(json[key]),
  },
  List<Object?>() => [for (final item in json) _reverseKeys(item)],
  _ => json,
};
