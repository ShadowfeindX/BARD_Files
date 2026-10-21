part of 'commands.dart';

/// Commands handled by `ConditionSystem`: conditions and afflictions (§4).
sealed class ConditionCommand extends Command {
  const ConditionCommand();
}

/// The GM applies a pack condition to an entity.
final class ApplyCondition extends ConditionCommand {
  /// Creates the command.
  const ApplyCondition({
    required this.entity,
    required this.condition,
    this.check,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  });

  /// The entity that gains the condition.
  final EntityId entity;

  /// Pack condition id.
  final String condition;

  /// The resolved check this follows from, if any.
  final CheckId? check;

  /// Who sees the resulting event once the GM confirms it.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is ApplyCondition &&
      other.entity == entity &&
      other.condition == condition &&
      other.check == check &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(ApplyCondition, entity, condition, check, visibility, actor);

  @override
  String toString() => 'ApplyCondition(${entity.value}, $condition)';
}

/// The GM clears an active condition.
final class ClearCondition extends ConditionCommand {
  /// Creates the command.
  const ClearCondition({
    required this.entity,
    required this.condition,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  });

  /// The entity that loses the condition.
  final EntityId entity;

  /// Pack condition id.
  final String condition;

  /// Who sees the resulting event once the GM confirms it.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is ClearCondition &&
      other.entity == entity &&
      other.condition == condition &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(ClearCondition, entity, condition, visibility, actor);

  @override
  String toString() => 'ClearCondition(${entity.value}, $condition)';
}
