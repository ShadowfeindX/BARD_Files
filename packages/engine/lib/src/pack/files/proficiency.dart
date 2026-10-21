/// The pack file `proficiency.json`: proficiency tiers and the creation allotment.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One proficiency tier (`untrained`, `proficient`, `expert`).
final class ProficiencyTier {
  /// Creates a [ProficiencyTier].
  const ProficiencyTier({
    required this.key,
    required this.name,
    this.bonus,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Key stored in the `Skills` component.
  final String key;

  /// Display name.
  final String name;

  /// Extra dice the tier adds to a check (G16); `null` = no bonus.
  final Expr? bonus;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is ProficiencyTier &&
      other.key == key &&
      other.name == name &&
      other.bonus == bonus &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    ProficiencyTier,
    key,
    name,
    bonus,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'ProficiencyTier($key, $name, $bonus)';
}

/// How many skills of each tier an agent picks at creation (rulebook §3).
final class ProficiencyCreation {
  /// Creates a [ProficiencyCreation].
  const ProficiencyCreation({required this.counts});

  /// Count per proficiency tier key. Not enforced yet: whether the counts are exact or a maximum is not ruled.
  final ImmutableMap<String, int> counts;

  @override
  bool operator ==(Object other) =>
      other is ProficiencyCreation && other.counts == counts;

  @override
  int get hashCode => Object.hash(ProficiencyCreation, counts);

  @override
  String toString() => 'ProficiencyCreation($counts)';
}

/// What `proficiency.json` holds.
typedef ProficiencyFile = ({
  List<ProficiencyTier> tiers,
  ProficiencyCreation? creation,
});

/// Parses `proficiency.json`.
ProficiencyFile parseProficiency(ObjectReader r, int? packMajor) {
  final tiers = r.objects('tiers', (t) {
    final key = t.string('key');
    final name = t.string('name');
    // `null` here is a real value ("no bonus"), not a pending marker.
    final bonus = t.has('bonus') && t.raw('bonus') == null
        ? null
        : t.expr('bonus');
    final deprecated = t.deprecation(packMajor);
    final fields = t.deprecatedFields(packMajor);
    if (key == null || name == null) return null;
    return ProficiencyTier(
      key: key,
      name: name,
      bonus: bonus,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final creation = r.has('creation')
      ? r.object('creation', (c) {
          final counts = <String, int>{};
          for (final key in c.takeAll().keys.toList()) {
            final count = c.integer(key);
            if (count != null) counts[key] = count;
          }
          return ProficiencyCreation(counts: ImmutableMap.of(counts));
        })
      : null;
  r.prose('decided');
  return (tiers: tiers, creation: creation);
}
