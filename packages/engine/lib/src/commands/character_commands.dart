part of 'commands.dart';

/// Commands handled by `CharacterSystem`: creating and changing characters.
sealed class CharacterCommand extends Command {
  const CharacterCommand();
}

/// Creates an agent (player character) with attribute scores and skill
/// tiers.
///
/// The engine checks every key against the pack and each score against the
/// pack's creation limits. Whether the scores must add up to the pack's
/// creation points exactly or at most is not ruled, so the total is not
/// checked yet.
final class CreateAgent extends CharacterCommand {
  /// Creates the command. [skills] maps skill id to proficiency tier key;
  /// skills not listed get no entry.
  CreateAgent({
    required this.name,
    required Map<String, int> attributes,
    Map<String, String> skills = const {},
    this.ownerAlias,
    this.actor = const GmActor(),
  }) : attributes = ImmutableMap.of(attributes),
       skills = ImmutableMap.of(skills);

  /// Display name.
  final String name;

  /// Score per pack attribute key. Must list every pack attribute.
  final ImmutableMap<String, int> attributes;

  /// Proficiency tier key per pack skill id.
  final ImmutableMap<String, String> skills;

  /// The alias that will control the agent, or `null` while unassigned.
  final AliasId? ownerAlias;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is CreateAgent &&
      other.name == name &&
      other.attributes == attributes &&
      other.skills == skills &&
      other.ownerAlias == ownerAlias &&
      other.actor == actor;

  @override
  int get hashCode =>
      Object.hash(CreateAgent, name, attributes, skills, ownerAlias, actor);

  @override
  String toString() =>
      'CreateAgent($name, ${attributes.asMap()}, ${skills.asMap()}, '
      'owner: $ownerAlias, by $actor)';
}
