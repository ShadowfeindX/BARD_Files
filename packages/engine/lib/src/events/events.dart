/// Events: facts that happened in an operation (01 §Commands and events).
///
/// A sealed family, grouped into one sealed sub-family per system, so both
/// `Engine.evolve` and each system switch over them exhaustively [V-16].
/// Event payloads are self-sufficient: applying one never re-runs a pack
/// formula. Event names and fields are Proposed.
library;

import '../actor.dart';
import '../ids.dart';
import '../immutable_map.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

part 'character_events.dart';
part 'operation_events.dart';

/// Something that happened. `evolve` applies it to state.
sealed class Event {
  const Event();

  /// Who caused the event.
  Actor get actor;

  /// Who may see the event once broadcast.
  Visibility get visibility;
}
