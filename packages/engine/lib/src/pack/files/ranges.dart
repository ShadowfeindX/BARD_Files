/// The pack file `ranges.json`: range bands and penalties.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../equality.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// A range band and its penalty (rulebook §7).
final class RangeBand {
  /// Creates a [RangeBand].
  RangeBand({
    required this.key,
    required this.name,
    this.minFeet,
    this.maxFeet,
    required this.penalty,
    List<String> notWithDamageCategories = const [],
    this.requiresText,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  }) : notWithDamageCategories = List.unmodifiable(notWithDamageCategories);

  /// Band key.
  final String key;

  /// Display name.
  final String name;

  /// Nearest distance in feet, if bounded.
  final int? minFeet;

  /// Farthest distance in feet, if bounded.
  final int? maxFeet;

  /// Modifier to attacks at this range.
  final int penalty;

  /// Damage categories whose weapons cannot be used at this range.
  final List<String> notWithDamageCategories;

  /// Printed prerequisite (for example Aim), as text; aim is G10, pending D.
  final String? requiresText;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is RangeBand &&
      other.key == key &&
      other.name == name &&
      other.minFeet == minFeet &&
      other.maxFeet == maxFeet &&
      other.penalty == penalty &&
      listEquals(other.notWithDamageCategories, notWithDamageCategories) &&
      other.requiresText == requiresText &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    RangeBand,
    key,
    name,
    minFeet,
    maxFeet,
    penalty,
    Object.hashAll(notWithDamageCategories),
    requiresText,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'RangeBand($key, $name, $minFeet)';
}

/// Parses `ranges.json`.
List<RangeBand> parseRanges(ObjectReader r, int? packMajor) {
  return r.objects('bands', (b) {
    final key = b.string('key');
    final name = b.string('name');
    final minFeet = b.optionalInt('minFeet');
    final maxFeet = b.optionalInt('maxFeet');
    final penalty = b.integer('penalty');
    final notWith = b.optionalStrings('notWithDamageCategories');
    final requiresText = b.optionalString('requires');
    final deprecated = b.deprecation(packMajor);
    final fields = b.deprecatedFields(packMajor);
    if (key == null || name == null || penalty == null) return null;
    if (minFeet != null && maxFeet != null && minFeet > maxFeet) {
      b.error('minFeet', 'Is larger than maxFeet.');
      return null;
    }
    return RangeBand(
      key: key,
      name: name,
      minFeet: minFeet,
      maxFeet: maxFeet,
      penalty: penalty,
      notWithDamageCategories: notWith,
      requiresText: requiresText,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
}
