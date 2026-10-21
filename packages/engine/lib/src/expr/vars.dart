/// The `var` keys the engine supplies, one per approved placement.
///
/// Approved by R 2026-10-20 (01 §Dice and checks). Adding a key or a placement
/// goes to R first; nothing else may be read by a `Var` node.
abstract final class VarKeys {
  /// The attribute score being bought: advancement attribute purchase XP,
  /// `10 × var(newScore)` in `advancement.json`.
  static const newScore = 'newScore';

  /// The helper's skill bonus: assistance bonus, `1d6 + var(helperSkillBonus)`
  /// in `difficulty.json`.
  static const helperSkillBonus = 'helperSkillBonus';

  /// Every approved key.
  static const all = {newScore, helperSkillBonus};
}
