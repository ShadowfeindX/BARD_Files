/// A deprecation record (P11, 01 §Deprecation): something that still works
/// in this major but is going away.
///
/// The same shape marks engine schema items and pack entries. In a pack,
/// [since] and [removeIn] are pack versions.
final class Deprecation {
  /// Creates a record.
  const Deprecation({
    required this.since,
    required this.removeIn,
    required this.note,
    this.replacedBy,
  });

  /// Version that introduced the deprecation, in the declaring scope.
  final String since;

  /// Major (same scope) in which the item may disappear.
  final int removeIn;

  /// Why, and what to do instead.
  final String note;

  /// The successor: `kind:id` for entries, `owner.field` for fields.
  final String? replacedBy;

  @override
  bool operator ==(Object other) =>
      other is Deprecation &&
      other.since == since &&
      other.removeIn == removeIn &&
      other.note == note &&
      other.replacedBy == replacedBy;

  @override
  int get hashCode => Object.hash(since, removeIn, note, replacedBy);

  @override
  String toString() =>
      'Deprecation(since $since, removeIn $removeIn'
      '${replacedBy == null ? '' : ', replacedBy $replacedBy'}: $note)';
}
