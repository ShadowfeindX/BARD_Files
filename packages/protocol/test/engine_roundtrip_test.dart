import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'support/engine_pack.dart';

/// Runs a short operation through the real engine and checks that every
/// command and every event it produced survives the codecs unchanged, and
/// that the decoded log replays to the same state (gate review, row 6).
void main() {
  const valeAlias = AliasId('al_vale');
  const quinnAlias = AliasId('al_quinn');

  final engine = Engine(testPack());
  // Exploding d6 (6 then 3), proficiency d4, then more faces for later rolls.
  final rng = ScriptedRng([6, 3, 4, 2, 1, 5, 6, 6, 1, 3]);
  final ids = SequentialIdSource();
  var state = const OperationState.initial();
  final commands = <Command>[];
  final log = <Event>[];

  List<Event> run(Command command) {
    commands.add(command);
    final decision = engine.decide(state, command, rng, ids);
    if (decision is! Accepted) fail('$command was rejected: $decision');
    for (final event in decision.events) {
      state = engine.evolve(state, event);
    }
    log.addAll(decision.events);
    return decision.events;
  }

  setUpAll(() {
    run(const StartOperation(operationId: 'op_rt'));
    final vale = run(
      CreateAgent(
        name: 'Vale',
        attributes: validScores(),
        skills: {'firearms': 'proficient'},
        ownerAlias: valeAlias,
      ),
    ).whereType<AgentCreated>().single.entity;
    run(
      CreateAgent(
        name: 'Quinn',
        attributes: {...validScores(), 'WIL': 1, 'STR': 2},
        ownerAlias: quinnAlias,
      ),
    );
    final request = run(
      RequestAction(
        entity: vale,
        description: 'Shoot the lock',
        suggestedSkill: 'firearms',
        actor: const AliasActor(valeAlias),
      ),
    ).whereType<ActionRequested>().single.request;
    final check = run(
      RequireCheck(
        entity: vale,
        skill: 'firearms',
        difficulty: const CategoryDifficulty('C'),
        modifiers: const [CheckModifier('Cover', -2)],
        request: request,
        visibility: AliasesOnly({valeAlias}),
      ),
    ).whereType<CheckRequired>().single.check;
    run(ResolveCheck(check: check));
    final second = run(
      RequestAction(
        entity: vale,
        description: 'Pick the lock instead',
        actor: const AliasActor(valeAlias),
      ),
    ).whereType<ActionRequested>().single.request;
    run(DeclineRequest(request: second, reason: 'Already open'));
    // A consequence as the GM edited it in review (overriddenFrom set).
    final damage = run(ApplyDamage(entity: vale, amount: 4, check: check))
        .whereType<DamageApplied>()
        .single;
    log.add(damage.withAmount(2));
    state = engine.evolve(state, log.last);
    run(ApplySanityLoss(entity: vale, amount: 3));
    run(ApplyCondition(entity: vale, condition: 'bleeding', check: check));
    run(const ClearCondition(entity: EntityId('e1'), condition: 'bleeding'));
    run(
      BroadcastToQualifying(
        text: 'A low groaning voice.',
        condition: Compare(CompareOp.lt, Attr('WIL'), Const(2)),
      ),
    );
    run(
      const SendPhoneMessage(
        from: PhoneAlias(valeAlias),
        to: PhoneGm(),
        text: 'Need backup',
        actor: AliasActor(valeAlias),
      ),
    );
    run(
      const SendPhoneMessage(
        from: PhoneGm(),
        to: PhoneAlias(valeAlias),
        text: 'Hold on',
        actor: GmActor(),
      ),
    );
    run(
      RequireCheck(
        entity: vale,
        attribute: 'WIL',
        difficulty: const FixedDifficulty(25),
        visibility: const Redacted(),
      ),
    );
  });

  Object? wire(Object? json) => jsonDecode(jsonEncode(json));

  test('the run covers every event type the codec knows', () {
    final kinds = {for (final e in log) encodeEvent(e)['type']};
    expect(kinds, {
      'operationStarted',
      'agentCreated',
      'actionRequested',
      'requestDeclined',
      'checkRequired',
      'checkResolved',
      'conditionApplied',
      'conditionCleared',
      'damageApplied',
      'sanityLost',
      'broadcastEvaluated',
      'broadcastDelivered',
      'phoneMessageSent',
    });
    expect(
      log.whereType<CheckResolved>().single.breakdown.primary,
      isA<DiceTerm>().having((d) => d.rolls.single.exploded, 'exploded', true),
    );
  });

  test('every engine event round-trips through JSON text', () {
    for (final event in log) {
      final encoded = encodeEvent(event);
      final decoded = decodeEvent(wire(encoded));
      expect(decoded, event, reason: '${encoded['type']}');
      expect(encodeEvent(decoded), encoded, reason: '${encoded['type']}');
    }
  });

  test('every command round-trips through JSON text', () {
    for (final command in commands) {
      final encoded = encodeCommand(command);
      expect(decodeCommand(wire(encoded)), command, reason: '$encoded');
    }
  });

  test('the decoded log replays to the same state', () {
    final decoded = [for (final e in log) decodeEvent(wire(encodeEvent(e)))];
    expect(
      engine.replay(const OperationState.initial(), decoded),
      engine.replay(const OperationState.initial(), log),
    );
    expect(engine.replay(const OperationState.initial(), log), state);
  });
}
