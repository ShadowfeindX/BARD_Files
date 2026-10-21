import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../expr/condition.dart';
import '../expr/evaluate.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

/// In-game messages (11 §Messaging). Today: the stat-gated broadcast. The
/// phone (04 §In-game phone) comes later.
///
/// Messages are not operation state: they live in the event log and the
/// text log, so `evolve` leaves the state as it is.
final class MessagingSystem {
  /// Creates the system for [pack].
  const MessagingSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides a [MessagingCommand].
  Decision decide(OperationState state, MessagingCommand command) =>
      switch (command) {
        BroadcastToQualifying() => _broadcast(state, command),
      };

  /// Applies a [MessagingEvent].
  OperationState evolve(OperationState state, MessagingEvent event) =>
      switch (event) {
        BroadcastEvaluated() || BroadcastDelivered() => state,
      };

  /// Every alias's result against [condition], without sending anything.
  ///
  /// The GM's preview of who would receive a broadcast. Agents (entity kind
  /// `agent`) owned by an alias are tested, in creation order; an alias with several agents is
  /// listed once per agent and qualifies if any of them passes.
  List<BroadcastCandidate> candidates(
    OperationState state,
    Condition condition,
  ) {
    final result = <BroadcastCandidate>[];
    for (final MapEntry(key: entity, value: identity)
        in state.stores.all(Identity.componentType).entries) {
      final alias = identity.ownerAlias;
      if (alias == null || identity.kind != EntityKind.agent) continue;
      final scores =
          state.stores.get(Attributes.componentType, entity)?.scores.asMap() ??
          const <String, int>{};
      ConditionResult? outcome;
      try {
        outcome = evaluateCondition(condition, attributes: scores);
      } on EvaluationException {
        outcome = null;
      }
      result.add(
        BroadcastCandidate(alias: alias, entity: entity, result: outcome),
      );
    }
    return result;
  }

  Decision _broadcast(OperationState state, BroadcastToQualifying command) {
    if (command.text.trim().isEmpty) {
      return const Rejected(
        Rejection(RejectionCode.invalidValue, 'The message is empty.'),
      );
    }
    for (final key in command.condition.attributeKeys) {
      if (pack.attribute(key) == null) {
        return Rejected(
          Rejection(RejectionCode.unknownPackKey, 'Unknown attribute "$key".'),
        );
      }
    }
    final evaluated = BroadcastEvaluated(
      text: command.text,
      condition: command.condition,
      candidates: candidates(state, command.condition),
      actor: command.actor,
    );
    final recipients = evaluated.recipients;
    return Accepted([
      evaluated,
      if (recipients.isNotEmpty)
        BroadcastDelivered(
          text: command.text,
          actor: command.actor,
          visibility: AliasesOnly(recipients),
        ),
    ]);
  }
}
