/// The values half of the game: what a pack supplies to the engine.
///
/// This is the in-memory form only. Reading and validating pack files is the
/// pack loader's job (02 §Loading and validation); this file holds the parts
/// the engine core reads today and grows as systems are added. The pack shape
/// is Provisional, pending D (02 §Pack structure).
library;

import '../equality.dart';
import '../expr/expr.dart';

/// Identifies one exact pack: what an operation pins (02 §Operations pin
/// packs).
final class PackRef {
  /// Creates a pack reference.
  const PackRef({
    required this.id,
    required this.version,
    required this.contentHash,
  });

  /// Pack id from the manifest.
  final String id;

  /// Pack semver from the manifest.
  final String version;

  /// Hash of the pack's content, computed by tooling.
  final String contentHash;

  @override
  bool operator ==(Object other) =>
      other is PackRef &&
      other.id == id &&
      other.version == version &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(id, version, contentHash);

  @override
  String toString() => 'PackRef($id@$version, $contentHash)';
}

/// One attribute the pack declares (`STR`, `DEX`, ...).
final class AttributeDef {
  /// Creates an attribute definition.
  const AttributeDef({required this.key, required this.name});

  /// Key used in components and formulas.
  final String key;

  /// Display name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AttributeDef && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(AttributeDef, key, name);
}

/// Limits on attribute scores when an agent is created (rulebook §3).
final class AttributeCreation {
  /// Creates creation limits.
  const AttributeCreation({
    required this.points,
    required this.minPerAttribute,
    required this.maxPerAttribute,
  });

  /// Points to distribute.
  ///
  /// Not enforced yet: whether the scores must add up to exactly this or at
  /// most this is not ruled.
  final int points;

  /// Lowest score allowed at creation.
  final int minPerAttribute;

  /// Highest score allowed at creation.
  final int maxPerAttribute;

  @override
  bool operator ==(Object other) =>
      other is AttributeCreation &&
      other.points == points &&
      other.minPerAttribute == minPerAttribute &&
      other.maxPerAttribute == maxPerAttribute;

  @override
  int get hashCode =>
      Object.hash(AttributeCreation, points, minPerAttribute, maxPerAttribute);
}

/// One proficiency tier (`untrained`, `proficient`, `expert`).
final class ProficiencyTier {
  /// Creates a tier.
  const ProficiencyTier({required this.key, required this.name, this.bonus});

  /// Key stored in the `Skills` component.
  final String key;

  /// Display name.
  final String name;

  /// Extra dice the tier adds to a check (G16); `null` = no bonus.
  final Expr? bonus;

  @override
  bool operator ==(Object other) =>
      other is ProficiencyTier &&
      other.key == key &&
      other.name == name &&
      other.bonus == bonus;

  @override
  int get hashCode => Object.hash(ProficiencyTier, key, name, bonus);
}

/// One of the pack's skill categories. Organizational only (F3).
final class SkillCategory {
  /// Creates a category.
  const SkillCategory({required this.key, required this.name});

  /// Key used by skills.
  final String key;

  /// Display name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SkillCategory && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(SkillCategory, key, name);
}

/// One skill: name, description, category and attribute (F3).
final class SkillDef {
  /// Creates a skill definition.
  const SkillDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.attribute,
  });

  /// Key stored in the `Skills` component.
  final String id;

  /// Display name.
  final String name;

  /// Display description.
  final String description;

  /// [SkillCategory.key], or `null` while the pack's author has not ruled.
  final String? category;

  /// [AttributeDef.key], or `null` while the pack's author has not ruled.
  final String? attribute;

  @override
  bool operator ==(Object other) =>
      other is SkillDef &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.category == category &&
      other.attribute == attribute;

  @override
  int get hashCode =>
      Object.hash(SkillDef, id, name, description, category, attribute);
}

/// A stat the engine computes from attributes, such as Health (rulebook §3).
final class DerivedStat {
  /// Creates a derived stat.
  const DerivedStat({
    required this.key,
    required this.name,
    required this.formula,
  });

  /// Key used by read models.
  final String key;

  /// Display name.
  final String name;

  /// Formula over attributes; never rolls dice.
  final Expr formula;

  @override
  bool operator ==(Object other) =>
      other is DerivedStat &&
      other.key == key &&
      other.name == name &&
      other.formula == formula;

  @override
  int get hashCode => Object.hash(DerivedStat, key, name, formula);
}

/// An immutable, validated rules pack bound to one `Engine`.
final class RulesPack {
  /// Creates a pack from already-validated parts.
  RulesPack({
    required this.ref,
    required List<AttributeDef> attributes,
    required this.attributeCreation,
    required List<ProficiencyTier> proficiencyTiers,
    required List<SkillCategory> skillCategories,
    required List<SkillDef> skills,
    required List<DerivedStat> derived,
  }) : attributes = List.unmodifiable(attributes),
       proficiencyTiers = List.unmodifiable(proficiencyTiers),
       skillCategories = List.unmodifiable(skillCategories),
       skills = List.unmodifiable(skills),
       derived = List.unmodifiable(derived);

  /// Which pack this is.
  final PackRef ref;

  /// Attributes in pack order.
  final List<AttributeDef> attributes;

  /// Attribute limits at agent creation.
  final AttributeCreation attributeCreation;

  /// Proficiency tiers in pack order.
  final List<ProficiencyTier> proficiencyTiers;

  /// Skill categories in pack order.
  final List<SkillCategory> skillCategories;

  /// Skills in pack order.
  final List<SkillDef> skills;

  /// Derived stats in pack order.
  final List<DerivedStat> derived;

  /// The attribute with [key], or `null`.
  AttributeDef? attribute(String key) => _find(attributes, (a) => a.key, key);

  /// The proficiency tier with [key], or `null`.
  ProficiencyTier? proficiencyTier(String key) =>
      _find(proficiencyTiers, (t) => t.key, key);

  /// The skill with [id], or `null`.
  SkillDef? skill(String id) => _find(skills, (s) => s.id, id);

  /// The derived stat with [key], or `null`.
  DerivedStat? derivedStat(String key) => _find(derived, (d) => d.key, key);

  static T? _find<T>(List<T> items, String Function(T) keyOf, String key) {
    for (final item in items) {
      if (keyOf(item) == key) return item;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RulesPack &&
      other.ref == ref &&
      other.attributeCreation == attributeCreation &&
      listEquals(other.attributes, attributes) &&
      listEquals(other.proficiencyTiers, proficiencyTiers) &&
      listEquals(other.skillCategories, skillCategories) &&
      listEquals(other.skills, skills) &&
      listEquals(other.derived, derived);

  @override
  int get hashCode => Object.hash(
    ref,
    attributeCreation,
    Object.hashAll(attributes),
    Object.hashAll(proficiencyTiers),
    Object.hashAll(skillCategories),
    Object.hashAll(skills),
    Object.hashAll(derived),
  );

  @override
  String toString() =>
      'RulesPack(${ref.id}@${ref.version}, '
      '${attributes.length} attributes, ${skills.length} skills)';
}
