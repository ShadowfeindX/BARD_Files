import 'commands/commands.dart';
import 'decision.dart';
import 'events/events.dart';
import 'expr/evaluate.dart';
import 'ids.dart';
import 'pack/rules_pack.dart';
import 'rng.dart';
import 'state/operation_state.dart';
import 'systems/character_system.dart';
import 'systems/operation_system.dart';

/// Engine entry point for operations on one rules pack (01 §Core loop).
///
/// Pure: no I/O, no clock, no randomness it was not handed. The pack is bound
/// at construction, so `decide` and `evolve` cannot run against the wrong
/// pack.
final class Engine {
  /// Creates an engine bound to [pack].
  Engine(this.pack)
    : _operation = OperationSystem(pack),
      _character = CharacterSystem(pack);

  /// The pack this engine runs.
  final RulesPack pack;

  final OperationSystem _operation;
  final CharacterSystem _character;

  /// Turns [command] into events, or a rejection, given [state].
  ///
  /// The only engine function that may draw from [rng] or [ids]. Runs on the
  /// GM's engine during an operation.
  Decision decide(
    OperationState state,
    Command command,
    Rng rng,
    IdSource ids,
  ) {
    if (!state.started && command is! StartOperation) {
      return const Rejected(
        Rejection(
          RejectionCode.notStarted,
          'The operation has not started yet.',
        ),
      );
    }
    try {
      return switch (command) {
        OperationCommand() => _operation.decide(state, command),
        CharacterCommand() => _character.decide(state, command, ids),
      };
    } on EvaluationException catch (e) {
      return Rejected(Rejection(RejectionCode.evaluationFailed, e.message));
    }
  }

  /// Applies [event] to [state]. Total and deterministic: no RNG, no ids, no
  /// failure path. Every client runs it.
  OperationState evolve(OperationState state, Event event) => switch (event) {
    OperationEvent() => _operation.evolve(state, event),
    CharacterEvent() => _character.evolve(state, event),
  };

  /// Folds [events] over [initial] with [evolve].
  OperationState replay(OperationState initial, Iterable<Event> events) =>
      events.fold(initial, evolve);
}
