part of 'events.dart';

/// Events applied by `TableSystem` (R-B2).
sealed class TableEvent extends Event {
  const TableEvent();
}

/// A random table was rolled (R-B2).
///
/// Self-sufficient like every event: it carries the faces, the total and
/// the selected row's text, so a log or archive reads without the pack.
/// A roll, never a consequence: it is broadcast at once and never altered.
final class TableRolled extends TableEvent implements RollingEvent {
  /// Creates the event.
  TableRolled({
    required this.table,
    this.entity,
    required this.sides,
    required List<int> faces,
    this.lead,
    required this.text,
    required this.draws,
    required this.actor,
    required this.visibility,
  }) : faces = List.unmodifiable(faces);

  /// Pack table id.
  final String table;

  /// The entity the roll is for, if any.
  final EntityId? entity;

  /// Faces per die rolled.
  final int sides;

  /// Every face rolled, in order.
  final List<int> faces;

  /// The table's lead-in line for players, if the pack has one.
  final String? lead;

  /// The selected row's text.
  final String text;

  /// The sum of [faces]: the total that picked the row.
  int get total => faces.fold(0, (a, b) => a + b);

  @override
  final DrawRange draws;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is TableRolled &&
      other.table == table &&
      other.entity == entity &&
      other.sides == sides &&
      listEquals(other.faces, faces) &&
      other.lead == lead &&
      other.text == text &&
      other.draws == draws &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    TableRolled,
    table,
    entity,
    sides,
    Object.hashAll(faces),
    lead,
    text,
    draws,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'TableRolled($table, ${faces.length}d$sides $faces = $total, "$text")';
}
