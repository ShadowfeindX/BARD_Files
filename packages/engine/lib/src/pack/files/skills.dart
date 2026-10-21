/// The pack file `skills.json`: skill categories and skills.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One of the pack's skill categories. Organizational only (F3).
final class SkillCategory {
  /// Creates a [SkillCategory].
  const SkillCategory({
    required this.key,
    required this.name,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Key used by skills.
  final String key;

  /// Display name.
  final String name;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is SkillCategory &&
      other.key == key &&
      other.name == name &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode =>
      Object.hash(SkillCategory, key, name, deprecated, deprecatedFields);

  @override
  String toString() => 'SkillCategory($key, $name, $deprecated)';
}

/// One skill: name, description, category and attribute (F3).
final class SkillDef {
  /// Creates a [SkillDef].
  const SkillDef({
    required this.id,
    required this.name,
    required this.description,
    this.category,
    this.attribute,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Key stored in the `Skills` component.
  final String id;

  /// Display name.
  final String name;

  /// Display description.
  final String description;

  /// [SkillCategory.key], or `null` while pending D.
  final String? category;

  /// [AttributeDef.key], or `null` while pending D.
  final String? attribute;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is SkillDef &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.category == category &&
      other.attribute == attribute &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    SkillDef,
    id,
    name,
    description,
    category,
    attribute,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'SkillDef($id, $name, $description)';
}

/// What `skills.json` holds.
typedef SkillsFile = ({List<SkillCategory> categories, List<SkillDef> skills});

/// Parses `skills.json`.
SkillsFile parseSkills(ObjectReader r, int? packMajor) {
  final categories = r.objects('categories', (c) {
    final key = c.string('key');
    final name = c.string('name');
    final deprecated = c.deprecation(packMajor);
    final fields = c.deprecatedFields(packMajor);
    if (key == null || name == null) return null;
    return SkillCategory(
      key: key,
      name: name,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final skills = r.objects('skills', (s) {
    final id = s.string('id');
    final name = s.string('name');
    final description = s.string('description');
    final category = s.stringOrPending('category');
    final attribute = s.stringOrPending('attribute');
    // Provisional-pack marker wrappers beside the field they explain (G15).
    final deprecated = s.deprecation(packMajor);
    final fields = s.deprecatedFields(packMajor);
    if (id == null || name == null || description == null) return null;
    return SkillDef(
      id: id,
      name: name,
      description: description,
      category: category,
      attribute: attribute,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  r.prose('attributeSource');
  r.prose('notShownHere');
  return (categories: categories, skills: skills);
}
