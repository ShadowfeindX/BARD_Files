/// Opaque identifier of an alias: a character an agent plays in one
/// operation (11 §Terminology).
extension type const AliasId(String value) {}

/// Who issued a command or caused an event.
///
/// The engine records the actor but never checks permissions with it: who may
/// send what is the session layer's job (04 §The operation loop).
sealed class Actor {
  const Actor();
}

/// The operation's GM (the Handler).
final class GmActor extends Actor {
  /// The GM actor. There is one GM per operation, so it carries no id.
  const GmActor();

  @override
  bool operator ==(Object other) => other is GmActor;

  @override
  int get hashCode => (GmActor).hashCode;

  @override
  String toString() => 'GmActor()';
}

/// A player acting through one of their aliases.
final class AliasActor extends Actor {
  /// Creates an alias actor.
  const AliasActor(this.alias);

  /// The alias the player is acting as.
  final AliasId alias;

  @override
  bool operator ==(Object other) => other is AliasActor && other.alias == alias;

  @override
  int get hashCode => Object.hash(AliasActor, alias);

  @override
  String toString() => 'AliasActor(${alias.value})';
}
