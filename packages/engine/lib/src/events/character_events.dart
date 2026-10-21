part of 'events.dart';

/// Events applied by `CharacterSystem`.
sealed class CharacterEvent extends Event {
  const CharacterEvent();
}

/// An agent was created with the listed scores and skill tiers.
final class AgentCreated extends CharacterEvent {
  /// Creates the event.
  AgentCreated({
    required this.entity,
    required this.name,
    required Map<String, int> attributes,
    required Map<String, String> skills,
    required this.ownerAlias,
    required this.actor,
    required this.visibility,
  }) : attributes = ImmutableMap.of(attributes),
       skills = ImmutableMap.of(skills);

  /// The new entity's id.
  final EntityId entity;

  /// Display name.
  final String name;

  /// Score per pack attribute key.
  final ImmutableMap<String, int> attributes;

  /// Proficiency tier key per pack skill id.
  final ImmutableMap<String, String> skills;

  /// The controlling alias, or `null` while unassigned.
  final AliasId? ownerAlias;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is AgentCreated &&
      other.entity == entity &&
      other.name == name &&
      other.attributes == attributes &&
      other.skills == skills &&
      other.ownerAlias == ownerAlias &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    AgentCreated,
    entity,
    name,
    attributes,
    skills,
    ownerAlias,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'AgentCreated(${entity.value}, $name, ${attributes.asMap()}, '
      '${skills.asMap()}, owner: $ownerAlias)';
}
