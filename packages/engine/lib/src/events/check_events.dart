part of 'events.dart';

/// Events applied by `CheckSystem`.
sealed class CheckEvent extends Event {
  const CheckEvent();
}

/// A player asked to take an action.
final class ActionRequested extends CheckEvent {
  /// Creates the event.
  const ActionRequested({
    required this.request,
    required this.entity,
    required this.description,
    this.suggestedSkill,
    required this.actor,
    required this.visibility,
  });

  /// The new request's id.
  final RequestId request;

  /// The entity that wants to act.
  final EntityId entity;

  /// What the player wants to do.
  final String description;

  /// The pack skill id the player suggests, if any.
  final String? suggestedSkill;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is ActionRequested &&
      other.request == request &&
      other.entity == entity &&
      other.description == description &&
      other.suggestedSkill == suggestedSkill &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    ActionRequested,
    request,
    entity,
    description,
    suggestedSkill,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'ActionRequested(${request.value}, ${entity.value}, "$description")';
}

/// The GM closed a request without a check.
final class RequestDeclined extends CheckEvent {
  /// Creates the event.
  const RequestDeclined({
    required this.request,
    this.reason,
    required this.actor,
    required this.visibility,
  });

  /// The closed request.
  final RequestId request;

  /// Optional words for the player.
  final String? reason;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is RequestDeclined &&
      other.request == request &&
      other.reason == reason &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode =>
      Object.hash(RequestDeclined, request, reason, actor, visibility);

  @override
  String toString() => 'RequestDeclined(${request.value}, $reason)';
}

/// The GM required a check. It stays pending until `CheckResolved`.
final class CheckRequired extends CheckEvent {
  /// Creates the event.
  const CheckRequired({
    required this.check,
    required this.spec,
    required this.actor,
    required this.visibility,
  });

  /// The new check's id.
  final CheckId check;

  /// What was asked, DC included.
  final CheckSpec spec;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is CheckRequired &&
      other.check == check &&
      other.spec == spec &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode =>
      Object.hash(CheckRequired, check, spec, actor, visibility);

  @override
  String toString() => 'CheckRequired(${check.value}, $spec)';
}

/// A check was rolled: the full breakdown, total, DC and outcome.
///
/// Never edited and never held for review (F2): the GM's control is over
/// consequences, not rolls.
final class CheckResolved extends CheckEvent implements RollingEvent {
  /// Creates the event.
  const CheckResolved({
    required this.check,
    required this.spec,
    required this.breakdown,
    required this.outcome,
    required this.draws,
    this.source = RollSourceKind.rng,
    required this.actor,
    required this.visibility,
  });

  /// The resolved check.
  final CheckId check;

  /// What was asked, DC included.
  final CheckSpec spec;

  /// Every part of the roll.
  final CheckBreakdown breakdown;

  /// The result band.
  final CheckOutcome outcome;

  @override
  final DrawRange draws;

  /// Where the faces came from. Only `rng` is produced (concern 7).
  final RollSourceKind source;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  /// The check's total.
  num get total => breakdown.total;

  @override
  bool operator ==(Object other) =>
      other is CheckResolved &&
      other.check == check &&
      other.spec == spec &&
      other.breakdown == breakdown &&
      other.outcome == outcome &&
      other.draws == draws &&
      other.source == source &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    CheckResolved,
    check,
    spec,
    breakdown,
    outcome,
    draws,
    source,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'CheckResolved(${check.value}, $breakdown vs ${spec.dc}: '
      '${outcome.name}, $draws)';
}
