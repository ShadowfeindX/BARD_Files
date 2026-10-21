import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/table.dart';
import 'support/test_pack.dart';

void main() {
  const vale = Table.vale;

  RequireCheck firearms({
    Difficulty difficulty = const CategoryDifficulty('C'),
    List<CheckModifier> modifiers = const [],
    RequestId? request,
    Visibility visibility = const Public(),
  }) => RequireCheck(
    entity: vale,
    skill: 'firearms',
    difficulty: difficulty,
    modifiers: modifiers,
    request: request,
    visibility: visibility,
  );

  CheckResolved resolveOnly(Table table, CheckId check) =>
      table.run(ResolveCheck(check: check)).single as CheckResolved;

  CheckId requireOnly(Table table, RequireCheck command) =>
      (table.run(command).single as CheckRequired).check;

  group('action requests', () {
    test('a player request is seen by the GM and that player', () {
      final table = Table();
      final event =
          table
                  .run(
                    const RequestAction(
                      entity: vale,
                      description: 'Shoot the lock',
                      suggestedSkill: 'firearms',
                      actor: AliasActor(Table.valeAlias),
                    ),
                  )
                  .single
              as ActionRequested;
      expect(event.visibility, AliasesOnly({Table.valeAlias}));
      expect(
        table.state.pending.requests[event.request]!.description,
        'Shoot the lock',
      );
    });

    test('a check that answers a request closes it', () {
      final table = Table();
      final request =
          (table
                      .run(
                        const RequestAction(
                          entity: vale,
                          description: 'Shoot the lock',
                          actor: AliasActor(Table.valeAlias),
                        ),
                      )
                      .single
                  as ActionRequested)
              .request;
      final check = requireOnly(table, firearms(request: request));
      expect(table.state.pending.requests.isEmpty, isTrue);
      expect(table.state.pending.checks[check]!.spec.request, request);
    });

    test('declining closes the request with its visibility', () {
      final table = Table();
      final request =
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
      final declined =
          table.run(DeclineRequest(request: request, reason: 'No time')).single
              as RequestDeclined;
      expect(declined.visibility, AliasesOnly({Table.valeAlias}));
      expect(table.state.pending.requests.isEmpty, isTrue);
    });

    test('rejections', () {
      final table = Table();
      expect(
        rejection(
          table.decide(
            const RequestAction(
              entity: EntityId('nobody'),
              description: 'x',
              actor: GmActor(),
            ),
          ),
        ),
        RejectionCode.unknownEntity,
      );
      expect(
        rejection(
          table.decide(
            const RequestAction(
              entity: vale,
              description: ' ',
              actor: GmActor(),
            ),
          ),
        ),
        RejectionCode.invalidValue,
      );
      expect(
        rejection(
          table.decide(
            const RequestAction(
              entity: vale,
              description: 'x',
              suggestedSkill: 'juggling',
              actor: GmActor(),
            ),
          ),
        ),
        RejectionCode.unknownPackKey,
      );
      expect(
        rejection(table.decide(const DeclineRequest(request: RequestId('r')))),
        RejectionCode.unknownRequest,
      );
    });
  });

  group('requiring a check', () {
    test('a skill check uses the skill attribute and the category DC', () {
      final table = Table();
      final event = table.run(firearms()).single as CheckRequired;
      expect(
        event.spec,
        CheckSpec(
          entity: vale,
          attribute: 'DEX',
          skill: 'firearms',
          category: 'C',
          dc: 10,
        ),
      );
      expect(
        table.state.pending.checks[event.check],
        PendingCheck(event.spec, const Public()),
      );
    });

    test('a fixed DC and an explicit attribute', () {
      final table = Table();
      final event =
          table
                  .run(
                    RequireCheck(
                      entity: vale,
                      attribute: 'INT',
                      difficulty: const FixedDifficulty(9),
                    ),
                  )
                  .single
              as CheckRequired;
      expect(event.spec.attribute, 'INT');
      expect(event.spec.category, isNull);
      expect(event.spec.dc, 9);
    });

    test('rejections', () {
      final table = Table();
      RejectionCode code(RequireCheck c) => rejection(table.decide(c));
      expect(
        code(
          RequireCheck(
            entity: const EntityId('x'),
            attribute: 'DEX',
            difficulty: const FixedDifficulty(5),
          ),
        ),
        RejectionCode.unknownEntity,
      );
      expect(
        code(RequireCheck(entity: vale, difficulty: const FixedDifficulty(5))),
        RejectionCode.invalidValue,
      );
      expect(
        code(
          RequireCheck(
            entity: vale,
            attribute: 'OCC',
            difficulty: const FixedDifficulty(5),
          ),
        ),
        RejectionCode.unknownPackKey,
      );
      expect(
        code(
          RequireCheck(
            entity: vale,
            skill: 'juggling',
            difficulty: const FixedDifficulty(5),
          ),
        ),
        RejectionCode.unknownPackKey,
      );
      expect(
        code(firearms(difficulty: const CategoryDifficulty('Z'))),
        RejectionCode.unknownPackKey,
      );
      expect(
        code(firearms(modifiers: [const CheckModifier(' ', 1)])),
        RejectionCode.invalidValue,
      );
      expect(
        code(firearms(request: const RequestId('r9'))),
        RejectionCode.unknownRequest,
      );
    });

    test('a pack without check rules cannot require checks', () {
      final base = testPack();
      final pack = RulesPack(
        ref: base.ref,
        attributes: base.attributes,
        attributeCreation: base.attributeCreation,
        proficiencyTiers: base.proficiencyTiers,
        skillCategories: base.skillCategories,
        skills: base.skills,
        derived: base.derived,
      );
      final table = Table(pack: pack);
      expect(rejection(table.decide(firearms())), RejectionCode.unavailable);
    });
  });

  group('resolving a check', () {
    test('primary die + attribute + proficiency dice + modifiers', () {
      // d6 4, DEX 2, Proficient d4 3, Cover +1 = 10 against DC 10.
      final table = Table(faces: [4, 3]);
      final check = requireOnly(
        table,
        firearms(modifiers: [const CheckModifier('Cover', 1)]),
      );
      final event = resolveOnly(table, check);
      expect(
        event.breakdown.primary,
        DiceTerm(
          sides: 6,
          explode: true,
          rolls: [
            DieRoll([4]),
          ],
        ),
      );
      expect(event.breakdown.attributeScore, 2);
      expect(event.breakdown.tier, 'proficient');
      expect(
        event.breakdown.proficiency,
        DiceTerm(
          sides: 4,
          explode: null,
          rolls: [
            DieRoll([3]),
          ],
        ),
      );
      expect(event.total, 10);
      expect(event.outcome, CheckOutcome.success);
      expect(event.source, RollSourceKind.rng);
      expect(event.enteredBy, isNull);
      expect(event.visibility, const Public());
      expect(table.state.pending.checks.isEmpty, isTrue);
    });

    test('the primary die explodes on its top face, chaining', () {
      final table = Table(faces: [6, 6, 1, 2]);
      final event = resolveOnly(table, requireOnly(table, firearms()));
      expect(event.breakdown.primary.value, 13);
      expect((event.breakdown.primary as DiceTerm).rolls.single.faces, [
        6,
        6,
        1,
      ]);
      expect(event.draws, DrawRange(0, 4));
    });

    test('outcome bands: success, partial success within 2, failure', () {
      CheckOutcome outcome(int primaryFace, int dc) {
        final table = Table(faces: [primaryFace, 1]);
        return resolveOnly(
          table,
          requireOnly(table, firearms(difficulty: FixedDifficulty(dc))),
        ).outcome;
      }

      // Total = face + DEX 2 + d4 1.
      expect(outcome(4, 7), CheckOutcome.success);
      expect(outcome(3, 7), CheckOutcome.partialSuccess);
      expect(outcome(2, 7), CheckOutcome.partialSuccess);
      expect(outcome(1, 7), CheckOutcome.failure);
    });

    test('a skill with no recorded tier adds no proficiency dice', () {
      final table = Table(faces: [5]);
      final event = resolveOnly(
        table,
        requireOnly(
          table,
          RequireCheck(
            entity: vale,
            skill: 'research',
            difficulty: const CategoryDifficulty('D'),
          ),
        ),
      );
      expect(event.breakdown.tier, isNull);
      expect(event.breakdown.proficiency, isNull);
      expect(event.total, 7);
    });

    test('auto-resolve rolls at once', () {
      final table = Table(
        faces: [2, 2],
        settings: const OperationSettings(autoResolveChecks: true),
      );
      final events = table.run(firearms());
      expect(events.map((e) => e.runtimeType), [CheckRequired, CheckResolved]);
      expect(
        (events.last as CheckResolved).check,
        (events.first as CheckRequired).check,
      );
      expect(table.state.pending.checks.isEmpty, isTrue);
    });

    test('a secret check stays secret when it resolves', () {
      final table = Table(faces: [2, 2]);
      final event = resolveOnly(
        table,
        requireOnly(table, firearms(visibility: const GmOnly())),
      );
      expect(event.visibility, const GmOnly());
    });

    test('an unknown check is rejected', () {
      final table = Table();
      expect(
        rejection(table.decide(const ResolveCheck(check: CheckId('c9')))),
        RejectionCode.unknownCheck,
      );
    });

    test('CheckResolved is not a consequence, so it is never held', () {
      final table = Table(faces: [2, 2]);
      final event = resolveOnly(table, requireOnly(table, firearms()));
      expect(event, isNot(isA<Consequence>()));
      expect(event, isA<RollingEvent>());
    });
  });

  group('draw-count invariant (Opus gate)', () {
    test('each roll records its draw range; folding sets the count to its '
        'end; ranges are contiguous', () {
      final table = Table(faces: [6, 1, 2, 3, 4, 6, 6, 2, 1]);
      final ranges = <DrawRange>[];
      for (var i = 0; i < 3; i++) {
        final event = resolveOnly(table, requireOnly(table, firearms()));
        ranges.add(event.draws);
        expect(table.state.rng.drawCount, event.draws.end);
        expect(table.rng.drawCount, event.draws.end);
      }
      expect(ranges, [DrawRange(0, 3), DrawRange(3, 5), DrawRange(5, 9)]);
      // Replaying the log reaches the same count without any RNG.
      final replayed = table.engine.replay(
        const OperationState.initial(),
        table.log,
      );
      expect(replayed.rng.drawCount, 9);
      expect(replayed, table.state);
    });

    test('rejections do not consume draws', () {
      final table = Table(faces: [3, 3]);
      final check = requireOnly(table, firearms());
      // Vale loses the DEX score the check needs (an edit outside the
      // engine, to reach the "missing score" path after the check exists).
      final scores = Map.of(validScores())..remove('DEX');
      table.state = table.state.copyWith(
        stores: table.state.stores.put(vale, Attributes(scores)),
      );
      expect(
        rejection(table.decide(ResolveCheck(check: check))),
        RejectionCode.invalidValue,
      );
      expect(
        rejection(table.decide(const ResolveCheck(check: CheckId('none')))),
        RejectionCode.unknownCheck,
      );
      expect(table.rng.drawCount, 0);
      expect(table.state.rng.drawCount, 0);
    });

    RulesPack packWithPrimary(Expr primary) {
      final base = testPack();
      final rules = base.checkRules!;
      return RulesPack(
        ref: base.ref,
        attributes: base.attributes,
        attributeCreation: base.attributeCreation,
        proficiencyTiers: base.proficiencyTiers,
        skillCategories: base.skillCategories,
        skills: base.skills,
        derived: base.derived,
        difficultyCategories: base.difficultyCategories,
        checkRules: CheckRules(
          primaryDie: primary,
          partialSuccessWithin: rules.partialSuccessWithin,
          fumbleFractionOfDc: rules.fumbleFractionOfDc,
          luckAdvantageAttribute: rules.luckAdvantageAttribute,
          luckAdvantageKeep: rules.luckAdvantageKeep,
          assistanceGateCategory: rules.assistanceGateCategory,
          assistanceBonus: rules.assistanceBonus,
        ),
      );
    }

    test('check dice that divide are refused before drawing', () {
      final table = Table(
        faces: [1],
        pack: packWithPrimary(
          Op(OpKind.div, [Const(6), Dice(count: 1, sides: 6)]),
        ),
      );
      final check = requireOnly(table, firearms());
      expect(
        rejection(table.decide(ResolveCheck(check: check))),
        RejectionCode.evaluationFailed,
      );
      expect(table.rng.drawCount, 0);
    });

    test('a rejection that drew anyway is a loud error, not a silent '
        'rejection', () {
      // A total past the web-safe range fails only after the die is rolled.
      final table = Table(
        faces: [1],
        pack: packWithPrimary(
          Sum([Dice(count: 1, sides: 6), Const(maxSafeInteger)]),
        ),
      );
      final check = requireOnly(table, firearms());
      expect(() => table.decide(ResolveCheck(check: check)), throwsStateError);
    });

    test('an RNG out of step with the state is refused before drawing', () {
      final table = Table(faces: [1, 1, 1]);
      final check = requireOnly(table, firearms());
      table.rng.rollDie(6); // Drawn outside the engine.
      expect(
        rejection(table.decide(ResolveCheck(check: check))),
        RejectionCode.rngOutOfSync,
      );
      expect(table.rng.drawCount, 1);
    });
  });
}
