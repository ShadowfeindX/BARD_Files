import '../commands/commands.dart';
import '../components/components.dart';
import '../decision.dart';
import '../events/events.dart';
import '../expr/condition.dart';
import '../expr/evaluate.dart';
import '../actor.dart';
import '../pack/rules_pack.dart';
import '../phone.dart';
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
        SendPhoneMessage() => _phone(state, command),
      };

  /// Applies a [MessagingEvent].
  OperationState evolve(OperationState state, MessagingEvent event) =>
      switch (event) {
        BroadcastEvaluated() ||
        BroadcastDelivered() ||
        PhoneMessageSent() => state,
      };

  /// Every alias's result against [condition], without sending anything.
  ///
  /// The GM's preview of who would receive a broadcast. Each alias's agent
  /// (entity kind `agent`; an alias plays at most one) is tested, in
  /// creation order.
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

  Decision _phone(OperationState state, SendPhoneMessage command) {
    final text = command.text;
    if (_isBlank(text)) {
      return _reject(RejectionCode.invalidValue, 'The message is empty.');
    }
    if (text.length > maxPhoneTextUnits) {
      return _reject(
        RejectionCode.invalidValue,
        'The message is longer than $maxPhoneTextUnits characters.',
      );
    }
    final from = command.from;
    final to = command.to;
    // The sender must be the actor: a player speaks only as their own alias,
    // the Handler only as themselves or a GM-run entity.
    final allowed = switch ((command.actor, from)) {
      (AliasActor(:final alias), PhoneAlias(alias: final sender)) =>
        alias == sender,
      (GmActor(), PhoneGm() || PhoneNpc()) => true,
      _ => false,
    };
    if (!allowed) {
      return _reject(
        RejectionCode.invalidValue,
        '${command.actor} cannot send as $from.',
      );
    }
    // Who may talk to whom: aliases to anyone but themselves; the Handler and
    // GM-run entities only to aliases.
    final pairing = switch ((from, to)) {
      (PhoneAlias(:final alias), PhoneAlias(alias: final other)) =>
        alias != other,
      (PhoneAlias(), _) => true,
      (_, PhoneAlias()) => true,
      _ => false,
    };
    if (!pairing) {
      return _reject(RejectionCode.invalidValue, '$from cannot message $to.');
    }
    for (final party in [from, to]) {
      if (!_exists(state, party)) {
        return _reject(
          RejectionCode.unknownEntity,
          'That recipient is not available.',
        );
      }
    }
    final aliases = {
      for (final party in [from, to])
        if (party is PhoneAlias) party.alias,
    };
    return Accepted([
      PhoneMessageSent(
        from: from,
        to: to,
        text: text,
        actor: command.actor,
        visibility: AliasesOnly(aliases),
      ),
    ]);
  }

  bool _exists(OperationState state, PhoneParty party) {
    final identities = state.stores.all(Identity.componentType);
    return switch (party) {
      PhoneGm() => true,
      PhoneAlias(:final alias) => identities.values.any(
        (i) => i.ownerAlias == alias,
      ),
      PhoneNpc(:final entity) =>
        identities[entity]?.ownerAlias == null &&
            identities.containsKey(entity),
    };
  }

  Decision _reject(RejectionCode code, String message) =>
      Rejected(Rejection(code, message));

  /// Whether [text] shows nothing: only whitespace and invisible format
  /// characters. An explicit list rather than `\p{Cf}`, which can differ by
  /// Unicode version between the VM and JS.
  bool _isBlank(String text) =>
      text.replaceAll(invisiblePhoneChars, '').trim().isEmpty;
}
