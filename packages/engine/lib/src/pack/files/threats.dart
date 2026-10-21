/// The pack file `threats.json`: human and supernatural threat classes.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// A human adversary class (rulebook §10).
final class HumanThreatClass {
  /// Creates a [HumanThreatClass].
  const HumanThreatClass({
    required this.classKey,
    required this.health,
    this.healthOpenEnded = false,
    required this.damageReduction,
    required this.skillsText,
    required this.gearText,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Class key.
  final String classKey;

  /// Health.
  final int health;

  /// Whether health is a floor.
  final bool healthOpenEnded;

  /// Damage reduction.
  final int damageReduction;

  /// Skills, as printed.
  final String skillsText;

  /// Gear, as printed.
  final String gearText;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is HumanThreatClass &&
      other.classKey == classKey &&
      other.health == health &&
      other.healthOpenEnded == healthOpenEnded &&
      other.damageReduction == damageReduction &&
      other.skillsText == skillsText &&
      other.gearText == gearText &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    HumanThreatClass,
    classKey,
    health,
    healthOpenEnded,
    damageReduction,
    skillsText,
    gearText,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'HumanThreatClass($classKey, $health, $healthOpenEnded)';
}

/// The damage a supernatural class deals.
final class ThreatDamage {
  /// Creates a [ThreatDamage].
  const ThreatDamage({
    required this.category,
    this.dice,
    this.min,
    this.openEnded = false,
  });

  /// Damage category key.
  final String category;

  /// Damage dice.
  final Expr? dice;

  /// Minimum damage.
  final int? min;

  /// Whether the damage is open-ended.
  final bool openEnded;

  @override
  bool operator ==(Object other) =>
      other is ThreatDamage &&
      other.category == category &&
      other.dice == dice &&
      other.min == min &&
      other.openEnded == openEnded;

  @override
  int get hashCode => Object.hash(ThreatDamage, category, dice, min, openEnded);

  @override
  String toString() => 'ThreatDamage($category, $dice, $min)';
}

/// A supernatural adversary class (rulebook §10).
final class SupernaturalThreatClass {
  /// Creates a [SupernaturalThreatClass].
  const SupernaturalThreatClass({
    required this.classKey,
    required this.health,
    this.healthOpenEnded = false,
    required this.damageReduction,
    this.damageReductionOpenEnded = false,
    required this.damage,
    required this.sanityLoss,
    this.sanityLossOpenEnded = false,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Class key.
  final String classKey;

  /// Health.
  final int health;

  /// Whether health is a floor.
  final bool healthOpenEnded;

  /// Damage reduction.
  final int damageReduction;

  /// Whether damage reduction is a floor.
  final bool damageReductionOpenEnded;

  /// Damage dealt.
  final ThreatDamage damage;

  /// Sanity lost on encounter.
  final int sanityLoss;

  /// Whether the loss is a floor.
  final bool sanityLossOpenEnded;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is SupernaturalThreatClass &&
      other.classKey == classKey &&
      other.health == health &&
      other.healthOpenEnded == healthOpenEnded &&
      other.damageReduction == damageReduction &&
      other.damageReductionOpenEnded == damageReductionOpenEnded &&
      other.damage == damage &&
      other.sanityLoss == sanityLoss &&
      other.sanityLossOpenEnded == sanityLossOpenEnded &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    SupernaturalThreatClass,
    classKey,
    health,
    healthOpenEnded,
    damageReduction,
    damageReductionOpenEnded,
    damage,
    sanityLoss,
    sanityLossOpenEnded,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() =>
      'SupernaturalThreatClass($classKey, $health, $healthOpenEnded)';
}

/// What `threats.json` holds.
typedef ThreatsFile = ({
  List<HumanThreatClass> human,
  List<SupernaturalThreatClass> supernatural,
});

/// Parses `threats.json`.
ThreatsFile parseThreats(ObjectReader r, int? packMajor) {
  final human = r.objects('human', (h) {
    final classKey = h.string('class');
    final health = h.integer('health');
    final healthOpenEnded = h.flag('healthOpenEnded');
    final dr = h.integer('damageReduction');
    final skills = h.string('skills');
    final gear = h.string('gear');
    final deprecated = h.deprecation(packMajor);
    final fields = h.deprecatedFields(packMajor);
    if (classKey == null ||
        health == null ||
        healthOpenEnded == null ||
        dr == null ||
        skills == null ||
        gear == null) {
      return null;
    }
    return HumanThreatClass(
      classKey: classKey,
      health: health,
      healthOpenEnded: healthOpenEnded,
      damageReduction: dr,
      skillsText: skills,
      gearText: gear,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final supernatural = r.objects('supernatural', (s) {
    final classKey = s.string('class');
    final health = s.integer('health');
    final healthOpenEnded = s.flag('healthOpenEnded');
    final dr = s.integer('damageReduction');
    final drOpenEnded = s.flag('damageReductionOpenEnded');
    final damage = s.object('damage', (d) {
      final category = d.string('category');
      final dice = d.exprOrPending('dice');
      final min = d.intOrPending('min');
      final openEnded = d.flag('openEnded');
      if (category == null || openEnded == null) return null;
      return ThreatDamage(
        category: category,
        dice: dice,
        min: min,
        openEnded: openEnded,
      );
    });
    final sanityLoss = s.integer('sanityLoss');
    final sanityLossOpenEnded = s.flag('sanityLossOpenEnded');
    final deprecated = s.deprecation(packMajor);
    final fields = s.deprecatedFields(packMajor);
    if (classKey == null ||
        health == null ||
        healthOpenEnded == null ||
        dr == null ||
        drOpenEnded == null ||
        damage == null ||
        sanityLoss == null ||
        sanityLossOpenEnded == null) {
      return null;
    }
    return SupernaturalThreatClass(
      classKey: classKey,
      health: health,
      healthOpenEnded: healthOpenEnded,
      damageReduction: dr,
      damageReductionOpenEnded: drOpenEnded,
      damage: damage,
      sanityLoss: sanityLoss,
      sanityLossOpenEnded: sanityLossOpenEnded,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  r.pendingSlot('perClassNumbersForAttackAndDefense'); // G11
  return (human: human, supernatural: supernatural);
}
