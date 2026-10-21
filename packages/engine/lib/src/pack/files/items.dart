/// The pack file `items/`: item templates, one per file.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// What an item template is. A new kind is an engine change.
enum ItemKind {
  /// Something that deals damage.
  weapon,

  /// Something worn that reduces damage.
  armor,
}

/// An item template from `items/` (rulebook §6).
final class ItemTemplate {
  /// Creates a [ItemTemplate].
  const ItemTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    this.damageCategory,
    this.drModifier,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Item id.
  final String id;

  /// Display name.
  final String name;

  /// Weapon or armor.
  final ItemKind kind;

  /// Display description.
  final String description;

  /// Weapon damage category key.
  final String? damageCategory;

  /// Armor damage reduction modifier; `null` while pending D (G8).
  final int? drModifier;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is ItemTemplate &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.description == description &&
      other.damageCategory == damageCategory &&
      other.drModifier == drModifier &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    ItemTemplate,
    id,
    name,
    kind,
    description,
    damageCategory,
    drModifier,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'ItemTemplate($id, $name, $kind)';
}

/// Parses one file of `items/`.
ItemTemplate? parseItem(ObjectReader r, int? packMajor) {
  final id = r.string('id');
  final name = r.string('name');
  final kindText = r.string('kind');
  final description = r.string('description');
  final kind = ItemKind.values.where((k) => k.name == kindText).firstOrNull;
  if (kindText != null && kind == null) {
    r.error('kind', 'Expected "weapon" or "armor".');
  }
  final damageCategory = kind == ItemKind.weapon
      ? r.string('damageCategory')
      : null;
  final drModifier = kind == ItemKind.armor
      ? r.intOrPending('drModifier')
      : null;
  r.pendingSlot('rangeBands'); // G10
  final deprecated = r.deprecation(packMajor);
  final fields = r.deprecatedFields(packMajor);
  if (id == null || name == null || kind == null || description == null) {
    return null;
  }
  return ItemTemplate(
    id: id,
    name: name,
    kind: kind,
    description: description,
    damageCategory: damageCategory,
    drModifier: drModifier,
    deprecated: deprecated,
    deprecatedFields: ImmutableMap.of(fields),
  );
}
