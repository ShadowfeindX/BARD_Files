import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/table.dart';

void main() {
  const vale = Table.vale;

  test('every event kind in a short session narrates', () {
    final table = Table(faces: [6, 2, 3]);
    final narrator = Narrator(table.engine.pack);
    final request =
        (table
                    .run(
                      const RequestAction(
                        entity: vale,
                        description: 'Shoot the lock',
                        suggestedSkill: 'firearms',
                        actor: AliasActor(Table.valeAlias),
                      ),
                    )
                    .single
                as ActionRequested)
            .request;
    final check =
        (table
                    .run(
                      RequireCheck(
                        entity: vale,
                        skill: 'firearms',
                        difficulty: const CategoryDifficulty('C'),
                        modifiers: [const CheckModifier('Cover', -1)],
                        request: request,
                      ),
                    )
                    .single
                as CheckRequired)
            .check;
    table.run(ResolveCheck(check: check));
    table.run(const ApplyDamage(entity: vale, amount: 2));
    table.run(const ApplySanityLoss(entity: vale, amount: 1));
    table.run(const ApplyCondition(entity: vale, condition: 'bleeding'));
    table.run(const ClearCondition(entity: vale, condition: 'bleeding'));
    final other =
        (table
                    .run(
                      const RequestAction(
                        entity: vale,
                        description: 'Run',
                        actor: AliasActor(Table.valeAlias),
                      ),
                    )
                    .single
                as ActionRequested)
            .request;
    table.run(DeclineRequest(request: other, reason: 'No time'));

    expect(
      [for (final e in table.log) narrator.narrate(table.state, e).gm],
      [
        'The operation began (pack test-core 0.0.1).',
        'Agent Vale joined the operation.',
        'Vale asks to act: "Shoot the lock" (suggests Firearms).',
        'Vale must make a Firearms (DEX) check against DC 10 (Cat-C).',
        'Vale rolled Firearms (DEX): die 6+2, DEX 2, Proficient 3, Cover -1 '
            '= 12 against DC 10 (Cat-C), success.',
        'Vale takes 2 damage.',
        'Vale loses 1 Sanity.',
        'Vale is now Bleeding.',
        'Vale is no longer Bleeding.',
        'Vale asks to act: "Run".',
        'The Handler declined the request: No time.',
      ],
    );
  });

  test('a GM edit is narrated with the original amount', () {
    final table = Table();
    final narrator = Narrator(table.engine.pack);
    final edited = const DamageApplied(
      entity: vale,
      amount: 4,
      actor: GmActor(),
      visibility: Public(),
    ).withAmount(1);
    final narration = narrator.narrate(table.state, edited);
    expect(
      narration.gm,
      'Vale takes 1 damage (changed by the Handler from 4).',
    );
    expect(narration.player, 'Vale takes 1 damage.');
  });

  group('perspectives follow visibility', () {
    final table = Table();
    final narrator = Narrator(table.engine.pack);
    Narration lines(Visibility visibility) => narrator.narrate(
      table.state,
      DamageApplied(
        entity: vale,
        amount: 1,
        actor: const GmActor(),
        visibility: visibility,
      ),
    );

    test('public and alias-only events give players the full line', () {
      expect(lines(const Public()).player, 'Vale takes 1 damage.');
      expect(lines(AliasesOnly({Table.valeAlias})).player, isNotNull);
    });

    test('GM-only events have no player line', () {
      final narration = lines(const GmOnly());
      expect(narration.player, isNull);
      expect(narration.redacted, isNull);
    });

    test('redacted events give players only the redacted line', () {
      final narration = lines(const Redacted());
      expect(narration.player, isNull);
      expect(narration.redacted, 'Something happened out of sight.');
      expect(narration.gm, 'Vale takes 1 damage.');
    });
  });
}
