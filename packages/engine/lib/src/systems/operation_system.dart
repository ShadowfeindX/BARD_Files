import '../commands/commands.dart';
import '../decision.dart';
import '../events/events.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../version.dart';

/// The operation's lifecycle: starting it and its settings. Proposed system;
/// 01 §Systems does not list one for this.
final class OperationSystem {
  /// Creates the system for [pack].
  const OperationSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides an [OperationCommand].
  Decision decide(OperationState state, OperationCommand command) =>
      switch (command) {
        StartOperation() => _start(state, command),
      };

  /// Applies an [OperationEvent].
  OperationState evolve(OperationState state, OperationEvent event) =>
      switch (event) {
        OperationStarted() => state.copyWith(
          meta: OperationMeta(
            operationId: event.operationId,
            engineVersion: event.engineVersion,
            packRef: event.packRef,
            settings: event.settings,
          ),
        ),
      };

  Decision _start(OperationState state, StartOperation command) {
    if (state.started) {
      return const Rejected(
        Rejection(
          RejectionCode.alreadyStarted,
          'The operation has already started.',
        ),
      );
    }
    if (command.operationId.isEmpty) {
      return const Rejected(
        Rejection(RejectionCode.invalidValue, 'The operation id is empty.'),
      );
    }
    return Accepted([
      OperationStarted(
        operationId: command.operationId,
        engineVersion: engineVersion,
        packRef: pack.ref,
        settings: command.settings,
        actor: command.actor,
      ),
    ]);
  }
}
