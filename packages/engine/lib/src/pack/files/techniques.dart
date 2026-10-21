/// The pack file `techniques/`: techniques, one per file.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// A technique from `techniques/`: a name and a description.
final class TechniqueTemplate {
  /// Creates a [TechniqueTemplate].
  const TechniqueTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Technique id.
  final String id;

  /// Display name.
  final String name;

  /// Display description.
  final String description;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is TechniqueTemplate &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    TechniqueTemplate,
    id,
    name,
    description,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'TechniqueTemplate($id, $name, $description)';
}

/// Parses one file of `techniques/`.
TechniqueTemplate? parseTechnique(ObjectReader r, int? packMajor) {
  final id = r.string('id');
  final name = r.string('name');
  final description = r.string('description');
  final deprecated = r.deprecation(packMajor);
  final fields = r.deprecatedFields(packMajor);
  if (id == null || name == null || description == null) return null;
  return TechniqueTemplate(
    id: id,
    name: name,
    description: description,
    deprecated: deprecated,
    deprecatedFields: ImmutableMap.of(fields),
  );
}
