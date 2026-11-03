import '../checks/check_types.dart';
import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../pack/rules_pack.dart';
import '../rng.dart';
import '../state/episode_state.dart';

/// Random tables (R-B2): roll a pack table's dice and record the row the
/// total selects.
///
/// A table roll changes no state besides the RNG draw count, which
/// `Engine.evolve` moves for every rolling event, so `evolve` leaves the
/// state as it is.
final class TableSystem {
  /// Creates the system for [pack].
  const TableSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides a [TableCommand].
  Decision decide(EpisodeState state, TableCommand command, Rng rng) =>
      switch (command) {
        RollTable() => _roll(state, command, rng),
      };

  /// Applies a [TableEvent].
  EpisodeState evolve(EpisodeState state, TableEvent event) => switch (event) {
    TableRolled() => state,
  };

  Decision _roll(EpisodeState state, RollTable command, Rng rng) {
    // Everything is checked before the first draw (draw-count invariant).
    final table = pack.randomTable(command.table);
    if (table == null) {
      return Rejected(
        Rejection(
          RejectionCode.unknownPackKey,
          'Unknown table "${command.table}".',
        ),
      );
    }
    final dice = table.dice;
    if (dice == null) {
      return Rejected(
        Rejection(
          RejectionCode.unavailable,
          'Table "${table.id}" has no dice yet (pending D).',
        ),
      );
    }
    final entity = command.entity;
    if (entity != null && !state.stores.has(Identity.componentType, entity)) {
      return Rejected(
        Rejection(RejectionCode.unknownEntity, 'No entity "${entity.value}".'),
      );
    }
    final expected = state.rng.drawCount;
    if (rng.drawCount < expected) {
      return Rejected(
        Rejection(
          RejectionCode.rngOutOfSync,
          'The RNG is at draw ${rng.drawCount}, behind the episode at '
          'draw $expected.',
        ),
      );
    }
    final start = rng.drawCount;
    final faces = [
      for (var i = 0; i < dice.count; i++) rng.rollDie(dice.sides),
    ];
    final total = faces.fold(0, (a, b) => a + b);
    // The loader proved every total has exactly one row, so this only fails
    // for a pack built in code without that check.
    final row = table.rowFor(total);
    if (row == null) {
      throw StateError('Table "${table.id}" has no row for $total.');
    }
    return Accepted([
      TableRolled(
        table: table.id,
        entity: entity,
        sides: dice.sides,
        faces: faces,
        text: row.text,
        draws: DrawRange(start, rng.drawCount),
        actor: command.actor,
        visibility: command.visibility,
      ),
    ]);
  }
}
