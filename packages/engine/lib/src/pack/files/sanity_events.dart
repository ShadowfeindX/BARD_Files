/// The pack file `sanity_events.json`: the sanity loss table.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One row of the sanity loss table (rulebook §4).
final class SanityEvent {
  /// Creates a [SanityEvent].
  const SanityEvent({
    required this.key,
    required this.name,
    required this.min,
    this.max,
    this.openEnded = false,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Event key.
  final String key;

  /// Display name.
  final String name;

  /// Lowest loss in the printed range.
  final int min;

  /// Highest loss; `null` when open-ended.
  final int? max;

  /// Whether the range has no top (for example 8+).
  final bool openEnded;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is SanityEvent &&
      other.key == key &&
      other.name == name &&
      other.min == min &&
      other.max == max &&
      other.openEnded == openEnded &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    SanityEvent,
    key,
    name,
    min,
    max,
    openEnded,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'SanityEvent($key, $name, $min)';
}

/// Parses `sanity_events.json`.
List<SanityEvent> parseSanityEvents(ObjectReader r, int? packMajor) {
  final events = r.objects('events', (e) {
    final key = e.string('key');
    final name = e.string('name');
    final min = e.integer('min');
    final openEnded = e.flag('openEnded');
    // An open-ended row (8+) has no top, so its max may be null.
    final max = openEnded == true && e.raw('max') == null
        ? null
        : e.integer('max');
    final deprecated = e.deprecation(packMajor);
    final fields = e.deprecatedFields(packMajor);
    if (key == null || name == null || min == null || openEnded == null) {
      return null;
    }
    return SanityEvent(
      key: key,
      name: name,
      min: min,
      max: max,
      openEnded: openEnded,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  r.pendingSlot('valueChoice'); // G5
  r.pendingSlot('fumble'); // G5
  return events;
}
