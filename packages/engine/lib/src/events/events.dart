/// Events: facts that happened in an operation (01 §Commands and events).
///
/// A sealed family, grouped into one sealed sub-family per system, so both
/// `Engine.evolve` and each system switch over them exhaustively [V-16].
/// Event payloads are self-sufficient: applying one never re-runs a pack
/// formula. Event names and fields are Proposed.
library;

import '../actor.dart';
import '../checks/check_types.dart';
import '../ids.dart';
import '../immutable_map.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

part 'character_events.dart';
part 'check_events.dart';
part 'condition_events.dart';
part 'operation_events.dart';
part 'vitals_events.dart';

/// Something that happened. `evolve` applies it to state.
sealed class Event {
  const Event();

  /// Who caused the event.
  Actor get actor;

  /// Who may see the event once broadcast.
  Visibility get visibility;
}

/// An event that drew from the RNG.
///
/// Folding one sets the operation's draw count to [draws]`.end`
/// (`Engine.evolve` does this for every rolling event in one place), so the
/// state always knows where the RNG stands and any roll can be audited from
/// the seed (01 §RNG).
abstract interface class RollingEvent {
  /// The draws this event used.
  DrawRange get draws;
}

/// A consequence: an event the session holds for GM review before it is
/// sequenced, narrated, stored or broadcast (F2, option A).
///
/// Rolls are never consequences: `CheckResolved` is not one, so it is never
/// held or changed.
abstract interface class Consequence {}
