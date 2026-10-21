/// The values half of the game: what a pack supplies to the engine.
///
/// This is the in-memory form. `loadPack` builds it from pack files (02
/// §Loading and validation); the value types of each file live beside that
/// file's parser in `files/`. The pack shape is Provisional, pending D (02
/// §Pack structure).
library;

import '../equality.dart';
import 'files/advancement.dart';
import 'files/attributes.dart';
import 'files/conditions.dart';
import 'files/damage.dart';
import 'files/derived.dart';
import 'files/difficulty.dart';
import 'files/disorders.dart';
import 'files/items.dart';
import 'files/manifest.dart';
import 'files/npcs.dart';
import 'files/proficiency.dart';
import 'files/ranges.dart';
import 'files/sanity_events.dart';
import 'files/skills.dart';
import 'files/strings.dart';
import 'files/techniques.dart';
import 'files/threats.dart';
import 'files/vehicles.dart';

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

/// An immutable, validated rules pack bound to one `Engine`.
final class RulesPack {
  /// Creates a pack from already-validated parts. Only the parts the engine
  /// core needs are required; the rest default to empty.
  RulesPack({
    required this.ref,
    this.manifest,
    required List<AttributeDef> attributes,
    required this.attributeCreation,
    this.advancementCap,
    required List<ProficiencyTier> proficiencyTiers,
    this.proficiencyCreation,
    required List<SkillCategory> skillCategories,
    required List<SkillDef> skills,
    required List<DerivedStat> derived,
    List<DifficultyCategory> difficultyCategories = const [],
    this.checkRules,
    List<ConditionDef> conditions = const [],
    this.disorders,
    List<SanityEvent> sanityEvents = const [],
    List<DamageCategory> damageCategories = const [],
    List<VehiclePerformance> vehiclePerformance = const [],
    List<VehicleDurability> vehicleDurability = const [],
    List<RangeBand> rangeBands = const [],
    List<AdvancementCost> advancementCosts = const [],
    List<HumanThreatClass> humanThreats = const [],
    List<SupernaturalThreatClass> supernaturalThreats = const [],
    List<ItemTemplate> items = const [],
    List<TechniqueTemplate> techniques = const [],
    List<NpcTemplate> npcs = const [],
    Map<String, PackStrings> strings = const {},
    this.occultPending,
    Set<String> pendingPaths = const {},
  }) : attributes = List.unmodifiable(attributes),
       proficiencyTiers = List.unmodifiable(proficiencyTiers),
       skillCategories = List.unmodifiable(skillCategories),
       skills = List.unmodifiable(skills),
       derived = List.unmodifiable(derived),
       difficultyCategories = List.unmodifiable(difficultyCategories),
       conditions = List.unmodifiable(conditions),
       sanityEvents = List.unmodifiable(sanityEvents),
       damageCategories = List.unmodifiable(damageCategories),
       vehiclePerformance = List.unmodifiable(vehiclePerformance),
       vehicleDurability = List.unmodifiable(vehicleDurability),
       rangeBands = List.unmodifiable(rangeBands),
       advancementCosts = List.unmodifiable(advancementCosts),
       humanThreats = List.unmodifiable(humanThreats),
       supernaturalThreats = List.unmodifiable(supernaturalThreats),
       items = List.unmodifiable(items),
       techniques = List.unmodifiable(techniques),
       npcs = List.unmodifiable(npcs),
       strings = Map.unmodifiable(strings),
       pendingPaths = Set.unmodifiable(pendingPaths);

  /// Which pack this is.
  final PackRef ref;

  /// The manifest, or `null` for a pack built in code.
  final PackManifest? manifest;

  /// Attributes in pack order.
  final List<AttributeDef> attributes;

  /// Attribute limits at agent creation.
  final AttributeCreation attributeCreation;

  /// Highest score advancement may reach.
  final int? advancementCap;

  /// Proficiency tiers in pack order.
  final List<ProficiencyTier> proficiencyTiers;

  /// Skills per tier picked at creation.
  final ProficiencyCreation? proficiencyCreation;

  /// Skill categories in pack order.
  final List<SkillCategory> skillCategories;

  /// Skills in pack order.
  final List<SkillDef> skills;

  /// Derived stats in pack order.
  final List<DerivedStat> derived;

  /// Difficulty categories in pack order.
  final List<DifficultyCategory> difficultyCategories;

  /// Check values (primary die, partial success, ...).
  final CheckRules? checkRules;

  /// Condition and affliction templates.
  final List<ConditionDef> conditions;

  /// The disorder table.
  final DisorderTable? disorders;

  /// The sanity loss table.
  final List<SanityEvent> sanityEvents;

  /// Weapon damage categories.
  final List<DamageCategory> damageCategories;

  /// Vehicle performance categories.
  final List<VehiclePerformance> vehiclePerformance;

