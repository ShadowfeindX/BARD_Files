part of 'commands.dart';

/// Commands handled by `TableSystem` (R-B2).
sealed class TableCommand extends Command {
  const TableCommand();
}

/// The GM rolls on the pack's random table [table] (R-B2).
///
/// The episode's RNG rolls the table's dice and the total picks one row.
/// A roll, so it is never held for review (F2).
final class RollTable extends TableCommand {
  /// Creates the command.
  const RollTable({
    required this.table,
    this.entity,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  });

  /// Pack table id.
  final String table;

  /// The entity the roll is for, if any (for example the agent whose
  /// casting failed).
  final EntityId? entity;

  /// Who sees the roll and its row. [GmOnly] makes a secret roll.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is RollTable &&
      other.table == table &&
      other.entity == entity &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(RollTable, table, entity, visibility, actor);

  @override
  String toString() => 'RollTable($table, ${entity?.value})';
}
