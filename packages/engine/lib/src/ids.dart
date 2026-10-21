/// Opaque identifier of an entity (agent, NPC, item, scene, ...).
///
/// An entity is an id and nothing else; what it *is* depends on which
/// components it has. Ids are generated inside `decide` from an injected
/// [IdSource] and recorded in the creating event, so every client agrees on
/// them.
extension type const EntityId(String value) {}

/// Supplies new entity ids during `decide`.
///
/// Injected like the RNG so the engine never invents ids itself. The session
/// layer decides how production ids are made.
abstract interface class IdSource {
  /// Returns an id that has not been returned before by this source.
  EntityId next();
}

/// Deterministic [IdSource] that returns `<prefix>1`, `<prefix>2`, ...
///
/// Useful in tests and anywhere ids only need to be unique within one
/// operation. Start from [start] to continue a sequence after a reload.
final class SequentialIdSource implements IdSource {
  /// Creates a source whose first id is `<prefix><start>`.
  SequentialIdSource({this.prefix = 'e', int start = 1}) : _next = start;

  /// Text placed before the counter in every id.
  final String prefix;

  int _next;

  @override
  EntityId next() => EntityId('$prefix${_next++}');
}
