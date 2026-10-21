/// The pack file `attributes.json`: the attributes and their creation limits.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One attribute the pack declares (`STR`, `DEX`, ...).
final class AttributeDef {
  /// Creates a [AttributeDef].
  const AttributeDef({
    required this.key,
    required this.name,
    this.descriptionKey,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Key used in components and formulas.
  final String key;

  /// Display name.
  final String name;

  /// Key of the description in `strings/`.
  final String? descriptionKey;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is AttributeDef &&
      other.key == key &&
      other.name == name &&
      other.descriptionKey == descriptionKey &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    AttributeDef,
    key,
    name,
    descriptionKey,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'AttributeDef($key, $name, $descriptionKey)';
}

/// Limits on attribute scores when an agent is created (rulebook §3).
final class AttributeCreation {
  /// Creates a [AttributeCreation].
  const AttributeCreation({
    required this.points,
    required this.minPerAttribute,
    required this.maxPerAttribute,
  });

  /// Points to distribute. Not enforced yet: whether the scores must add up to exactly this or at most this is not ruled.
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

  @override
  String toString() =>
      'AttributeCreation($points, $minPerAttribute, $maxPerAttribute)';
}

/// What `attributes.json` holds.
typedef AttributesFile = ({
  List<AttributeDef> attributes,
  AttributeCreation? creation,
  int? advancementCap,
});

/// Parses `attributes.json`.
AttributesFile parseAttributes(ObjectReader r, int? packMajor) {
  final attributes = r.objects('attributes', (a) {
    final key = a.string('key');
    final name = a.string('name');
    final descriptionKey = a.optionalString('descriptionKey');
    final deprecated = a.deprecation(packMajor);
    final fields = a.deprecatedFields(packMajor);
    if (key == null || name == null) return null;
    return AttributeDef(
      key: key,
      name: name,
      descriptionKey: descriptionKey,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final creation = r.object('creation', (c) {
    final points = c.integer('points');
    final min = c.integer('minPerAttribute');
    final max = c.integer('maxPerAttribute');
    if (points == null || min == null || max == null) return null;
    if (min > max) {
      c.error('minPerAttribute', 'Is larger than maxPerAttribute.');
      return null;
    }
    return AttributeCreation(
      points: points,
      minPerAttribute: min,
      maxPerAttribute: max,
    );
  });
  final advancementCap = r.optionalInt('advancementCap');
  return (
    attributes: attributes,
    creation: creation,
    advancementCap: advancementCap,
  );
}
