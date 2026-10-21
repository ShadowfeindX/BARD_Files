/// Value types of the check flow (01 §Commands and events, §Dice and
/// checks): ids, difficulty, modifiers, the stored check, its breakdown and
/// outcome, and the RNG draw range a roll used.
///
/// Names and fields are Proposed.
library;

import '../equality.dart';
import '../expr/evaluate.dart';
import '../ids.dart';

/// Opaque id of a player's action request.
extension type const RequestId(String value) {}

/// Opaque id of a check the GM required.
extension type const CheckId(String value) {}

/// How hard a check is, as the GM sets it.
sealed class Difficulty {
  const Difficulty();
}

/// A pack difficulty category (`F` ... `S`, `OMEGA`); its DC comes from the
/// pack.
final class CategoryDifficulty extends Difficulty {
  /// Creates a category difficulty.
  const CategoryDifficulty(this.category);

  /// Pack difficulty category key.
  final String category;

  @override
  bool operator ==(Object other) =>
      other is CategoryDifficulty && other.category == category;

  @override
  int get hashCode => Object.hash(CategoryDifficulty, category);

  @override
  String toString() => 'CategoryDifficulty($category)';
}

/// The largest magnitude the engine accepts for a number the GM types in:
/// a fixed DC, a modifier, a damage or sanity amount. Proposed.
///
/// A check total and an accumulated loss are sums of these. Keeping each part
/// within 32 bits keeps every sum far below 2^53, so the same value results
/// on the VM and the web [V-14], and an absurd entry is refused before any
/// die is drawn (draw-count invariant).
const int maxEnteredValue = 2147483647;

/// A DC the GM states outright, for example a Cat-Ω value the Handler sets
/// (G12) or a DC no category matches.
final class FixedDifficulty extends Difficulty {
  /// Creates a fixed difficulty.
  const FixedDifficulty(this.dc);

  /// The DC.
  final int dc;

  @override
  bool operator ==(Object other) => other is FixedDifficulty && other.dc == dc;

  @override
  int get hashCode => Object.hash(FixedDifficulty, dc);

  @override
  String toString() => 'FixedDifficulty($dc)';
}

/// A situational modifier the GM adds to a check, with where it came from.
final class CheckModifier {
  /// Creates a modifier.
  const CheckModifier(this.label, this.value);

  /// What the modifier is for, as shown in the breakdown ("Cover", ...).
  final String label;

  /// Points added to the total (negative for a penalty).
  final int value;

  @override
  bool operator ==(Object other) =>
      other is CheckModifier && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(CheckModifier, label, value);

  @override
  String toString() => 'CheckModifier($label, $value)';
}

/// Everything fixed about a check when the GM requires it.
///
/// Stored in `CheckRequired` and held in state until the check resolves, so
/// the event alone says what was asked (events are self-sufficient).
final class CheckSpec {
  /// Creates a check spec.
  CheckSpec({
    required this.entity,
    required this.attribute,
    this.skill,
    this.category,
    required this.dc,
    List<CheckModifier> modifiers = const [],
    this.request,
  }) : modifiers = List.unmodifiable(modifiers);

  /// The entity that rolls.
  final EntityId entity;

  /// Pack attribute key added to the roll.
  final String attribute;

  /// Pack skill id whose proficiency adds dice, or `null` for a plain
  /// attribute check.
  final String? skill;

  /// The difficulty category the DC came from, or `null` for a fixed DC.
  final String? category;

  /// The difficulty class.
  final int dc;

  /// Situational modifiers, in order.
  final List<CheckModifier> modifiers;

  /// The action request this check answers, if any.
  final RequestId? request;

  @override
  bool operator ==(Object other) =>
      other is CheckSpec &&
      other.entity == entity &&
      other.attribute == attribute &&
      other.skill == skill &&
      other.category == category &&
      other.dc == dc &&
      listEquals(other.modifiers, modifiers) &&
      other.request == request;

  @override
  int get hashCode => Object.hash(
    CheckSpec,
    entity,
    attribute,
    skill,
    category,
    dc,
    Object.hashAll(modifiers),
    request,
  );

  @override
  String toString() =>
      'CheckSpec(${entity.value}, $attribute, skill: $skill, '
      'dc: $dc${category == null ? '' : ' ($category)'}, $modifiers)';
}

/// Where a check's faces came from (concern 7, reserved).
///
/// Only [RollSourceKind.rng] is produced. Entered faces (players rolling
/// physical dice) are reserved so logs written today stay valid; the feature
/// is pending D and is not built.
enum RollSourceKind {
  /// The operation's RNG rolled the faces.
  rng,

  /// Someone entered physical dice faces. Reserved, never produced yet.
  entered,
}

/// The range of RNG draws a rolling event used: `[start, end)`.
///
/// Folding the event sets the operation's draw count to [end] (01 §RNG), so
/// the GM can audit any roll from the seed.
final class DrawRange {
  /// Creates a range. Throws an [ArgumentError] unless
  /// `0 <= start <= end`.
  DrawRange(this.start, this.end) {
    if (start < 0 || end < start) {
      throw ArgumentError('Invalid draw range [$start, $end).');
    }
  }

  /// Draw count before rolling.
  final int start;

  /// Draw count after rolling.
  final int end;

  /// Number of draws used.
  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is DrawRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(DrawRange, start, end);

  @override
  String toString() => 'DrawRange[$start, $end)';
}

/// The result band of a check (rulebook §2).
///
/// A fumble is not produced: its basis is gap G1, pending D (setup decision
/// 1: a feature that needs a pending value stays off).
enum CheckOutcome {
  /// The total reached the DC.
  success,

  /// The total fell short of the DC by no more than the pack's partial
  /// success margin.
  partialSuccess,

  /// The total fell further short.
  failure,
}

/// Every part of a resolved check, as rolled (01: the UI renders the
/// breakdown and never recomputes it).
final class CheckBreakdown {
  /// Creates a breakdown.
  CheckBreakdown({
    required this.primary,
    required this.attribute,
    required this.attributeScore,
    this.skill,
    this.tier,
    this.proficiency,
    List<CheckModifier> modifiers = const [],
  }) : modifiers = List.unmodifiable(modifiers);

  /// The primary die as rolled, explosions included.
  final Term primary;

  /// Pack attribute key.
  final String attribute;

  /// The entity's score in [attribute] when the check resolved.
  final int attributeScore;

  /// Pack skill id, or `null` for a plain attribute check.
  final String? skill;

  /// The entity's proficiency tier in [skill], or `null` when it has none
  /// recorded.
  final String? tier;

  /// The tier's bonus dice as rolled, or `null` when the tier adds none.
  final Term? proficiency;

  /// Situational modifiers, in order.
  final List<CheckModifier> modifiers;

  /// Sum of every part.
  num get total => normalizeNumber(
    primary.value +
        attributeScore +
        (proficiency?.value ?? 0) +
        modifiers.fold<int>(0, (a, m) => a + m.value),
  );

  @override
  bool operator ==(Object other) =>
      other is CheckBreakdown &&
      other.primary == primary &&
      other.attribute == attribute &&
      other.attributeScore == attributeScore &&
      other.skill == skill &&
      other.tier == tier &&
      other.proficiency == proficiency &&
      listEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(
    CheckBreakdown,
    primary,
    attribute,
    attributeScore,
    skill,
    tier,
    proficiency,
    Object.hashAll(modifiers),
  );

  @override
  String toString() =>
      'CheckBreakdown($primary + $attribute $attributeScore'
      '${proficiency == null ? '' : ' + $tier $proficiency'}'
      ' + $modifiers = $total)';
}
