/// The pack file `conditions.json`: condition and affliction templates.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// Whether a condition is short-term or a longer affliction (rulebook §4).
enum ConditionKind {
  /// A short-term condition.
  condition,

  /// A longer-lasting affliction.
  affliction,
}

/// A condition or affliction template (rulebook §4). Effects come later.
final class ConditionDef {
  /// Creates a [ConditionDef].
  const ConditionDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Condition id.
  final String id;

  /// Display name.
  final String name;

  /// Condition or affliction.
  final ConditionKind kind;

  /// Display description.
  final String description;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is ConditionDef &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.description == description &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    ConditionDef,
    id,
    name,
    kind,
    description,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'ConditionDef($id, $name, $kind)';
}

/// Parses `conditions.json`.
List<ConditionDef> parseConditions(ObjectReader r, int? packMajor) {
  return r.objects('conditions', (c) {
    final id = c.string('id');
    final name = c.string('name');
    final kindText = c.string('kind');
    final description = c.string('description');
    c.emptyList('effects', 'condition effects are not engine vocabulary yet.');
    final deprecated = c.deprecation(packMajor);
    final fields = c.deprecatedFields(packMajor);
    final kind = ConditionKind.values
        .where((k) => k.name == kindText)
        .firstOrNull;
    if (kindText != null && kind == null) {
      c.error('kind', 'Expected "condition" or "affliction".');
    }
    if (id == null || name == null || kind == null || description == null) {
      return null;
    }
    return ConditionDef(
      id: id,
      name: name,
      kind: kind,
      description: description,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
}
