@TestOn('vm')
library;

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/provisional_pack.dart';
import 'support/test_pack.dart';

/// The worked examples (`rulebook_examples_test.dart`) take their DCs from
/// the test pack; this pins those DCs to the provisional pack in
/// `content_core` too, so the two cannot drift apart (gate review of row 5).
void main() {
  final provisional = loadPack(provisionalPackFiles()).pack!;
  final fixture = testPack();

  for (final (category, dc) in [('C', 10), ('B', 13)]) {
    test('Cat-$category is DC $dc in the provisional and the test pack', () {
      expect(provisional.difficultyCategory(category)?.dc, dc);
      expect(fixture.difficultyCategory(category)?.dc, dc);
    });
  }

  test('the primary die is an exploding d6 in both packs', () {
    expect(provisional.checkRules!.primaryDie, fixture.checkRules!.primaryDie);
  });

  test('both packs give Proficient a d4 and Expert a d6', () {
    for (final pack in [provisional, fixture]) {
      expect(pack.proficiencyTier('proficient')!.bonus, isA<Dice>());
      expect((pack.proficiencyTier('proficient')!.bonus! as Dice).sides, 4);
      expect((pack.proficiencyTier('expert')!.bonus! as Dice).sides, 6);
    }
  });
}
