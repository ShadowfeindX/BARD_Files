/// An immutable map with value equality.
///
/// Every "change" returns a new map and leaves the original untouched, which
/// is what keeps engine state an immutable value (00 §Cross-cutting
/// principles).
///
/// It is copy-on-write: [put] and [remove] copy the entries. Operation state
/// holds tens or hundreds of entities, where a copy is cheap. If profiling
/// ever shows this matters, a structurally shared map can replace the inside
/// of this class without changing its API (01 §State keeps that choice
/// internal to the engine).
final class ImmutableMap<K, V> {
  /// Creates an empty map.
  const ImmutableMap.empty() : _entries = const {};

  /// Creates a map holding a copy of [entries].
  ImmutableMap.of(Map<K, V> entries) : _entries = Map.unmodifiable(entries);

  ImmutableMap._(this._entries);

  final Map<K, V> _entries;

  /// The value stored for [key], or `null` when there is none.
  V? operator [](K key) => _entries[key];

  /// Whether [key] has a value.
  bool containsKey(K key) => _entries.containsKey(key);

  /// Number of entries.
  int get length => _entries.length;

  /// Whether the map has no entries.
  bool get isEmpty => _entries.isEmpty;

  /// Whether the map has at least one entry.
  bool get isNotEmpty => _entries.isNotEmpty;

  /// The keys, in insertion order.
  Iterable<K> get keys => _entries.keys;

  /// The values, in key insertion order.
  Iterable<V> get values => _entries.values;

  /// The entries, in insertion order.
  Iterable<MapEntry<K, V>> get entries => _entries.entries;

  /// A read-only [Map] view of the entries.
  Map<K, V> asMap() => _entries;

  /// Returns a map with [key] set to [value].
  ImmutableMap<K, V> put(K key, V value) =>
      ImmutableMap._(Map.unmodifiable({..._entries, key: value}));

  /// Returns a map without [key]. Returns this map when [key] is absent.
  ImmutableMap<K, V> remove(K key) {
    if (!_entries.containsKey(key)) return this;
    return ImmutableMap._(Map.unmodifiable(Map.of(_entries)..remove(key)));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ImmutableMap<K, V> || other.length != length) return false;
    for (final entry in _entries.entries) {
      if (!other.containsKey(entry.key) || other[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    _entries.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'ImmutableMap($_entries)';
}
