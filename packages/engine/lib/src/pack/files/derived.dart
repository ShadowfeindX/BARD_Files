/// The pack file `derived.json`: derived stat formulas.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// A stat the engine computes from attributes, such as Health (rulebook §3).
final class DerivedStat {
  /// Creates a [DerivedStat].
  const DerivedStat({
    required this.key,
    required this.name,
    required this.formula,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Key used by read models.
  final String key;

  /// Display name.
  final String name;

  /// Formula over attributes; never rolls dice.
  final Expr formula;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is DerivedStat &&
      other.key == key &&
      other.name == name &&
      other.formula == formula &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    DerivedStat,
    key,
    name,
    formula,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'DerivedStat($key, $name, $formula)';
}

/// Parses `derived.json`.
List<DerivedStat> parseDerived(ObjectReader r, int? packMajor) {
  final derived = r.objects('derived', (d) {
    final key = d.string('key');
    final name = d.string('name');
    final formula = d.expr('formula', formula: true);
    d.pendingSlot('armorModifierAdded'); // G8
    final deprecated = d.deprecation(packMajor);
    final fields = d.deprecatedFields(packMajor);
    if (key == null || name == null || formula == null) return null;
    return DerivedStat(
      key: key,
      name: name,
      formula: formula,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  r.prose('storedModifiersAllowed');
  return derived;
}
