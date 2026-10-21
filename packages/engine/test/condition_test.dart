import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  Compare wilBelow(num value) =>
      Compare(CompareOp.lt, Attr('WIL'), Const(value));

  test('every comparison', () {
    bool check(CompareOp op, int wil) => evaluateCondition(
      Compare(op, Attr('WIL'), Const(3)),
      attributes: {'WIL': wil},
    ).passed;
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.lt, w),
      ],
      [true, false, false],
    );
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.le, w),
      ],
      [true, true, false],
    );
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.eq, w),
      ],
      [false, true, false],
    );
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.ne, w),
      ],
      [true, false, true],
    );
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.ge, w),
      ],
      [false, true, true],
    );
    expect(
      [
        for (final w in [2, 3, 4]) check(CompareOp.gt, w),
      ],
      [false, false, true],
    );
  });

  test('the result records both values', () {
    expect(
      evaluateCondition(wilBelow(3), attributes: {'WIL': 2}),
      const ConditionResult(passed: true, left: 2, right: 3),
    );
  });

  test('a missing score is an evaluation error', () {
    expect(
      () => evaluateCondition(wilBelow(3)),
      throwsA(isA<EvaluationException>()),
    );
  });

  test('sides must be formulas: no dice, no var', () {
    expect(
      () => Compare(CompareOp.lt, Dice(count: 1, sides: 6), Const(3)),
      throwsArgumentError,
    );
    expect(
      () => Compare(CompareOp.lt, Attr('WIL'), Var(VarKeys.newScore)),
      throwsArgumentError,
    );
  });

  test('JSON round trip', () {
    final condition = Compare(
      CompareOp.ge,
      Op(OpKind.add, [Attr('WIL'), Attr('LCK')]),
      Const(5),
    );
    final json = encodeCondition(condition);
    expect(json, {
      'type': 'compare',
      'op': 'ge',
      'left': {
        'type': 'op',
        'op': 'add',
        'args': [
          {'type': 'attr', 'key': 'WIL'},
          {'type': 'attr', 'key': 'LCK'},
        ],
      },
      'right': {'type': 'const', 'value': 5},
    });
    expect(decodeCondition(json), condition);
  });

  group('decode errors', () {
    void expectError(Object? json, String fragment) => expect(
      () => decodeCondition(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(fragment),
        ),
      ),
    );
    final wil = {'type': 'attr', 'key': 'WIL'};
    final three = {'type': 'const', 'value': 3};

    test('shape', () {
      expectError(7, 'expected a condition object');
      expectError({'type': 'and'}, 'unknown condition type');
      expectError({
        'type': 'compare',
        'op': 'lt',
        'left': wil,
        'right': three,
        'x': 1,
      }, 'unknown key "x"');
      expectError({
        'type': 'compare',
        'op': 'below',
        'left': wil,
        'right': three,
      }, r'$.op: unknown comparison');
    });

    test('sides', () {
      expectError({'type': 'compare', 'op': 'lt', 'right': three}, r'$.left');
      expectError({
        'type': 'compare',
        'op': 'lt',
        'left': {'type': 'dice', 'count': 1, 'sides': 6, 'explode': false},
        'right': three,
      }, r'$.left: must be a formula');
    });
  });
}
