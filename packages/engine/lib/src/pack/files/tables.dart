/// The pack folder `tables/`: random tables, one per file (R-B2).
///
/// A random table is a die and rows of text; a roll picks the row whose
/// range holds the total. Value types and their parser, kept together so a
/// change to this file's shape is a local edit. The engine ships no table
/// rows: the tables themselves are pack content (D).
library;

import '../../deprecation.dart';
import '../../equality.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One row of a [RandomTable]: the totals [from] to [to] (inclusive) select
/// it.
final class RandomTableRow {
  /// Creates a [RandomTableRow].
  const RandomTableRow({
    required this.from,
    required this.to,
    required this.text,
  });

  /// Lowest total that selects the row.
  final int from;

  /// Highest total that selects the row.
  final int to;

  /// What happens, as text for the table.
  final String text;

  /// Whether [total] selects this row.
  bool covers(int total) => total >= from && total <= to;

  @override
  bool operator ==(Object other) =>
      other is RandomTableRow &&
      other.from == from &&
      other.to == to &&
      other.text == text;

  @override
  int get hashCode => Object.hash(RandomTableRow, from, to, text);

  @override
  String toString() => 'RandomTableRow($from-$to, $text)';
}

/// A random table from `tables/` (R-B2): a die and rows of text.
final class RandomTable {
  /// Creates a [RandomTable].
  RandomTable({
    required this.id,
    required this.name,
    required this.dice,
    required List<RandomTableRow> rows,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  }) : rows = List.unmodifiable(rows);

  /// Table id, unique in the pack.
  final String id;

  /// Display name.
  final String name;

  /// The dice rolled on the table: a plain dice node without `explode`.
  /// `null` while the value is pending D; such a table cannot be rolled.
  final Dice? dice;

  /// Rows in order. The loader checks that they cover every total of
  /// [dice] exactly once.
  final List<RandomTableRow> rows;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  /// The row [total] selects, or `null` when none does.
  RandomTableRow? rowFor(int total) {
    for (final row in rows) {
      if (row.covers(total)) return row;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RandomTable &&
      other.id == id &&
      other.name == name &&
      other.dice == dice &&
      listEquals(other.rows, rows) &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    RandomTable,
    id,
    name,
    dice,
    Object.hashAll(rows),
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'RandomTable($id, $dice, $rows)';
}

/// Parses one file of `tables/`.
RandomTable? parseRandomTable(ObjectReader r, int? packMajor) {
  final id = r.string('id');
  final name = r.string('name');
  final expr = r.exprOrPending('dice');
  final rows = r.objects('rows', (row) {
    final from = row.integer('from');
    final to = row.integer('to');
    final text = row.string('text');
    // No effect has engine meaning yet, so the slot must stay empty (R-B2).
    if (row.has('effects')) {
      row.emptyList('effects', 'no table effect has engine meaning yet.');
    }
    if (from == null || to == null || text == null) return null;
    if (from > to) {
      row.error('to', 'Must not be lower than "from".');
      return null;
    }
    return RandomTableRow(from: from, to: to, text: text);
  });
  final deprecated = r.deprecation(packMajor);
  final fields = r.deprecatedFields(packMajor);
  Dice? dice;
  if (expr != null) {
    if (expr is Dice && expr.explode != true) {
      dice = expr;
    } else {
      r.error('dice', 'Expected a plain dice node without explode.');
      return null;
    }
  }
  if (id == null || name == null) return null;
  return RandomTable(
    id: id,
    name: name,
    dice: dice,
    rows: rows,
    deprecated: deprecated,
    deprecatedFields: ImmutableMap.of(fields),
  );
}
