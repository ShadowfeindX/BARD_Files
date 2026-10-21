/// Commands: requests to change an operation (01 §Commands and events).
///
/// A sealed family, grouped into one sealed sub-family per system, so both
/// `Engine.decide` and each system switch over them exhaustively [V-16].
/// Command names and fields are Proposed.
library;

import '../actor.dart';
import '../checks/check_types.dart';
import '../equality.dart';
import '../expr/condition.dart';
import '../ids.dart';
import '../immutable_map.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

part 'character_commands.dart';
part 'check_commands.dart';
part 'condition_commands.dart';
part 'messaging_commands.dart';
part 'operation_commands.dart';
part 'vitals_commands.dart';

/// A request to change an operation. `decide` turns it into events or a
/// rejection.
sealed class Command {
  const Command();

  /// Who issued the command.
  Actor get actor;
}
