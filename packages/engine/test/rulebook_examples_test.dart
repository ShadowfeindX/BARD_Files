/// The rulebook's worked examples (PDF page 10, "Example Rolls"), pinning the
/// check arithmetic to the book (08 §Engine). Verbatim text:
/// project library `rulebook/p10-worked-examples.md`.
///
/// What the tests leave out, and why:
/// - "Expert Demolitions" (example 2) is not in the book's skill list, and
///   example 3's "Occult" skill belongs to the occult rules (pending D). Both
///   use test-only skills here, so no skill or occult ruling is implied.
/// - Example 3's "Extreme DC 21" is an old difficulty name (G13); it is
///   given as a fixed DC 21.
/// - INT 4 (example 2) and WIL 6 (example 3) are above the creation maximum,
///   so the scores are set directly, as advancement would.
/// - Only the primary d6 explodes (page 11, as printed); no G1 (fumble), G2
///   (advantage) or wider G3 (other dice) ruling is used.
library;

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/table.dart';
import 'support/test_pack.dart';

void main() {
  /// The test pack plus three test-only skills for the examples.
  RulesPack examplePack() {
    final base = testPack();
    return RulesPack(
      ref: base.ref,
      attributes: base.attributes,
      attributeCreation: base.attributeCreation,
      proficiencyTiers: base.proficiencyTiers,
      skillCategories: base.skillCategories,
      skills: [
        ...base.skills,
        for (final (id, attribute) in [
          ('test-climbing', 'DEX'),
          ('test-demolitions', 'INT'),
          ('test-channeling', 'WIL'),
        ])
          SkillDef(
            id: id,
            name: id,
            description: 'Test-only skill for a rulebook example.',
            category: 'physical',
            attribute: attribute,
          ),
      ],
      derived: base.derived,
      difficultyCategories: base.difficultyCategories,
      checkRules: base.checkRules,
    );
  }

  /// Rolls one check for Vale with [scores] and [tiers] set directly, the
  /// RNG scripted with [faces].
  CheckResolved roll({
    required List<int> faces,
    required Map<String, int> scores,
    required String skill,
    required String tier,
    required Difficulty difficulty,
  }) {
    final table = Table(faces: faces, pack: examplePack());
    table.state = table.state.copyWith(
      stores: table.state.stores
          .put(Table.vale, Attributes({...validScores(), ...scores}))
          .put(Table.vale, Skills({skill: tier})),
    );
    final check =
        (table
                    .run(
                      RequireCheck(
                        entity: Table.vale,
                        skill: skill,
                        difficulty: difficulty,
                      ),
                    )
                    .single
                as CheckRequired)
            .check;
    final resolved =
        table.run(ResolveCheck(check: check)).single as CheckResolved;
    expect(resolved.draws, DrawRange(0, faces.length));
    return resolved;
  }

  test('example 1, basic task: Hall climbs a wall, Cat-C DC 10', () {
    // 1d6(5) + Proficiency 1d4(3) + DEX(2) = 10: success.
    final result = roll(
      faces: [5, 3],
      scores: {'DEX': 2},
      skill: 'test-climbing',
      tier: 'proficient',
      difficulty: const CategoryDifficulty('C'),
    );
    expect(result.spec.dc, 10);
    expect(result.breakdown.primary.value, 5);
    expect(result.breakdown.proficiency!.value, 3);
    expect(result.breakdown.attributeScore, 2);
    expect(result.total, 10);
    expect(result.outcome, CheckOutcome.success);
  });

  test('example 2, hard challenge: Vale disarms a bomb, Cat-B DC 13', () {
    // 1d6(5) + Expert 1d6(4) + INT(4) = 13: "barely succeeds". The book's
    // "barely" is the Handler's description; a total equal to the DC is a
    // success.
    final result = roll(
      faces: [5, 4],
      scores: {'INT': 4},
      skill: 'test-demolitions',
      tier: 'expert',
      difficulty: const CategoryDifficulty('B'),
    );
    expect(result.spec.dc, 13);
    expect(
      result.breakdown.proficiency,
      DiceTerm(
        sides: 6,
        explode: null,
        rolls: [
          DieRoll([4]),
        ],
      ),
    );
    expect(result.total, 13);
    expect(result.outcome, CheckOutcome.success);
  });

  test('example 3, extreme feat: Grimm closes a rift, DC 21', () {
    // 1d6(6, explodes, +2) + Proficient 1d4(3) + WIL(6) = 17: failure.
    final result = roll(
      faces: [6, 2, 3],
      scores: {'WIL': 6},
      skill: 'test-channeling',
      tier: 'proficient',
      difficulty: const FixedDifficulty(21),
    );
    expect((result.breakdown.primary as DiceTerm).rolls.single.faces, [6, 2]);
    expect(result.breakdown.primary.value, 8);
    expect(result.total, 17);
    // 4 short of the DC, outside the partial-success margin of 2.
    expect(result.outcome, CheckOutcome.failure);
  });
}
