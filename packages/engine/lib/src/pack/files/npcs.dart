/// The pack file `npcs/`: NPC templates, one per file.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';
import '../load/pending.dart';

/// An NPC template from `npcs/`.
final class NpcTemplate {
  /// Creates a [NpcTemplate].
  const NpcTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.threatClass,
    this.attributes,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// NPC id.
  final String id;

  /// Display name.
  final String name;

  /// Display description.
  final String description;

  /// Threat class as `group:class`, for example `human:E`.
  final String threatClass;

  /// Attribute scores; `null` while pending D (G11).
  final ImmutableMap<String, int>? attributes;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is NpcTemplate &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.threatClass == threatClass &&
      other.attributes == attributes &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    NpcTemplate,
    id,
    name,
    description,
    threatClass,
    attributes,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'NpcTemplate($id, $name, $description)';
}

/// Parses one file of `npcs/`.
NpcTemplate? parseNpc(ObjectReader r, int? packMajor) {
  final id = r.string('id');
  final name = r.string('name');
  final description = r.string('description');
  final threatClass = r.string('threatClass');
  final pending = r.has('attributes') && isPendingMarker(r.raw('attributes'));
  if (pending) r.log.pendingD(r.file, r.at('attributes'));
  final attributes = pending
      ? null
      : r.object('attributes', (a) {
          final scores = <String, int>{};
          for (final key in a.takeAll().keys.toList()) {
            final score = a.integer(key);
            if (score != null) scores[key] = score;
          }
          return ImmutableMap.of(scores);
        });
  final deprecated = r.deprecation(packMajor);
  final fields = r.deprecatedFields(packMajor);
  if (id == null ||
      name == null ||
      description == null ||
      threatClass == null) {
    return null;
  }
  if (!threatClass.contains(':')) {
    r.error('threatClass', 'Expected group:class, such as human:E.');
    return null;
  }
  return NpcTemplate(
    id: id,
    name: name,
    description: description,
    threatClass: threatClass,
    attributes: attributes,
    deprecated: deprecated,
    deprecatedFields: ImmutableMap.of(fields),
  );
}
