import 'package:engine/engine.dart';

/// A small pack with values copied from the provisional example pack
/// (library `packs/example-core/`): its nine attributes, creation limits,
/// proficiency tiers, a few skills and the Health and Sanity formulas.
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
