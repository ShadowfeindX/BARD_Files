import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('evaluate', () {
    test('constants, attributes and vars report their values', () {
      final term = evaluate(
        Sum([Const(3), Attr('DEX'), Var('helperSkillBonus')]),
        attributes: {'DEX': 2},
        vars: {'helperSkillBonus': 4},
      );
      expect(term.value, 9);
      expect((term as SumTerm).terms, [
        const ConstTerm(3),
        const AttrTerm('DEX', 2),
        const VarTerm('helperSkillBonus', 4),
      ]);
    });

    test('dice sum their faces and record each die', () {
      final term = evaluate(
        Dice(count: 2, sides: 6, explode: false),
        rng: ScriptedRng([6, 3]),
      );
      expect(term.value, 9);
      expect((term as DiceTerm).rolls, [
        DieRoll([6]),
        DieRoll([3]),
      ]);
    });

    test('an exploding die chains on its maximum face', () {
      final rng = ScriptedRng([6, 6, 2]);
      final term = evaluate(
        Dice(count: 1, sides: 6, explode: true),
        rng: rng,
      ) as DiceTerm;
      expect(term.value, 14);
      expect(term.rolls.single.faces, [6, 6, 2]);
      expect(term.rolls.single.exploded, isTrue);
      expect(rng.drawCount, 3);
    });

    test('explode null (not ruled) rolls like false', () {
      final rng = ScriptedRng([4, 1]);
      final term = evaluate(Dice(count: 1, sides: 4), rng: rng) as DiceTerm;
      expect(term.value, 4);
      expect(term.explode, isNull);
      expect(term.rolls.single.exploded, isFalse);
      expect(rng.remaining, 1);
    });

    test('nodes draw depth first, left to right', () {
      final term = evaluate(
        Sum([
          Dice(count: 1, sides: 6, explode: true),
          Dice(count: 1, sides: 4),
        ]),
        rng: ScriptedRng([6, 1, 3]),
      ) as SumTerm;
      expect((term.terms[0] as DiceTerm).rolls.single.faces, [6, 1]);
      expect((term.terms[1] as DiceTerm).rolls.single.faces, [3]);
      expect(term.value, 10);
    });

    test('keepHighest keeps the best options and the earliest on a tie', () {
      final term = evaluate(
        KeepHighest([
          Dice(count: 1, sides: 6),
          Dice(count: 1, sides: 6),
          Dice(count: 1, sides: 6),
        ], 1),
        rng: ScriptedRng([4, 5, 5]),
      ) as KeepHighestTerm;
      expect(term.value, 5);
      expect(term.kept, [1]);
      expect(term.options.map((o) => o.value), [4, 5, 5]);
    });

    test('keepHighest can keep several, listed in pool order', () {
      final term = evaluate(
        KeepHighest([Const(1), Const(7), Const(3)], 2),
      ) as KeepHighestTerm;
      expect(term.value, 10);
      expect(term.kept, [1, 2]);
    });

    test('operators', () {
      num calc(OpKind op, List<num> args) =>
          evaluate(Op(op, [for (final a in args) Const(a)])).value;
      expect(calc(OpKind.add, [1, 2, 3]), 6);
      expect(calc(OpKind.sub, [5, 7]), -2);
      expect(calc(OpKind.mul, [2, 3, 4]), 24);
      expect(calc(OpKind.div, [7, 2]), 3.5);
      expect(calc(OpKind.min, [4, 2, 9]), 2);
      expect(calc(OpKind.max, [4, 2, 9]), 9);
      expect(calc(OpKind.floor, [3.5]), 3);
      expect(calc(OpKind.floor, [-3.5]), -4);
    });

    test('whole results are ints on every platform', () {
      final value = evaluate(Op(OpKind.div, [Const(10), Const(2)])).value;
      expect(value, isA<int>());
      expect(value.toString(), '5');
      expect(normalizeNumber(2.5), 2.5);
    });

    test('results beyond 2^53 fail instead of differing on the web', () {
      expect(
        () => evaluate(Op(OpKind.mul, [Const(maxSafeInteger), Const(2)])),
        throwsA(isA<EvaluationException>()),
      );
      expect(
        () => evaluate(Sum([Const(maxSafeInteger), Const(1)])),
        throwsA(isA<EvaluationException>()),
      );
      expect(
        () => evaluate(Attr('STR'), attributes: {'STR': maxSafeInteger + 1}),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('division by zero fails', () {
      expect(
        () => evaluate(Op(OpKind.div, [Const(1), Const(0)])),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('missing values and a missing RNG fail', () {
      expect(() => evaluate(Attr('STR')), throwsA(isA<EvaluationException>()));
      expect(
        () => evaluate(Var('newScore')),
        throwsA(isA<EvaluationException>()),
      );
      expect(
        () => evaluate(Dice(count: 1, sides: 6)),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('evaluateFormula refuses dice', () {
      expect(
        () => evaluateFormula(Sum([Dice(count: 1, sides: 6)])),
        throwsA(isA<EvaluationException>()),
      );
      expect(
        evaluateFormula(
          Op(OpKind.mul, [Attr('END'), Attr('LCK')]),
          attributes: {'END': 3, 'LCK': 2},
        ),
        6,
      );
    });
  });

  group('approved var placements', () {
    test('attribute purchase XP: 10 × var(newScore)', () {
      final xp = Op(OpKind.mul, [Const(10), Var(VarKeys.newScore)]);
      expect(evaluateFormula(xp, vars: {VarKeys.newScore: 4}), 40);
    });

    test('assistance bonus: 1d6 + var(helperSkillBonus)', () {
      final bonus = Sum([
        Dice(count: 1, sides: 6),
        Var(VarKeys.helperSkillBonus),
      ]);
      final term = evaluate(
        bonus,
        vars: {VarKeys.helperSkillBonus: 3},
        rng: ScriptedRng([5]),
      );
      expect(term.value, 8);
    });
  });

  group('node invariants', () {
    test('dice need a count and sides, and exploding dice 2+ sides', () {
      expect(() => Dice(count: 0, sides: 6), throwsArgumentError);
      expect(() => Dice(count: 1, sides: 0), throwsArgumentError);
      expect(
        () => Dice(count: 1, sides: 1, explode: true),
        throwsArgumentError,
      );
      expect(Dice(count: 1, sides: 1).sides, 1);
    });

    test('constants must be finite and web-safe; keys must be non-empty', () {
      expect(() => Const(double.nan), throwsArgumentError);
      expect(() => Const(double.infinity), throwsArgumentError);
      expect(() => Const(maxSafeInteger + 1), throwsArgumentError);
      expect(Const(maxSafeInteger).value, maxSafeInteger);
      expect(() => Attr(''), throwsArgumentError);
    });

    test('only approved var keys exist', () {
      expect(() => Var('playerLevel'), throwsArgumentError);
      expect(() => Var(''), throwsArgumentError);
      for (final key in VarKeys.all) {
        expect(Var(key).key, key);
      }
    });

    test('operator arity', () {
      expect(() => Op(OpKind.sub, [Const(1)]), throwsArgumentError);
      expect(() => Op(OpKind.floor, [Const(1), Const(2)]), throwsArgumentError);
      expect(() => Op(OpKind.add, const []), throwsArgumentError);
    });

    test('sum and keepHighest need options', () {
      expect(() => Sum(const []), throwsArgumentError);
      expect(() => KeepHighest([Const(1)], 2), throwsArgumentError);
      expect(() => KeepHighest([Const(1)], 0), throwsArgumentError);
    });

    test('trees report dice, vars and attributes they read', () {
      final expr = Sum([
        Dice(count: 1, sides: 6),
        Op(OpKind.add, [Attr('DEX'), Var('helperSkillBonus')]),
      ]);
      expect(expr.rollsDice, isTrue);
      expect(expr.varKeys, {'helperSkillBonus'});
      expect(expr.attributeKeys, {'DEX'});
      expect(Op(OpKind.add, [Attr('DEX')]).rollsDice, isFalse);
    });

    test('value equality', () {
      expect(
        Sum([Dice(count: 1, sides: 6, explode: true), Const(2)]),
        Sum([Dice(count: 1, sides: 6, explode: true), Const(2)]),
      );
      expect(
        Dice(count: 1, sides: 6),
        isNot(Dice(count: 1, sides: 6, explode: false)),
      );
    });
  });
}
