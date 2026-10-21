import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../ids.dart';
import '../state/operation_state.dart';

/// Health and Sanity losses (rulebook §4, §7).
///
/// Today the GM enters every amount; the session holds the resulting events
/// for GM review (F2). Damage dice, DR and sanity bands come later, several
/// of their values being pending D. Current values are not clamped: what
/// happens at or below 0 is a later rule.
final class VitalsSystem {
  /// Creates the system.
  const VitalsSystem();

  /// Decides a [VitalsCommand].
  Decision decide(OperationState state, VitalsCommand command) =>
      switch (command) {
        ApplyDamage() =>
          _check(state, command.entity, command.amount) ??
              Accepted([
                DamageApplied(
                  entity: command.entity,
                  amount: command.amount,
                  check: command.check,
                  actor: command.actor,
                  visibility: command.visibility,
                ),
              ]),
        ApplySanityLoss() =>
          _check(state, command.entity, command.amount) ??
              Accepted([
                SanityLost(
                  entity: command.entity,
                  amount: command.amount,
                  check: command.check,
                  actor: command.actor,
                  visibility: command.visibility,
                ),
              ]),
      };

  /// Applies a [VitalsEvent].
  OperationState evolve(OperationState state, VitalsEvent event) {
    final (entity, update) = switch (event) {
      DamageApplied(:final entity, :final amount) => (
        entity,
        (Vitals v) => v.copyWith(damageTaken: v.damageTaken + amount),
      ),
      SanityLost(:final entity, :final amount) => (
        entity,
        (Vitals v) => v.copyWith(sanityLost: v.sanityLost + amount),
      ),
    };
    return state.copyWith(
      stores: state.stores.put(entity, update(_vitals(state, entity))),
    );
  }

  Vitals _vitals(OperationState state, EntityId entity) =>
      state.stores.get(Vitals.componentType, entity) ?? const Vitals();

  Rejected? _check(OperationState state, EntityId entity, int amount) {
    if (!state.stores.has(Attributes.componentType, entity)) {
      return Rejected(
        Rejection(
          RejectionCode.unknownEntity,
          'No character "${entity.value}".',
        ),
      );
    }
    if (amount < 0) {
      return Rejected(
        Rejection(
          RejectionCode.invalidValue,
          'The amount is $amount; it must be 0 or more.',
        ),
      );
    }
    return null;
  }
}
