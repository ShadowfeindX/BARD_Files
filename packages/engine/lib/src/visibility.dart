import 'actor.dart';

/// Who may see an event once it is broadcast.
///
/// The GM sees every event. The session filters each participant's stream by
/// this value (04 §Perspectives); the engine only sets it. Proposed shape.
sealed class Visibility {
  const Visibility();

  /// Whether a player acting as [alias] may see the event.
  bool visibleTo(AliasId alias);
}

/// Every participant sees the event.
final class Public extends Visibility {
  /// The public visibility.
  const Public();

  @override
  bool visibleTo(AliasId alias) => true;

  @override
  bool operator ==(Object other) => other is Public;

  @override
  int get hashCode => (Public).hashCode;

  @override
  String toString() => 'Public()';
}

/// Only the GM sees the event.
final class GmOnly extends Visibility {
  /// The GM-only visibility.
  const GmOnly();

  @override
  bool visibleTo(AliasId alias) => false;

  @override
  bool operator ==(Object other) => other is GmOnly;

  @override
  int get hashCode => (GmOnly).hashCode;

  @override
  String toString() => 'GmOnly()';
}

/// The GM and the listed aliases see the event.
final class AliasesOnly extends Visibility {
  /// Creates a visibility for [aliases]. Throws an [ArgumentError] when empty;
  /// use [GmOnly] for "nobody but the GM".
  AliasesOnly(Set<AliasId> aliases) : aliases = Set.unmodifiable(aliases) {
    if (aliases.isEmpty) {
      throw ArgumentError.value(aliases, 'aliases', 'must not be empty');
    }
  }

  /// The aliases that may see the event.
  final Set<AliasId> aliases;

  @override
  bool visibleTo(AliasId alias) => aliases.contains(alias);

  @override
  bool operator ==(Object other) =>
      other is AliasesOnly &&
      other.aliases.length == aliases.length &&
      other.aliases.containsAll(aliases);

  @override
  int get hashCode =>
      Object.hash(AliasesOnly, Object.hashAllUnordered(aliases));

  @override
  String toString() => 'AliasesOnly(${aliases.map((a) => a.value).toList()})';
}
