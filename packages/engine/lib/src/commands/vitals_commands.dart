part of 'commands.dart';

/// Commands handled by `VitalsSystem`: Health and Sanity changes (§4, §7).
///
/// Today the GM enters every amount. Rolled damage, DR and sanity bands come
/// with the vitals rules (several of their values are pending D).
sealed class VitalsCommand extends Command {
  const VitalsCommand();
}

/// The GM applies damage the GM worked out.
final class ApplyDamage extends VitalsCommand {
  /// Creates the command.
  const ApplyDamage({
    required this.entity,
    required this.amount,
    this.check,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  });

  /// The entity that takes the damage.
  final EntityId entity;

  /// Health lost, at least 0.
  final int amount;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  /// Who sees the resulting event once the GM confirms it.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is ApplyDamage &&
      other.entity == entity &&
      other.amount == amount &&
      other.check == check &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(ApplyDamage, entity, amount, check, visibility, actor);

  @override
  String toString() => 'ApplyDamage(${entity.value}, $amount)';
}

/// The GM applies a sanity loss the GM worked out.
final class ApplySanityLoss extends VitalsCommand {
  /// Creates the command.
  const ApplySanityLoss({
    required this.entity,
    required this.amount,
    this.check,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  });

  /// The entity that loses Sanity.
  final EntityId entity;

  /// Sanity lost, at least 0.
  final int amount;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  /// Who sees the resulting event once the GM confirms it.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is ApplySanityLoss &&
      other.entity == entity &&
      other.amount == amount &&
      other.check == check &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(ApplySanityLoss, entity, amount, check, visibility, actor);

  @override
  String toString() => 'ApplySanityLoss(${entity.value}, $amount)';
}
