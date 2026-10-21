part of 'events.dart';

/// Events applied by `ConditionSystem`.
sealed class ConditionEvent extends Event {
  const ConditionEvent();
}

/// An entity gained a condition.
///
/// A consequence (F2), so the GM reviews it before anyone sees it; the GM's
/// edit here is to drop it from the batch or replace the condition.
final class ConditionApplied extends ConditionEvent implements Consequence {
  /// Creates the event.
  const ConditionApplied({
    required this.entity,
    required this.condition,
    this.check,
    required this.actor,
    required this.visibility,
  });

  /// The entity that gained the condition.
  final EntityId entity;

  /// Pack condition id.
  final String condition;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is ConditionApplied &&
      other.entity == entity &&
      other.condition == condition &&
      other.check == check &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    ConditionApplied,
    entity,
    condition,
    check,
    actor,
    visibility,
  );

  @override
  String toString() => 'ConditionApplied(${entity.value}, $condition)';
}

/// An active condition was cleared by the GM.
///
/// Not a consequence: it is a direct GM edit, not an outcome to review.
final class ConditionCleared extends ConditionEvent {
  /// Creates the event.
  const ConditionCleared({
    required this.entity,
    required this.condition,
    required this.actor,
    required this.visibility,
  });

  /// The entity that lost the condition.
  final EntityId entity;

  /// Pack condition id.
  final String condition;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is ConditionCleared &&
      other.entity == entity &&
      other.condition == condition &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode =>
      Object.hash(ConditionCleared, entity, condition, actor, visibility);

  @override
  String toString() => 'ConditionCleared(${entity.value}, $condition)';
}
