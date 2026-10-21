part of 'events.dart';

/// Events applied by `VitalsSystem`.
sealed class VitalsEvent extends Event {
  const VitalsEvent();
}

/// An entity lost Health.
final class DamageApplied extends VitalsEvent implements Consequence {
  /// Creates the event.
  const DamageApplied({
    required this.entity,
    required this.amount,
    this.overriddenFrom,
    this.check,
    required this.actor,
    required this.visibility,
  });

  /// The entity that took the damage.
  final EntityId entity;

  /// Health lost.
  final int amount;

  /// The amount before the GM edited it in review, or `null` when not edited
  /// (F2: the edit sits beside the original).
  final int? overriddenFrom;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  /// Returns the event as the GM edited it in review: [newAmount], with the
  /// original amount kept in [overriddenFrom].
  DamageApplied withAmount(int newAmount) => DamageApplied(
    entity: entity,
    amount: newAmount,
    overriddenFrom: overriddenFrom ?? amount,
    check: check,
    actor: actor,
    visibility: visibility,
  );

  @override
  bool operator ==(Object other) =>
      other is DamageApplied &&
      other.entity == entity &&
      other.amount == amount &&
      other.overriddenFrom == overriddenFrom &&
      other.check == check &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    DamageApplied,
    entity,
    amount,
    overriddenFrom,
    check,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'DamageApplied(${entity.value}, $amount'
      '${overriddenFrom == null ? '' : ', was $overriddenFrom'})';
}

/// An entity lost Sanity.
final class SanityLost extends VitalsEvent implements Consequence {
  /// Creates the event.
  const SanityLost({
    required this.entity,
    required this.amount,
    this.overriddenFrom,
    this.check,
    required this.actor,
    required this.visibility,
  });

  /// The entity that lost Sanity.
  final EntityId entity;

  /// Sanity lost.
  final int amount;

  /// The amount before the GM edited it in review, or `null` when not edited.
  final int? overriddenFrom;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  /// Returns the event as the GM edited it in review: [newAmount], with the
  /// original amount kept in [overriddenFrom].
  SanityLost withAmount(int newAmount) => SanityLost(
    entity: entity,
    amount: newAmount,
    overriddenFrom: overriddenFrom ?? amount,
    check: check,
    actor: actor,
    visibility: visibility,
  );

  @override
  bool operator ==(Object other) =>
      other is SanityLost &&
      other.entity == entity &&
      other.amount == amount &&
      other.overriddenFrom == overriddenFrom &&
      other.check == check &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    SanityLost,
    entity,
    amount,
    overriddenFrom,
    check,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'SanityLost(${entity.value}, $amount'
      '${overriddenFrom == null ? '' : ', was $overriddenFrom'})';
}
