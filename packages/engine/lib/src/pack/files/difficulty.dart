/// The pack file `difficulty.json`: difficulty categories and check rules.
///
/// Value types and their parser, kept together so a change to this file's
/// shape (Provisional, pending D) is a local edit.
library;

import '../../deprecation.dart';
import '../../expr/expr.dart';
import '../../expr/vars.dart';
import '../../immutable_map.dart';
import '../load/object_reader.dart';

/// One difficulty category and its DC (rulebook §2).
final class DifficultyCategory {
  /// Creates a [DifficultyCategory].
  const DifficultyCategory({
    required this.key,
    required this.name,
    required this.dc,
    this.deprecated,
    this.deprecatedFields = const ImmutableMap.empty(),
  });

  /// Category key (`F` ... `S`, `OMEGA`).
  final String key;

  /// Display name.
  final String name;

  /// Difficulty class. For Cat-Ω the Handler sets the value (G12); this is the printed default.
  final int dc;

  /// The entry's deprecation record (P11), if it is going away.
  final Deprecation? deprecated;

  /// Deprecation records for single fields, by field name.
  final ImmutableMap<String, Deprecation> deprecatedFields;

  @override
  bool operator ==(Object other) =>
      other is DifficultyCategory &&
      other.key == key &&
      other.name == name &&
      other.dc == dc &&
      other.deprecated == deprecated &&
      other.deprecatedFields == deprecatedFields;

  @override
  int get hashCode => Object.hash(
    DifficultyCategory,
    key,
    name,
    dc,
    deprecated,
    deprecatedFields,
  );

  @override
  String toString() => 'DifficultyCategory($key, $name, $dc)';
}

/// The pack's check values from `difficulty.json` `checkRules` (provisional location).
final class CheckRules {
  /// Creates a [CheckRules].
  const CheckRules({
    required this.primaryDie,
    required this.partialSuccessWithin,
    required this.fumbleFractionOfDc,
    required this.luckAdvantageAttribute,
    required this.luckAdvantageKeep,
    required this.assistanceGateCategory,
    required this.assistanceBonus,
  });

  /// The primary die of every check (rulebook: an exploding d6).
  final Expr primaryDie;

  /// A total this many points or fewer below the DC is a partial success.
  final int partialSuccessWithin;

  /// A fumble is at or below this fraction of the DC. Its basis is G1, pending D, so fumbles stay off.
  final num fumbleFractionOfDc;

  /// Attribute whose score gives the number of extra primary dice for advantage. What grants advantage is G2, pending D.
  final String luckAdvantageAttribute;

  /// Which result advantage keeps (`bestTotal`).
  final String luckAdvantageKeep;

  /// Difficulty category of a helper's gate check.
  final String assistanceGateCategory;

  /// Bonus a successful helper adds: `1d6 + var(helperSkillBonus)`.
  final Expr assistanceBonus;

  @override
  bool operator ==(Object other) =>
      other is CheckRules &&
      other.primaryDie == primaryDie &&
      other.partialSuccessWithin == partialSuccessWithin &&
      other.fumbleFractionOfDc == fumbleFractionOfDc &&
      other.luckAdvantageAttribute == luckAdvantageAttribute &&
      other.luckAdvantageKeep == luckAdvantageKeep &&
      other.assistanceGateCategory == assistanceGateCategory &&
      other.assistanceBonus == assistanceBonus;

  @override
  int get hashCode => Object.hash(
    CheckRules,
    primaryDie,
    partialSuccessWithin,
    fumbleFractionOfDc,
    luckAdvantageAttribute,
    luckAdvantageKeep,
    assistanceGateCategory,
    assistanceBonus,
  );

  @override
  String toString() =>
      'CheckRules($primaryDie, $partialSuccessWithin, $fumbleFractionOfDc)';
}

/// What `difficulty.json` holds.
typedef DifficultyFile = ({
  List<DifficultyCategory> categories,
  CheckRules? checkRules,
});

/// Parses `difficulty.json`.
DifficultyFile parseDifficulty(ObjectReader r, int? packMajor) {
  final categories = r.objects('categories', (c) {
    final key = c.string('key');
    final name = c.string('name');
    final dc = c.integer('dc');
    final deprecated = c.deprecation(packMajor);
    final fields = c.deprecatedFields(packMajor);
    if (key == null || name == null || dc == null) return null;
    return DifficultyCategory(
      key: key,
      name: name,
      dc: dc,
      deprecated: deprecated,
      deprecatedFields: ImmutableMap.of(fields),
    );
  });
  final checkRules = r.object('checkRules', (c) {
    final primaryDie = c.expr('primaryDie');
    final within = c.object(
      'partialSuccess',
      (p) => p.integer('withinPointsBelowDc'),
    );
    final fumble = c.object('fumble', (f) {
      final fraction = f.number('atOrBelowFractionOfDc');
      f.pendingSlot('basis'); // G1
      return fraction;
    });
    final advantage = c.object('luckAdvantage', (a) {
      final attribute = a.string('extraPrimaryDiceFrom');
      final keep = a.string('keep');
      a.pendingSlot('grantedBy'); // G2
      if (keep != null && keep != 'bestTotal') {
        a.error('keep', 'Expected "bestTotal".');
        return null;
      }
      if (attribute == null || keep == null) return null;
      return (attribute: attribute, keep: keep);
    });
    final assistance = c.object('assistance', (a) {
      final gate = a.string('gateCategory');
      final bonus = a.expr('bonus', allowedVars: {VarKeys.helperSkillBonus});
      a.pendingSlot('cap'); // G4
      if (gate == null || bonus == null) return null;
      return (gate: gate, bonus: bonus);
    });
    if (primaryDie == null ||
        within == null ||
        fumble == null ||
        advantage == null ||
        assistance == null) {
      return null;
    }
    return CheckRules(
      primaryDie: primaryDie,
      partialSuccessWithin: within,
      fumbleFractionOfDc: fumble,
      luckAdvantageAttribute: advantage.attribute,
      luckAdvantageKeep: advantage.keep,
      assistanceGateCategory: assistance.gate,
      assistanceBonus: assistance.bonus,
    );
  });
  return (categories: categories, checkRules: checkRules);
}
