import '../components/components.dart';
import '../commands/commands.dart';
import '../decision.dart';
import '../events/events.dart';
import '../ids.dart';
import '../pack/rules_pack.dart';
import '../state/operation_state.dart';
import '../visibility.dart';

/// Character creation and changes (rulebook §3, §9).
///
/// Today it creates agents. Advancement purchases come later.
final class CharacterSystem {
  /// Creates the system for [pack].
  const CharacterSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides a [CharacterCommand].
  Decision decide(
    OperationState state,
    CharacterCommand command,
    IdSource ids,
  ) => switch (command) {
    CreateAgent() => _createAgent(command, ids),
  };

  /// Applies a [CharacterEvent].
  OperationState evolve(OperationState state, CharacterEvent event) =>
      switch (event) {
        AgentCreated() => state.copyWith(
          stores: state.stores
              .put(
                event.entity,
                Identity(
                  name: event.name,
                  kind: EntityKind.agent,
                  ownerAlias: event.ownerAlias,
                ),
              )
              .put(event.entity, Attributes(event.attributes.asMap()))
              .put(event.entity, Skills(event.skills.asMap())),
        ),
      };

  Decision _createAgent(CreateAgent command, IdSource ids) {
    final problem = _checkAgent(command);
    if (problem != null) return Rejected(problem);
    final owner = command.ownerAlias;
    return Accepted([
      AgentCreated(
        entity: ids.next(),
        name: command.name,
        attributes: command.attributes.asMap(),
        skills: command.skills.asMap(),
        ownerAlias: owner,
        actor: command.actor,
        // Proposed: an agent's sheet is seen by the GM and its owner.
        visibility: owner == null ? const GmOnly() : AliasesOnly({owner}),
      ),
    ]);
  }

  Rejection? _checkAgent(CreateAgent command) {
    if (command.name.trim().isEmpty) {
      return const Rejection(RejectionCode.invalidValue, 'The name is empty.');
    }
    for (final key in command.attributes.keys) {
      if (pack.attribute(key) == null) {
        return Rejection(
          RejectionCode.unknownPackKey,
          'Unknown attribute "$key".',
        );
      }
    }
    final limits = pack.attributeCreation;
    for (final attribute in pack.attributes) {
      final score = command.attributes[attribute.key];
      if (score == null) {
        return Rejection(
          RejectionCode.invalidValue,
          'No score for ${attribute.name} (${attribute.key}).',
        );
      }
      if (score < limits.minPerAttribute || score > limits.maxPerAttribute) {
        return Rejection(
          RejectionCode.invalidValue,
          '${attribute.name} is $score; at creation it must be between '
          '${limits.minPerAttribute} and ${limits.maxPerAttribute}.',
        );
      }
    }
    for (final MapEntry(key: skillId, value: tier) in command.skills.entries) {
      if (pack.skill(skillId) == null) {
        return Rejection(
          RejectionCode.unknownPackKey,
          'Unknown skill "$skillId".',
        );
      }
      if (pack.proficiencyTier(tier) == null) {
        return Rejection(
          RejectionCode.unknownPackKey,
          'Unknown proficiency tier "$tier" for skill "$skillId".',
        );
      }
    }
    return null;
  }
}
