/// Components: the immutable values attached to entities (01 §ECS model).
///
/// A component never stores a value that can be derived (Health max, Evasion,
/// ...); those are read models over [Attributes] and pack formulas. Keys
/// inside components are pack values, validated against the active pack.
///
/// This holds the components the engine core needs today. Later systems add
/// theirs here; each new component is a new [ComponentType] constant.
library;

import '../actor.dart';
import '../immutable_map.dart';

/// Names one component type and its stable serialization key.
///
/// Used to address ECS stores with type safety:
/// `state.stores.get(Attributes.componentType, id)` returns an [Attributes].
final class ComponentType<C extends Component> {
  const ComponentType._(this.typeKey);

  /// Stable key used in serialization. Never changes within an engine major.
  final String typeKey;

  @override
  String toString() => 'ComponentType($typeKey)';
}

/// An immutable value attached to an entity.
sealed class Component {
  const Component();

  /// This component's type.
  ComponentType<Component> get type;
}

/// What kind of thing an entity is, for display and filtering only.
///
/// Rules never branch on this; they look at which components an entity has.
enum EntityKind {
  /// A player character.
  agent,

  /// A GM-run character.
  npc,

  /// A hostile GM-run character or creature.
  adversary,

  /// A carried or placed object.
  item,

  /// A vehicle.
  vehicle,

  /// An occult artifact.
  artifact,

  /// A place.
  location,

  /// A scene.
  scene,
}

/// Name, kind and owning alias of an entity.
final class Identity extends Component {
  /// Creates an identity.
  const Identity({required this.name, required this.kind, this.ownerAlias});

  /// The [ComponentType] of [Identity].
  static const componentType = ComponentType<Identity>._('identity');

  /// Display name.
  final String name;

  /// What kind of entity this is.
  final EntityKind kind;

  /// The alias that controls this entity, or `null` for GM-controlled ones.
  final AliasId? ownerAlias;

  @override
  ComponentType<Identity> get type => componentType;

  @override
  bool operator ==(Object other) =>
      other is Identity &&
      other.name == name &&
      other.kind == kind &&
      other.ownerAlias == ownerAlias;

  @override
  int get hashCode => Object.hash(Identity, name, kind, ownerAlias);

  @override
  String toString() => 'Identity($name, ${kind.name}, owner: $ownerAlias)';
}

/// Attribute scores, keyed by pack attribute key.
final class Attributes extends Component {
  /// Creates attribute scores.
  Attributes(Map<String, int> scores) : scores = ImmutableMap.of(scores);

  /// The [ComponentType] of [Attributes].
  static const componentType = ComponentType<Attributes>._('attributes');

  /// Score per attribute key.
  final ImmutableMap<String, int> scores;

  /// The score for [key], or `null` when the entity has none.
  int? operator [](String key) => scores[key];

  @override
  ComponentType<Attributes> get type => componentType;

  @override
  bool operator ==(Object other) =>
      other is Attributes && other.scores == scores;

  @override
  int get hashCode => Object.hash(Attributes, scores);

  @override
  String toString() => 'Attributes(${scores.asMap()})';
}

/// Proficiency tier per skill, keyed by pack skill id.
///
/// A skill with no entry has no recorded tier; how that rolls belongs to the
/// check system.
final class Skills extends Component {
  /// Creates skill tiers.
  Skills(Map<String, String> tiers) : tiers = ImmutableMap.of(tiers);

  /// The [ComponentType] of [Skills].
  static const componentType = ComponentType<Skills>._('skills');

  /// Proficiency tier key per skill id.
  final ImmutableMap<String, String> tiers;

  /// The tier key for [skillId], or `null` when not listed.
  String? operator [](String skillId) => tiers[skillId];

  @override
  ComponentType<Skills> get type => componentType;

  @override
  bool operator ==(Object other) => other is Skills && other.tiers == tiers;

  @override
  int get hashCode => Object.hash(Skills, tiers);

  @override
  String toString() => 'Skills(${tiers.asMap()})';
}

/// Every component type the engine knows, by [ComponentType.typeKey].
///
/// Decoders use it to refuse component types from a newer engine.
const Map<String, ComponentType<Component>> componentTypes = {
  'identity': Identity.componentType,
  'attributes': Attributes.componentType,
  'skills': Skills.componentType,
};
