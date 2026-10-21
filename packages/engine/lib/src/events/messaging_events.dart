part of 'events.dart';

/// Events applied by `MessagingSystem`.
sealed class MessagingEvent extends Event {
  const MessagingEvent();
}

/// How one alias fared against a broadcast condition.
final class BroadcastCandidate {
  /// Creates a candidate.
  const BroadcastCandidate({
    required this.alias,
    required this.entity,
    required this.result,
  });

  /// The alias.
  final AliasId alias;

  /// The alias's agent the condition was tested on.
  final EntityId entity;

  /// The values compared and whether they passed, or `null` when the agent
  /// lacks a score the condition reads (it does not qualify).
  final ConditionResult? result;

  /// Whether the alias receives the message.
  bool get qualifies => result?.passed ?? false;

  @override
  bool operator ==(Object other) =>
      other is BroadcastCandidate &&
      other.alias == alias &&
      other.entity == entity &&
      other.result == result;

  @override
  int get hashCode => Object.hash(alias, entity, result);

  @override
  String toString() =>
      'BroadcastCandidate(${alias.value}, ${entity.value}, $result)';
}

/// The GM's record of a stat-gated broadcast: the text, the condition and
/// every alias's result. Always GM-only, so the condition stays hidden.
final class BroadcastEvaluated extends MessagingEvent {
  /// Creates the event.
  BroadcastEvaluated({
    required this.text,
    required this.condition,
    required List<BroadcastCandidate> candidates,
    required this.actor,
  }) : candidates = List.unmodifiable(candidates);

  /// The message.
  final String text;

  /// The condition tested.
  final Condition condition;

  /// Every alias with an agent, in creation order.
  final List<BroadcastCandidate> candidates;

  /// The aliases that receive the message.
  Set<AliasId> get recipients => {
    for (final c in candidates)
      if (c.qualifies) c.alias,
  };

  @override
  final Actor actor;

  @override
  Visibility get visibility => const GmOnly();

  @override
  bool operator ==(Object other) =>
      other is BroadcastEvaluated &&
      other.text == text &&
      other.condition == condition &&
      listEquals(other.candidates, candidates) &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(
    BroadcastEvaluated,
    text,
    condition,
    Object.hashAll(candidates),
    actor,
  );

  @override
  String toString() => 'BroadcastEvaluated("$text", $condition, $candidates)';
}

/// The broadcast text, delivered to the qualifying aliases only.
///
/// Not emitted when nobody qualifies. Players never see who else received
/// it (R, 2026-10-21): [visibility] lists every recipient for the host's
/// filter, and the session strips that list from each player's copy.
final class BroadcastDelivered extends MessagingEvent {
  /// Creates the event.
  const BroadcastDelivered({
    required this.text,
    required this.actor,
    required this.visibility,
  });

  /// The message.
  final String text;

  @override
  final Actor actor;

  /// `AliasesOnly` with the qualifying aliases.
  @override
  final AliasesOnly visibility;

  @override
  bool operator ==(Object other) =>
      other is BroadcastDelivered &&
      other.text == text &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(BroadcastDelivered, text, actor, visibility);

  @override
  String toString() => 'BroadcastDelivered("$text", $visibility)';
}
