/// The pack file `strings/`: display text, one file per language.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// Display text for one language, from `strings/<language>.json`.
final class PackStrings {
  /// Creates a [PackStrings].
  const PackStrings({required this.language, required this.entries});

  /// Language code.
  final String language;

  /// Text by key.
  final ImmutableMap<String, String> entries;

  @override
  bool operator ==(Object other) =>
      other is PackStrings &&
      other.language == language &&
      other.entries == entries;

  @override
  int get hashCode => Object.hash(PackStrings, language, entries);

  @override
  String toString() => 'PackStrings($language, $entries)';
}

/// Parses one file of `strings/`. Every key but `language` is a text entry.
PackStrings? parseStrings(ObjectReader r) {
  final language = r.string('language');
  final entries = <String, String>{};
  for (final MapEntry(:key, :value) in r.takeAll().entries) {
    if (key == 'language') continue;
    if (value is String) {
      entries[key] = value;
    } else {
      r.error(key, 'Expected text.');
    }
  }
  if (language == null) return null;
  return PackStrings(language: language, entries: ImmutableMap.of(entries));
}
