import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../ids.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';

/// Conditions and afflictions on entities (rulebook §4).
///
/// The GM applies and clears pack conditions; applied ones are held for GM
/// review by the session (F2). Durations and ticking come later.
final class ConditionSystem {
  /// Creates the system for [pack].
  const ConditionSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides a [ConditionCommand].
  Decision decide(OperationState state, ConditionCommand command) =>
      switch (command) {
        ApplyCondition() => _apply(state, command),
        ClearCondition() => _clear(state, command),
      };

  /// Applies a [ConditionEvent].
  OperationState evolve(OperationState state, ConditionEvent event) =>
      switch (event) {
        ConditionApplied(:final entity, :final condition) => _set(
          state,
          entity,
          {..._active(state, entity), condition},
        ),
        ConditionCleared(:final entity, :final condition) => _set(
          state,
          entity,
          _active(state, entity).difference({condition}),
        ),
      };

  Decision _apply(OperationState state, ApplyCondition command) {
    final problem = _check(state, command.entity, command.condition);
    if (problem != null) return problem;
    if (_active(state, command.entity).contains(command.condition)) {
      return Rejected(
        Rejection(
          RejectionCode.invalidValue,
          '${command.entity.value} already has "${command.condition}".',
        ),
      );
    }
    return Accepted([
      ConditionApplied(
        entity: command.entity,
        condition: command.condition,
        check: command.check,
        actor: command.actor,
        visibility: command.visibility,
      ),
    ]);
  }

  Decision _clear(OperationState state, ClearCondition command) {
    final problem = _check(state, command.entity, command.condition);
    if (problem != null) return problem;
    if (!_active(state, command.entity).contains(command.condition)) {
      return Rejected(
        Rejection(
          RejectionCode.invalidValue,
          '${command.entity.value} does not have "${command.condition}".',
        ),
      );
    }
    return Accepted([
      ConditionCleared(
        entity: command.entity,
        condition: command.condition,
        actor: command.actor,
        visibility: command.visibility,
      ),
    ]);
  }

  Rejected? _check(OperationState state, EntityId entity, String condition) {
    if (!state.stores.has(Identity.componentType, entity)) {
      return Rejected(
        Rejection(RejectionCode.unknownEntity, 'No entity "${entity.value}".'),
      );
    }
    if (pack.condition(condition) == null) {
      return Rejected(
        Rejection(
          RejectionCode.unknownPackKey,
          'Unknown condition "$condition".',
        ),
      );
    }
    return null;
  }

  Set<String> _active(OperationState state, EntityId entity) =>
      state.stores.get(Conditions.componentType, entity)?.ids ?? const {};

  OperationState _set(OperationState state, EntityId entity, Set<String> ids) =>
      state.copyWith(
        stores: ids.isEmpty
            ? state.stores.remove(Conditions.componentType, entity)
            : state.stores.put(entity, Conditions(ids)),
      );
}
