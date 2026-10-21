import 'package:engine/engine.dart';

/// A small pack with values copied from the provisional example pack
/// (library `packs/example-core/`): its nine attributes, creation limits,
/// proficiency tiers, a few skills, the Health and Sanity formulas, the
/// difficulty categories and check rules, and two conditions.
RulesPack testPack({
  PackRef ref = const PackRef(
    id: 'test-core',
    version: '0.0.1',
    contentHash: 'test',
  ),
}) => RulesPack(
  ref: ref,
  attributes: [
    for (final key in attributeKeys) AttributeDef(key: key, name: key),
  ],
  attributeCreation: const AttributeCreation(
    points: 20,
    minPerAttribute: 1,
    maxPerAttribute: 3,
  ),
  proficiencyTiers: [
    const ProficiencyTier(key: 'untrained', name: 'Untrained'),
    ProficiencyTier(
      key: 'proficient',
      name: 'Proficient',
      bonus: Dice(count: 1, sides: 4),
    ),
    ProficiencyTier(
      key: 'expert',
      name: 'Expert',
      bonus: Dice(count: 1, sides: 6),
    ),
  ],
  skillCategories: const [
    SkillCategory(key: 'physical', name: 'Physical'),
    SkillCategory(key: 'investigation', name: 'Investigation'),
  ],
  skills: const [
    SkillDef(
      id: 'firearms',
      name: 'Firearms',
      description: '',
      category: 'physical',
      attribute: 'DEX',
    ),
    SkillDef(
      id: 'research',
      name: 'Research',
      description: '',
      category: 'investigation',
      attribute: 'INT',
    ),
  ],
  derived: [
    DerivedStat(
      key: 'health',
      name: 'Health',
      formula: Op(OpKind.mul, [Attr('END'), Attr('LCK')]),
    ),
    DerivedStat(
      key: 'sanity',
      name: 'Sanity',
      formula: Op(OpKind.mul, [Attr('WIS'), Attr('LCK')]),
    ),
  ],
  difficultyCategories: const [
    DifficultyCategory(key: 'F', name: 'Cat-F', dc: 3),
    DifficultyCategory(key: 'E', name: 'Cat-E', dc: 5),
    DifficultyCategory(key: 'D', name: 'Cat-D', dc: 7),
    DifficultyCategory(key: 'C', name: 'Cat-C', dc: 10),
    DifficultyCategory(key: 'B', name: 'Cat-B', dc: 13),
    DifficultyCategory(key: 'A', name: 'Cat-A', dc: 17),
    DifficultyCategory(key: 'S', name: 'Cat-S', dc: 21),
  ],
  checkRules: CheckRules(
    primaryDie: Dice(count: 1, sides: 6, explode: true),
    partialSuccessWithin: 2,
    fumbleFractionOfDc: 0.25,
    luckAdvantageAttribute: 'LCK',
    luckAdvantageKeep: 'bestTotal',
    assistanceGateCategory: 'D',
    assistanceBonus: Sum([
      Dice(count: 1, sides: 6),
      Var(VarKeys.helperSkillBonus),
    ]),
  ),
  conditions: const [
    ConditionDef(
      id: 'bleeding',
      name: 'Bleeding',
      kind: ConditionKind.condition,
      description: '',
    ),
    ConditionDef(
      id: 'stunned',
      name: 'Stunned',
      kind: ConditionKind.condition,
      description: '',
    ),
  ],
);

/// The example pack's attribute keys, in pack order.
const attributeKeys = [
  'STR',
  'DEX',
  'END',
  'PER',
  'INT',
  'WIS',
  'CHA',
  'WIL',
  'LCK',
];

/// Valid creation scores: every attribute 2, except LCK 3 and STR 1.
Map<String, int> validScores() => {
  for (final key in attributeKeys) key: 2,
  'STR': 1,
  'LCK': 3,
};
