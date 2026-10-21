import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('decodeExpr reads the provisional pack forms', () {
    test('derived.json Health: END × LCK', () {
      final expr = decodeExpr(
        jsonDecode(
          '{"type":"op","op":"mul","args":'
          '[{"type":"attr","key":"END"},{"type":"attr","key":"LCK"}]}',
        ),
      );
      expect(expr, Op(OpKind.mul, [Attr('END'), Attr('LCK')]));
    });

    test('difficulty.json primary die: exploding d6', () {
      final expr = decodeExpr(
        jsonDecode('{"type":"dice","count":1,"sides":6,"explode":true}'),
      );
      expect(expr, Dice(count: 1, sides: 6, explode: true));
    });

    test('difficulty.json assistance bonus with its var', () {
      final expr = decodeExpr(
        jsonDecode(
          '{"type":"sum","terms":[{"type":"dice","count":1,"sides":6,'
          '"explode":null},{"type":"var","key":"helperSkillBonus"}]}',
        ),
        allowedVars: {VarKeys.helperSkillBonus},
      );
      expect(
        expr,
        Sum([Dice(count: 1, sides: 6), Var(VarKeys.helperSkillBonus)]),
      );
    });

    test('advancement.json attribute XP with its var', () {
      final expr = decodeExpr(
        jsonDecode(
          '{"type":"op","op":"mul","args":[{"type":"const","value":10},'
          '{"type":"var","key":"newScore"}]}',
        ),
        allowedVars: {VarKeys.newScore},
      );
      expect(expr, Op(OpKind.mul, [Const(10), Var(VarKeys.newScore)]));
    });
  });

  test('every node type round-trips', () {
    final expr = Op(OpKind.max, [
      Sum([Dice(count: 2, sides: 4, explode: false), Var(VarKeys.newScore)]),
      KeepHighest([Dice(count: 1, sides: 6, explode: true), Attr('LCK')], 1),
      Op(OpKind.floor, [
        Op(OpKind.div, [Const(7), Const(2)]),
      ]),
      Op(OpKind.sub, [Const(1.5), Const(1)]),
    ]);
    final json = jsonDecode(jsonEncode(encodeExpr(expr)));
    expect(decodeExpr(json, allowedVars: {VarKeys.newScore}), expr);
  });

  test('a missing explode key means not ruled', () {
    final expr = decodeExpr({'type': 'dice', 'count': 1, 'sides': 4}) as Dice;
    expect(expr.explode, isNull);
  });

  test('whole doubles are accepted where an int is expected', () {
    final expr = decodeExpr({'type': 'dice', 'count': 1.0, 'sides': 6.0});
    expect(expr, Dice(count: 1, sides: 6));
  });

  test('whole-number constants decode and encode as ints', () {
    final expr = decodeExpr({'type': 'const', 'value': 10.0}) as Const;
    expect(expr.value, isA<int>());
    expect(jsonEncode(encodeExpr(Const(10.0))), '{"type":"const","value":10}');
  });

  test('allowedVars may only name approved keys', () {
    expect(
      () => decodeExpr({'type': 'const', 'value': 1}, allowedVars: {'x'}),
      throwsArgumentError,
    );
  });

  group('decodeExpr errors', () {
    void expectError(Object? json, String fragment, {Set<String>? vars}) {
      expect(
        () => decodeExpr(json, allowedVars: vars ?? const {}, path: 'f'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(fragment),
          ),
        ),
      );
    }

    test('not an object', () => expectError(3, 'expected an expression'));
    test(
      'unknown type',
      () => expectError({'type': 'roll'}, 'unknown expression type "roll"'),
    );
    test('unknown key, so annotations must be stripped first', () {
      expectError({
        'type': 'attr',
        'key': 'STR',
        'note': 'x',
      }, 'unknown key "note"');
    });
    test('var not allowed in this placement', () {
      expectError({
        'type': 'var',
        'key': 'newScore',
      }, 'no var keys are allowed');
      expectError(
        {'type': 'var', 'key': 'newScore'},
        'allowed here: helperSkillBonus',
        vars: {VarKeys.helperSkillBonus},
      );
    });
    test('unknown operator', () {
      expectError({
        'type': 'op',
        'op': 'pow',
        'args': <Object?>[],
      }, 'unknown operator "pow"');
    });
    test('wrong arity becomes a format error with the path', () {
      expectError({
        'type': 'op',
        'op': 'sub',
        'args': [
          {'type': 'const', 'value': 1},
        ],
      }, 'f: sub takes exactly 2');
    });
    test('nested paths', () {
      expectError({
        'type': 'sum',
        'terms': [
          {'type': 'const', 'value': 1},
          {'type': 'const', 'value': 'two'},
        ],
      }, 'f.terms[1].value: expected a number');
    });
    test('numbers outside the web-safe range', () {
      expectError({'type': 'const', 'value': 9007199254740992}, 'f: ');
      expectError({
        'type': 'dice',
        'count': 9007199254740992,
        'sides': 6,
      }, 'f.count');
    });
    test('empty attribute key', () {
      expectError({'type': 'attr', 'key': ''}, 'f.key');
    });
    test('empty sum becomes a format error with the path', () {
      expect(
        () => decodeExpr({'type': 'sum', 'terms': <Object?>[]}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith(r'$:'),
          ),
        ),
      );
    });

    test('bad dice fields', () {
      expectError({'type': 'dice', 'count': 1, 'sides': 2.5}, 'f.sides');
      expectError({
        'type': 'dice',
        'count': 1,
        'sides': 6,
        'explode': 'yes',
      }, 'f.explode');
      expectError({
        'type': 'dice',
        'count': 1,
        'sides': 1,
        'explode': true,
      }, 'at least 2 sides');
    });
  });
}
