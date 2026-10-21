/// The pack file `advancement.json`: XP costs.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../expr/vars.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One advancement purchase and its XP cost (rulebook §9).
final class AdvancementCost {
  /// Creates a [AdvancementCost].
  const AdvancementCost({
    required this.key,
    required this.name,
    required this.xp,
    this.grants,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Purchase key.
  final String key;

  /// Display name.
  final String name;

  /// XP cost: a number, or a formula over `var(newScore)`.
  final Expr xp;

  /// Dice the purchase grants, if any.
  final Expr? grants;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is AdvancementCost &&
      other.key == key &&
      other.name == name &&
      other.xp == xp &&
      other.grants == grants &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    AdvancementCost,
    key,
    name,
    xp,
    grants,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'AdvancementCost($key, $name, $xp)';
}

/// Parses `advancement.json`.
List<AdvancementCost> parseAdvancement(ObjectReader r, int? packMajor) {
  return r.objects('costs', (c) {
    final key = c.string('key');
    final name = c.string('name');
    // A plain number is shorthand for a constant cost.
    final xpRaw = c.has('xp') ? c.raw('xp') : null;
    final xp = xpRaw is num
        ? _constant(c, xpRaw)
        : c.expr('xp', allowedVars: {VarKeys.newScore}, formula: true);
    final grants = c.optionalExpr('grants');
    c.pendingSlot('effect'); // G14
    c.pendingSlot('repeat'); // G14
    final deprecated = c.deprecation(packMajor);
    final fields = c.deprecatedFields(packMajor);
    if (key == null || name == null || xp == null) return null;
    return AdvancementCost(
      key: key,
      name: name,
      xp: xp,
      grants: grants,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
}

Expr? _constant(ObjectReader c, num value) {
  try {
    return Const(value);
  } on ArgumentError catch (e) {
    c.error('xp', '${e.message}');
    return null;
  }
}
