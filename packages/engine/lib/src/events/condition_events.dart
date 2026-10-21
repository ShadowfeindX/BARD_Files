part of 'events.dart';

/// Events applied by `ConditionSystem`.
sealed class ConditionEvent extends Event {
  const ConditionEvent();
}

/// An entity gained a condition.
///
/// A consequence (F2), so the GM reviews it before anyone sees it. The GM may
/// drop it from the batch or replace the condition; a replacement keeps the
/// original in [overriddenFrom].
final class ConditionApplied extends ConditionEvent implements Consequence {
  /// Creates the event.
  const ConditionApplied({
    required this.entity,
    required this.condition,
    this.overriddenFrom,
    this.check,
    required this.actor,
    required this.visibility,
  });

  /// The entity that gained the condition.
  final EntityId entity;

  /// Pack condition id.
  final String condition;

  /// The condition before the GM replaced it in review, or `null` when not
  /// edited.
  final String? overriddenFrom;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  /// Returns the event as the GM edited it in review: [newCondition], with
  /// the original kept in [overriddenFrom]. Throws an [ArgumentError] when
  /// [newCondition] is empty; the session checks it against the pack.
  ConditionApplied withCondition(String newCondition) {
    if (newCondition.isEmpty) {
      throw ArgumentError.value(newCondition, 'newCondition', 'is empty');
    }
    return ConditionApplied(
      entity: entity,
      condition: newCondition,
      overriddenFrom: overriddenFrom ?? condition,
      check: check,
      actor: actor,
      visibility: visibility,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConditionApplied &&
      other.entity == entity &&
      other.condition == condition &&
      other.overriddenFrom == overriddenFrom &&
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
