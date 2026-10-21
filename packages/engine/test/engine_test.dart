import 'package:engine/engine.dart';
import 'package:test/test.dart';

import 'support/decisions.dart';
import 'support/test_pack.dart';

void main() {
  late Engine engine;
  late OperationState started;

  setUp(() {
    engine = Engine(testPack());
    started = engine.replay(const OperationState.initial(), [
      ...accepted(
        engine.decide(
          const OperationState.initial(),
          const StartOperation(operationId: 'op1'),
          ScriptedRng([]),
          SequentialIdSource(),
        ),
      ),
    ]);
  });

  Decision decide(OperationState state, Command command, {IdSource? ids}) =>
      engine.decide(
        state,
        command,
        ScriptedRng([]),
        ids ?? SequentialIdSource(),
      );

  group('StartOperation', () {
    test('records the engine version, pinned pack and settings', () {
      const settings = OperationSettings(autoConfirmConsequences: true);
      final decision = decide(
        const OperationState.initial(),
        const StartOperation(operationId: 'op1', settings: settings),
      );
      expect(
        decision,
        Accepted([
          OperationStarted(
            operationId: 'op1',
            engineVersion: engineVersion,
            packRef: engine.pack.ref,
            settings: settings,
            actor: const GmActor(),
          ),
        ]),
      );
    });

    test('evolve fills meta', () {
      expect(started.started, isTrue);
      expect(started.meta!.operationId, 'op1');
      expect(started.meta!.packRef, engine.pack.ref);
      expect(started.meta!.settings, const OperationSettings());
    });

    test('a second start is rejected', () {
      expect(
        rejection(decide(started, const StartOperation(operationId: 'op2'))),
        RejectionCode.alreadyStarted,
      );
    });

    test('an empty id is rejected', () {
      expect(
        rejection(
          decide(
            const OperationState.initial(),
            const StartOperation(operationId: ''),
          ),
        ),
        RejectionCode.invalidValue,
      );
    });
  });

  test('commands before the start are rejected', () {
    expect(
      rejection(
        decide(
          const OperationState.initial(),
          CreateAgent(name: 'Hall', attributes: validScores()),
        ),
      ),
      RejectionCode.notStarted,
    );
  });

  test('an engine bound to another pack refuses to decide', () {
    final other = Engine(
      testPack(
        ref: const PackRef(id: 'test-core', version: '0.0.2', contentHash: 'x'),
      ),
    );
    expect(
      rejection(
        other.decide(
          started,
          CreateAgent(name: 'Hall', attributes: validScores()),
          ScriptedRng([]),
          SequentialIdSource(),
        ),
      ),
      RejectionCode.packMismatch,
    );
  });

  group('CreateAgent', () {
    test('produces AgentCreated with a new id, visible to its owner', () {
      const owner = AliasId('alias-1');
      final decision = decide(
        started,
        CreateAgent(
          name: 'Hall',
          attributes: validScores(),
          skills: {'firearms': 'proficient'},
          ownerAlias: owner,
        ),
        ids: SequentialIdSource(prefix: 'agent-'),
      );
      expect(
        decision,
        Accepted([
          AgentCreated(
            entity: const EntityId('agent-1'),
            name: 'Hall',
            attributes: validScores(),
            skills: {'firearms': 'proficient'},
            ownerAlias: owner,
            actor: const GmActor(),
            visibility: AliasesOnly({owner}),
          ),
        ]),
      );
    });

    test('an agent with no owner is GM-only', () {
      final event =
          accepted(
                decide(
                  started,
                  CreateAgent(name: 'Vale', attributes: validScores()),
                ),
              ).single
              as AgentCreated;
      expect(event.visibility, const GmOnly());
    });

    test('evolve attaches identity, attributes and skills', () {
      final events = accepted(
        decide(
          started,
          CreateAgent(
            name: 'Hall',
            attributes: validScores(),
            skills: {'research': 'expert'},
            ownerAlias: const AliasId('a'),
          ),
        ),
      );
      final state = engine.replay(started, events);
      const id = EntityId('e1');
      expect(
        state.stores.get(Identity.componentType, id),
        const Identity(
          name: 'Hall',
          kind: EntityKind.agent,
          ownerAlias: AliasId('a'),
        ),
      );
      expect(state.stores.get(Attributes.componentType, id)!['LCK'], 3);
      expect(state.stores.get(Skills.componentType, id)!['research'], 'expert');
      expect(started.stores.entities, isEmpty, reason: 'old state unchanged');
    });

    Map<String, int> scores(Map<String, int> overrides) => {
      ...validScores(),
      ...overrides,
    };

    final invalid = <String, (CreateAgent, RejectionCode)>{
      'empty name': (
        CreateAgent(name: ' ', attributes: validScores()),
        RejectionCode.invalidValue,
      ),
      'unknown attribute': (
        CreateAgent(name: 'X', attributes: scores({'OCC': 2})),
        RejectionCode.unknownPackKey,
      ),
      'missing attribute': (
        CreateAgent(name: 'X', attributes: validScores()..remove('WIL')),
        RejectionCode.invalidValue,
      ),
      'score below the creation minimum': (
        CreateAgent(name: 'X', attributes: scores({'STR': 0})),
        RejectionCode.invalidValue,
      ),
      'score above the creation maximum': (
        CreateAgent(name: 'X', attributes: scores({'STR': 4})),
        RejectionCode.invalidValue,
      ),
      'unknown skill': (
        CreateAgent(
          name: 'X',
          attributes: validScores(),
          skills: {'lockpicking': 'proficient'},
        ),
        RejectionCode.unknownPackKey,
      ),
      'unknown tier': (
        CreateAgent(
          name: 'X',
          attributes: validScores(),
          skills: {'firearms': 'master'},
        ),
        RejectionCode.unknownPackKey,
      ),
    };
    for (final MapEntry(key: name, value: (command, code)) in invalid.entries) {
      test('rejects $name', () {
        expect(rejection(decide(started, command)), code);
      });
    }

    test('a rejection draws no id', () {
      final ids = SequentialIdSource();
      decide(
        started,
        CreateAgent(name: '', attributes: validScores()),
        ids: ids,
      );
      expect(ids.next(), const EntityId('e1'));
    });
  });

  test('replay of a recorded log equals the state built step by step', () {
    final ids = SequentialIdSource();
    var state = const OperationState.initial();
    final log = <Event>[];
    for (final command in <Command>[
      const StartOperation(operationId: 'op1'),
      CreateAgent(name: 'Hall', attributes: validScores()),
      CreateAgent(
        name: 'Vale',
        attributes: validScores(),
        ownerAlias: const AliasId('v'),
      ),
    ]) {
      final events = accepted(
        engine.decide(state, command, ScriptedRng([]), ids),
      );
      log.addAll(events);
      state = engine.replay(state, events);
    }
    expect(engine.replay(const OperationState.initial(), log), state);
    expect(state.stores.all(Identity.componentType).length, 2);
  });
}
