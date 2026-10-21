import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  test('ScriptedRng returns its faces in order and counts draws', () {
    final rng = ScriptedRng([3, 1, 6]);
    expect([rng.rollDie(6), rng.rollDie(4), rng.rollDie(6)], [3, 1, 6]);
    expect(rng.drawCount, 3);
    expect(rng.remaining, 0);
  });

  test('ScriptedRng fails loudly when exhausted or mis-scripted', () {
    expect(() => ScriptedRng([]).rollDie(6), throwsStateError);
    expect(() => ScriptedRng([5]).rollDie(4), throwsArgumentError);
    expect(() => ScriptedRng([0]).rollDie(4), throwsArgumentError);
    expect(() => ScriptedRng([1]).rollDie(0), throwsArgumentError);
  });

  test('SequentialIdSource is deterministic', () {
    final ids = SequentialIdSource(prefix: 'a', start: 7);
    expect(
      [ids.next(), ids.next()],
      [const EntityId('a7'), const EntityId('a8')],
    );
  });
}
