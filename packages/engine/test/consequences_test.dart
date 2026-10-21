import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/table.dart';

void main() {
  const vale = Table.vale;

  group('vitals', () {
    test('GM-entered damage and sanity loss accumulate', () {
      final table = Table();
      table.run(const ApplyDamage(entity: vale, amount: 2));
      table.run(const ApplyDamage(entity: vale, amount: 1));
      table.run(const ApplySanityLoss(entity: vale, amount: 3));
      expect(
        table.state.stores.get(Vitals.componentType, vale),
        const Vitals(damageTaken: 3, sanityLost: 3),
      );
    });

    test('the events are consequences, held for GM review', () {
      final table = Table();
      final events = [
        ...table.run(const ApplyDamage(entity: vale, amount: 2)),
        ...table.run(const ApplySanityLoss(entity: vale, amount: 1)),
      ];
      expect(events, everyElement(isA<Consequence>()));
    });

    test('a review edit keeps the original amount beside the new one', () {
      const original = DamageApplied(
        entity: vale,
        amount: 4,
        actor: GmActor(),
        visibility: Public(),
      );
      final edited = original.withAmount(2).withAmount(1);
      expect(edited.amount, 1);
      expect(edited.overriddenFrom, 4);
      final sanity = const SanityLost(
        entity: vale,
        amount: 3,
        actor: GmActor(),
        visibility: Public(),
      ).withAmount(5);
      expect((sanity.amount, sanity.overriddenFrom), (5, 3));
    });

    test('rejections', () {
      final table = Table();
      expect(
        rejection(
          table.decide(const ApplyDamage(entity: EntityId('x'), amount: 1)),
        ),
        RejectionCode.unknownEntity,
      );
      expect(
        rejection(
          table.decide(const ApplySanityLoss(entity: vale, amount: -1)),
        ),
        RejectionCode.invalidValue,
      );
    });
  });

  group('conditions', () {
    test('apply and clear', () {
      final table = Table();
      final applied = table.run(
        const ApplyCondition(entity: vale, condition: 'bleeding'),
      );
      expect(applied.single, isA<Consequence>());
      expect(
        table.state.stores.get(Conditions.componentType, vale),
        Conditions({'bleeding'}),
      );
      final cleared = table.run(
        const ClearCondition(entity: vale, condition: 'bleeding'),
      );
      expect(cleared.single, isNot(isA<Consequence>()));
      expect(table.state.stores.has(Conditions.componentType, vale), isFalse);
    });

    test('rejections', () {
      final table = Table();
      RejectionCode code(Command c) => rejection(table.decide(c));
      expect(
        code(const ApplyCondition(entity: vale, condition: 'cursed')),
        RejectionCode.unknownPackKey,
      );
      expect(
        code(const ClearCondition(entity: vale, condition: 'bleeding')),
        RejectionCode.invalidValue,
      );
      table.run(const ApplyCondition(entity: vale, condition: 'stunned'));
      expect(
        code(const ApplyCondition(entity: vale, condition: 'stunned')),
        RejectionCode.invalidValue,
      );
      expect(
        code(const ApplyCondition(entity: EntityId('x'), condition: 'stunned')),
        RejectionCode.unknownEntity,
      );
    });
  });

  group('derived stats', () {
    test('Health = END x LCK and Sanity = WIS x LCK, minus losses', () {
      final table = Table();
      final derived = DerivedStats(table.engine.pack);
      // Vale: END 2, WIS 2, LCK 3.
      expect(derived.of(table.state, vale), {'health': 6, 'sanity': 6});
      table.run(const ApplyDamage(entity: vale, amount: 2));
      table.run(const ApplySanityLoss(entity: vale, amount: 7));
      expect(
        derived.vitals(table.state, vale),
        const VitalsView(maxHealth: 6, health: 4, maxSanity: 6, sanity: -1),
      );
    });

    test('an entity without attributes has none', () {
      final table = Table();
      final derived = DerivedStats(table.engine.pack);
      expect(derived.of(table.state, const EntityId('x')), isEmpty);
      expect(derived.vitals(table.state, const EntityId('x')), isNull);
    });
  });
}
