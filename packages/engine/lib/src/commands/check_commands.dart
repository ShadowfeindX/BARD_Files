part of 'commands.dart';

/// Commands handled by `CheckSystem`: action requests and checks (§2, §5).
sealed class CheckCommand extends Command {
  const CheckCommand();
}

/// A player asks to take an action; the GM answers with a check or declines.
final class RequestAction extends CheckCommand {
  /// Creates the command.
  const RequestAction({
    required this.entity,
    required this.description,
    this.suggestedSkill,
    required this.actor,
  });

  /// The entity that wants to act (the player's agent).
  final EntityId entity;

  /// What the player wants to do, in their words.
  final String description;

  /// The pack skill id the player suggests, if any.
  final String? suggestedSkill;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is RequestAction &&
      other.entity == entity &&
      other.description == description &&
      other.suggestedSkill == suggestedSkill &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(RequestAction, entity, description, suggestedSkill, actor);

  @override
  String toString() =>
      'RequestAction(${entity.value}, "$description", $suggestedSkill, '
      'by $actor)';
}

/// The GM declines an open action request without a check.
final class DeclineRequest extends CheckCommand {
  /// Creates the command.
  const DeclineRequest({
    required this.request,
    this.reason,
    this.actor = const GmActor(),
  });

  /// The request to close.
  final RequestId request;

  /// Optional words for the player.
  final String? reason;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is DeclineRequest &&
      other.request == request &&
      other.reason == reason &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(DeclineRequest, request, reason, actor);

  @override
  String toString() => 'DeclineRequest(${request.value}, $reason)';
}

/// The GM requires a check: `primary die + attribute + proficiency dice +
/// modifiers` against a DC (§2).
///
/// [attribute] may be left out when [skill] names a skill whose pack
/// attribute is set; the skill's attribute is used. With the operation's
/// auto-resolve setting on, the check rolls at once.
final class RequireCheck extends CheckCommand {
  /// Creates the command.
  RequireCheck({
    required this.entity,
    this.attribute,
    this.skill,
    required this.difficulty,
    List<CheckModifier> modifiers = const [],
    this.request,
    this.visibility = const Public(),
    this.actor = const GmActor(),
  }) : modifiers = List.unmodifiable(modifiers);

  /// The entity that rolls.
  final EntityId entity;

  /// Pack attribute key, or `null` to use [skill]'s attribute.
  final String? attribute;

  /// Pack skill id, or `null` for a plain attribute check.
  final String? skill;

  /// How hard the check is.
  final Difficulty difficulty;

  /// Situational modifiers, in order.
  final List<CheckModifier> modifiers;

  /// The action request this check answers, if any. It closes the request.
  final RequestId? request;

  /// Who sees the check and its result. [GmOnly] makes a secret check;
  /// [Redacted] tells players only that the GM rolled something.
  final Visibility visibility;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is RequireCheck &&
      other.entity == entity &&
      other.attribute == attribute &&
      other.skill == skill &&
      other.difficulty == difficulty &&
      listEquals(other.modifiers, modifiers) &&
      other.request == request &&
      other.visibility == visibility &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(
    RequireCheck,
    entity,
    attribute,
    skill,
    difficulty,
    Object.hashAll(modifiers),
    request,
    visibility,
    actor,
  );

  @override
  String toString() =>
      'RequireCheck(${entity.value}, $attribute, $skill, $difficulty, '
      '$modifiers)';
}

/// The GM rolls a required check.
final class ResolveCheck extends CheckCommand {
  /// Creates the command.
  const ResolveCheck({required this.check, this.actor = const GmActor()});

  /// The check to roll.
  final CheckId check;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is ResolveCheck && other.check == check && other.actor == actor;

  @override
  int get hashCode => Object.hash(ResolveCheck, check, actor);

  @override
  String toString() => 'ResolveCheck(${check.value})';
}