  /// Vehicle durability categories.
  final List<VehicleDurability> vehicleDurability;

  /// Range bands.
  final List<RangeBand> rangeBands;

  /// Advancement purchases.
  final List<AdvancementCost> advancementCosts;

  /// Human threat classes.
  final List<HumanThreatClass> humanThreats;

  /// Supernatural threat classes.
  final List<SupernaturalThreatClass> supernaturalThreats;

  /// Item templates, by file name order.
  final List<ItemTemplate> items;

  /// Techniques, by file name order.
  final List<TechniqueTemplate> techniques;

  /// NPC templates, by file name order.
  final List<NpcTemplate> npcs;

  /// Display text by language code.
  final Map<String, PackStrings> strings;

  /// `occult.json` as raw JSON. The occult system is pending D (C5/G6, F3), so it is kept but not validated or used.
  final Object? occultPending;

  /// Every value marked pending D, as `file: path`. A feature that needs one of these stays off.
  final Set<String> pendingPaths;

  /// The attribute with [key], or `null`.
  AttributeDef? attribute(String key) => _find(attributes, (a) => a.key, key);

  /// The proficiency tier with [key], or `null`.
  ProficiencyTier? proficiencyTier(String key) =>
      _find(proficiencyTiers, (t) => t.key, key);

  /// The skill with [id], or `null`.
  SkillDef? skill(String id) => _find(skills, (s) => s.id, id);

  /// The derived stat with [key], or `null`.
  DerivedStat? derivedStat(String key) => _find(derived, (d) => d.key, key);

  /// The difficulty category with [key], or `null`.
  DifficultyCategory? difficultyCategory(String key) =>
      _find(difficultyCategories, (c) => c.key, key);

  /// The condition with [id], or `null`.
  ConditionDef? condition(String id) => _find(conditions, (c) => c.id, id);

  static T? _find<T>(List<T> items, String Function(T) keyOf, String key) {
    for (final item in items) {
      if (keyOf(item) == key) return item;
    }
    return null;
  }

  /// Equality ignores [occultPending], which is unvalidated raw JSON.
  @override
  bool operator ==(Object other) =>
      other is RulesPack &&
      other.ref == ref &&
      other.manifest == manifest &&
      other.attributeCreation == attributeCreation &&
      other.advancementCap == advancementCap &&
      other.proficiencyCreation == proficiencyCreation &&
      other.checkRules == checkRules &&
      other.disorders == disorders &&
      listEquals(other.attributes, attributes) &&
      listEquals(other.proficiencyTiers, proficiencyTiers) &&
      listEquals(other.skillCategories, skillCategories) &&
      listEquals(other.skills, skills) &&
      listEquals(other.derived, derived) &&
      listEquals(other.difficultyCategories, difficultyCategories) &&
      listEquals(other.conditions, conditions) &&
      listEquals(other.sanityEvents, sanityEvents) &&
      listEquals(other.damageCategories, damageCategories) &&
      listEquals(other.vehiclePerformance, vehiclePerformance) &&
      listEquals(other.vehicleDurability, vehicleDurability) &&
      listEquals(other.rangeBands, rangeBands) &&
      listEquals(other.advancementCosts, advancementCosts) &&
      listEquals(other.humanThreats, humanThreats) &&
      listEquals(other.supernaturalThreats, supernaturalThreats) &&
      listEquals(other.items, items) &&
      listEquals(other.techniques, techniques) &&
      listEquals(other.npcs, npcs) &&
      _mapEquals(other.strings, strings) &&
      other.pendingPaths.length == pendingPaths.length &&
      other.pendingPaths.containsAll(pendingPaths);

  @override
  int get hashCode => Object.hashAll([
    ref,
    manifest,
    attributeCreation,
    advancementCap,
    proficiencyCreation,
    checkRules,
    disorders,
    Object.hashAll(attributes),
    Object.hashAll(proficiencyTiers),
    Object.hashAll(skillCategories),
    Object.hashAll(skills),
    Object.hashAll(derived),
    Object.hashAll(difficultyCategories),
    Object.hashAll(conditions),
    Object.hashAll(sanityEvents),
    Object.hashAll(damageCategories),
    Object.hashAll(vehiclePerformance),
    Object.hashAll(vehicleDurability),
    Object.hashAll(rangeBands),
    Object.hashAll(advancementCosts),
    Object.hashAll(humanThreats),
    Object.hashAll(supernaturalThreats),
    Object.hashAll(items),
    Object.hashAll(techniques),
    Object.hashAll(npcs),
    Object.hashAllUnordered(strings.keys),
    Object.hashAllUnordered(pendingPaths),
  ]);

  @override
  String toString() =>
      'RulesPack(${ref.id}@${ref.version}, '
      '${attributes.length} attributes, ${skills.length} skills)';
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
