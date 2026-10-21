/// The pack file `damage.json`: weapon damage categories.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One weapon damage category (rulebook §6).
final class DamageCategory {
  /// Creates a [DamageCategory].
  const DamageCategory({
    required this.key,
    required this.name,
    this.dice,
    this.min,
    this.minOpenEnded = false,
    this.printedAs,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Category key.
  final String key;

  /// Display name.
  final String name;

  /// Damage dice; `null` when not set (Cat-Ω: the Handler decides, G12).
  final Expr? dice;

  /// Minimum damage as printed (what MIN means is G9, pending D); `null` when not set.
  final int? min;

  /// Whether the minimum is open-ended (11+).
  final bool minOpenEnded;

  /// How the book prints the row, for display.
  final String? printedAs;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is DamageCategory &&
      other.key == key &&
      other.name == name &&
      other.dice == dice &&
      other.min == min &&
      other.minOpenEnded == minOpenEnded &&
      other.printedAs == printedAs &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    DamageCategory,
    key,
    name,
    dice,
    min,
    minOpenEnded,
    printedAs,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'DamageCategory($key, $name, $dice)';
}

/// Parses `damage.json`.
List<DamageCategory> parseDamage(ObjectReader r, int? packMajor) {
  final categories = r.objects('categories', (c) {
    final key = c.string('key');
    final name = c.string('name');
    final dice = c.exprOrPending('dice');
    final min = c.intOrPending('min');
    final minOpenEnded = c.flag('minOpenEnded');
    final printedAs = c.optionalString('printedAs');
    final deprecated = c.deprecation(packMajor);
    final fields = c.deprecatedFields(packMajor);
    if (key == null || name == null || minOpenEnded == null) return null;
    return DamageCategory(
      key: key,
      name: name,
      dice: dice,
      min: min,
      minOpenEnded: minOpenEnded,
      printedAs: printedAs,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  r.prose('appliesTo');
  return categories;
}
