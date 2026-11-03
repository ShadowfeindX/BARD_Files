import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/table.dart';
import 'support/test_pack.dart';

void main() {
  RulesPack packWith(RandomTable table) {
    final base = testPack();
    return RulesPack(
      ref: base.ref,
      attributes: base.attributes,
      attributeCreation: base.attributeCreation,
      proficiencyTiers: base.proficiencyTiers,
      skillCategories: base.skillCategories,
      skills: base.skills,
      derived: base.derived,
      difficultyCategories: base.difficultyCategories,
      checkRules: base.checkRules,
      conditions: base.conditions,
      randomTables: [table],
    );
  }

  test('a roll picks the row its total selects and records the draws', () {
    final t = Table(faces: [5]);
    final events = t.run(
      const RollTable(table: 'test-table', entity: Table.vale),
    );
    final rolled = events.single as TableRolled;
    expect(rolled.faces, [5]);
    expect(rolled.total, 5);
    expect(rolled.sides, 6);
    expect(rolled.text, 'High.');
    expect(rolled.entity, Table.vale);
    expect(rolled.draws, DrawRange(0, 1));
    expect(rolled, isA<RollingEvent>());
    expect(rolled, isNot(isA<Consequence>()));
    expect(t.state.rng.drawCount, 1);
  });

  test('several dice are summed', () {
    final t = Table(
      faces: [2, 3],
      pack: packWith(
        RandomTable(
          id: 'two',
          name: 'Two',
          dice: Dice(count: 2, sides: 6),
          rows: const [
            RandomTableRow(from: 2, to: 4, text: 'Low.'),
            RandomTableRow(from: 5, to: 12, text: 'High.'),
          ],
        ),
      ),
    );
    final rolled = t.run(const RollTable(table: 'two')).single as TableRolled;
    expect(rolled.faces, [2, 3]);
    expect(rolled.text, 'High.');
    expect(rolled.draws, DrawRange(0, 2));
  });

  test('the visibility is the command\'s', () {
    final t = Table(faces: [1]);
    final rolled =
        t.run(const RollTable(table: 'test-table', visibility: GmOnly())).single
            as TableRolled;
    expect(rolled.visibility, const GmOnly());
  });

  group('refusals draw nothing', () {
    test('unknown table', () {
      final t = Table(faces: [1]);
      expect(
        rejection(t.decide(const RollTable(table: 'nope'))),
        RejectionCode.unknownPackKey,
      );
      expect(t.rng.drawCount, 0);
    });

    test('a table whose dice are pending D', () {
      final t = Table(
        faces: [1],
        pack: packWith(RandomTable(id: 'p', name: 'P', dice: null, rows: [])),
      );
      expect(
        rejection(t.decide(const RollTable(table: 'p'))),
        RejectionCode.unavailable,
      );
      expect(t.rng.drawCount, 0);
    });

    test('unknown entity', () {
      final t = Table(faces: [1]);
      expect(
        rejection(
          t.decide(
            const RollTable(table: 'test-table', entity: EntityId('ghost')),
          ),
        ),
        RejectionCode.unknownEntity,
      );
      expect(t.rng.drawCount, 0);
    });

    test('an RNG behind the episode', () {
      final t = Table(faces: [1, 2]);
      t.run(const RollTable(table: 'test-table'));
      final behind = ScriptedRng([3]);
      expect(
        rejection(
          t.engine.decide(
            t.state,
            const RollTable(table: 'test-table'),
            behind,
            t.ids,
          ),
        ),
        RejectionCode.rngOutOfSync,
      );
      expect(behind.drawCount, 0);
    });
  });

  test('narration names the table, the faces and the row', () {
    final t = Table(faces: [2]);
    final narrator = Narrator(t.engine.pack);
    final rolled = t.run(
      const RollTable(table: 'test-table', entity: Table.vale),
    );
    final line = narrator.narrate(t.state, rolled.single);
    expect(line.player, 'Vale rolled on Test Table: 1d6 2 = 2. Low.');
  });

  test(
    'a secret or redacted roll tells players only that something rolled',
    () {
      final t = Table(faces: [2]);
      final narrator = Narrator(t.engine.pack);
      final rolled = t.run(
        const RollTable(table: 'test-table', visibility: Redacted()),
      );
      final line = narrator.narrate(t.state, rolled.single);
      expect(line.redacted, 'The Handler rolled something.');
      expect(line.gm, 'The Handler rolled on Test Table: 1d6 2 = 2. Low.');
    },
  );
}
