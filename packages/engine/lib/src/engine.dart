import 'commands/commands.dart';
import 'decision.dart';
import 'events/events.dart';
import 'expr/evaluate.dart';
import 'ids.dart';
import 'pack/rules_pack.dart';
import 'rng.dart';
import 'state/operation_state.dart';
import 'systems/character_system.dart';
import 'systems/check_system.dart';
import 'systems/condition_system.dart';
import 'systems/operation_system.dart';
import 'systems/vitals_system.dart';

/// Engine entry point for operations on one rules pack (01 §Core loop).
///
/// Pure: no I/O, no clock, no randomness it was not handed. The pack is bound
/// at construction, so `decide` and `evolve` cannot run against the wrong
/// pack.
final class Engine {
  /// Creates an engine bound to [pack].
  Engine(this.pack)
    : _operation = OperationSystem(pack),
      _character = CharacterSystem(pack),
      _check = CheckSystem(pack),
      _condition = ConditionSystem(pack);

  /// The pack this engine runs.
  final RulesPack pack;

  final OperationSystem _operation;
  final CharacterSystem _character;
  final CheckSystem _check;
  final ConditionSystem _condition;
  final VitalsSystem _vitals = const VitalsSystem();

  /// Turns [command] into events, or a rejection, given [state].
  ///
  /// The only engine function that may draw from [rng] or [ids]. Runs on the
  /// GM's engine during an operation.
  ///
  /// A rejection never consumes a draw (draw-count invariant): systems
  /// validate before rolling. Throws a [StateError] if a rejection did draw,
  /// because that roll could no longer be audited; it means a system missed
  /// a check, and is a bug.
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
    // The pinned pack decides every outcome (02 §Operations pin packs), so an
    // engine bound to any other pack must not decide for this operation.
    final pinned = state.meta?.packRef;
    if (pinned != null && pinned != pack.ref) {
      return Rejected(
        Rejection(
          RejectionCode.packMismatch,
          'The operation pins $pinned but this engine runs ${pack.ref}.',
        ),
      );
    }
    final drawsBefore = rng.drawCount;
    Decision decision;
    try {
      decision = switch (command) {
        OperationCommand() => _operation.decide(state, command),
        CharacterCommand() => _character.decide(state, command, ids),
        CheckCommand() => _check.decide(state, command, rng, ids),
        VitalsCommand() => _vitals.decide(state, command),
        ConditionCommand() => _condition.decide(state, command),
      };
    } on EvaluationException catch (e) {
      decision = Rejected(Rejection(RejectionCode.evaluationFailed, e.message));
    }
    if (decision is Rejected && rng.drawCount != drawsBefore) {
      throw StateError(
        'A rejected ${command.runtimeType} drew from the RNG '
        '($drawsBefore to ${rng.drawCount}).',
      );
    }
    return decision;
  }

  /// Applies [event] to [state]. Total and deterministic: no RNG, no ids, no
  /// failure path. Every client runs it.
  ///
  /// A [RollingEvent] also sets the draw count to the end of its range when
  /// that is past the current count, here in one place for every rolling
  /// event. The count never moves back.
  OperationState evolve(OperationState state, Event event) {
    final next = switch (event) {
      OperationEvent() => _operation.evolve(state, event),
      CharacterEvent() => _character.evolve(state, event),
      CheckEvent() => _check.evolve(state, event),
      VitalsEvent() => _vitals.evolve(state, event),
      ConditionEvent() => _condition.evolve(state, event),
    };
    return switch (event) {
      // The highest end so far: a held consequence batch confirmed after
      // later rolls has a lower range, and must not move the count back.
      RollingEvent(:final draws) when draws.end > next.rng.drawCount =>
        next.copyWith(rng: RngState(drawCount: draws.end)),
      _ => next,
    };
  }

  /// Folds [events] over [initial] with [evolve].
  OperationState replay(OperationState initial, Iterable<Event> events) =>
      events.fold(initial, evolve);
}
