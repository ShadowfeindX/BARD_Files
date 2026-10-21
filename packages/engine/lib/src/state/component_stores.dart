import '../components/components.dart';
import '../ids.dart';
import '../immutable_map.dart';

/// The ECS stores: one map of entity id to component per component type
/// (01 §State).
///
/// Immutable. Every change returns new stores and leaves this one as it was.
final class ComponentStores {
  /// Stores with no components.
  const ComponentStores.empty() : _byType = const ImmutableMap.empty();

  const ComponentStores._(this._byType);

  /// Component maps keyed by [ComponentType.typeKey]. A type with no
  /// components has no entry, so equal contents always compare equal.
  final ImmutableMap<String, ImmutableMap<EntityId, Component>> _byType;

  /// The [type] component of [entity], or `null` when it has none.
  C? get<C extends Component>(ComponentType<C> type, EntityId entity) =>
      _byType[type.typeKey]?[entity] as C?;

  /// Whether [entity] has a [type] component.
  bool has(ComponentType<Component> type, EntityId entity) =>
      _byType[type.typeKey]?.containsKey(entity) ?? false;

  /// Every entity with a [type] component, with that component.
  ImmutableMap<EntityId, C> all<C extends Component>(ComponentType<C> type) {
    final store = _byType[type.typeKey];
    if (store == null) return const ImmutableMap.empty();
    return ImmutableMap.of({
      for (final entry in store.entries) entry.key: entry.value as C,
    });
  }

  /// Every entity that has at least one component.
  Set<EntityId> get entities => {
    for (final store in _byType.values) ...store.keys,
  };

  /// Returns stores with [component] set on [entity], replacing any component
  /// of the same type.
  ComponentStores put(EntityId entity, Component component) {
    final key = component.type.typeKey;
    final store = _byType[key] ?? const ImmutableMap.empty();
    return ComponentStores._(_byType.put(key, store.put(entity, component)));
  }

  /// Returns stores without [entity]'s [type] component.
  ComponentStores remove(ComponentType<Component> type, EntityId entity) {
    final store = _byType[type.typeKey];
    if (store == null || !store.containsKey(entity)) return this;
    final rest = store.remove(entity);
    return ComponentStores._(
      rest.isEmpty
          ? _byType.remove(type.typeKey)
          : _byType.put(type.typeKey, rest),
    );
  }

  /// Returns stores without any component of [entity].
  ComponentStores removeEntity(EntityId entity) {
    var byType = _byType;
    for (final entry in _byType.entries) {
      if (!entry.value.containsKey(entity)) continue;
      final rest = entry.value.remove(entity);
      byType = rest.isEmpty
          ? byType.remove(entry.key)
          : byType.put(entry.key, rest);
    }
    return ComponentStores._(byType);
  }

  @override
  bool operator ==(Object other) =>
      other is ComponentStores && other._byType == _byType;

  @override
  int get hashCode => _byType.hashCode;

  @override
  String toString() => 'ComponentStores(${_byType.asMap()})';
}
