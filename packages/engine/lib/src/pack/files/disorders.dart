/// The pack file `disorders.json`: the disorder table and Disorder Check.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../equality.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// When and how a Disorder Check is rolled (rulebook §4).
final class DisorderCheck {
  /// Creates a [DisorderCheck].
  DisorderCheck({
    required this.attribute,
    required this.dc,
    required List<String> when,
  }) : when = List.unmodifiable(when);

  /// Attribute rolled.
  final String attribute;

  /// Difficulty class.
  final int dc;

  /// When the check is called for, as text for the GM.
  final List<String> when;

  @override
  bool operator ==(Object other) =>
      other is DisorderCheck &&
      other.attribute == attribute &&
      other.dc == dc &&
      listEquals(other.when, when);

  @override
  int get hashCode =>
      Object.hash(DisorderCheck, attribute, dc, Object.hashAll(when));

  @override
  String toString() => 'DisorderCheck($attribute, $dc, $when)';
}

/// One row of the disorder table.
final class DisorderRow {
  /// Creates a [DisorderRow].
  const DisorderRow({
    required this.roll,
    required this.name,
    required this.effect,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Die result that selects the row.
  final int roll;

  /// Display name.
  final String name;

  /// Effect, as text for the GM.
  final String effect;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is DisorderRow &&
      other.roll == roll &&
      other.name == name &&
      other.effect == effect &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    DisorderRow,
    roll,
    name,
    effect,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'DisorderRow($roll, $name, $effect)';
}

/// The disorder table and its check (rulebook §4).
final class DisorderTable {
  /// Creates a [DisorderTable].
  DisorderTable({
    this.rollDie,
    required this.check,
    required List<DisorderRow> rows,
  }) : rows = List.unmodifiable(rows);

  /// Die rolled on the table; `null` while pending D (G5).
  final Expr? rollDie;

  /// The Disorder Check.
  final DisorderCheck check;

  /// Table rows in roll order.
  final List<DisorderRow> rows;

  @override
  bool operator ==(Object other) =>
      other is DisorderTable &&
      other.rollDie == rollDie &&
      other.check == check &&
      listEquals(other.rows, rows);

  @override
  int get hashCode =>
      Object.hash(DisorderTable, rollDie, check, Object.hashAll(rows));

  @override
  String toString() => 'DisorderTable($rollDie, $check, $rows)';
}

/// Parses `disorders.json`.
DisorderTable? parseDisorders(ObjectReader r, int? packMajor) {
  final rollDie = r.exprOrPending('rollDie'); // G5
  final check = r.object('disorderCheck', (c) {
    final attribute = c.string('attribute');
    final dc = c.integer('dc');
    final when = c.strings('when');
    if (attribute == null || dc == null) return null;
    return DisorderCheck(attribute: attribute, dc: dc, when: when);
  });
  final rows = r.objects('table', (t) {
    final roll = t.integer('roll');
    final name = t.string('name');
    final effect = t.string('effect');
    final deprecated = t.deprecation(packMajor);
    final fields = t.deprecatedFields(packMajor);
    if (roll == null || name == null || effect == null) return null;
    return DisorderRow(
      roll: roll,
      name: name,
      effect: effect,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  if (check == null) return null;
  return DisorderTable(rollDie: rollDie, check: check, rows: rows);
}
