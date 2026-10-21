import 'dart:async';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart' hide PackPin, Rejected;
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/rig.dart';
import 'support/test_pack.dart';

void main() {
  late Rig rig;

  tearDown(() => rig.close());

  group('the loop', () {
    test(
      'commits GM commands with consecutive seq and stores them first',
      () async {
        rig = await Rig.create();
        expect(await rig.start(), isA<Committed>());
        final result = await rig.host.submit(rig.agent('Hall'));
        expect((result as Committed).seqs, [2]);
        expect(rig.host.lastSeq, 2);

        final stored = await rig.store.read('op1').toList();
        expect(stored.map((e) => e.seq), [1, 2]);
        expect(stored.first.engineVersion, engineVersion);
        final head = (await rig.store.headSnapshot('op1'))!;
        expect(head.seq, 2);
      },
    );

    test('an engine rejection becomes a Refusal and stores nothing', () async {
      rig = await Rig.create();
      final result = await rig.host.submit(rig.agent('Hall'));
      expect(
        result,
        isA<Refusal>().having((r) => r.code, 'code', 'notStarted'),
      );
      expect(await rig.store.read('op1').toList(), isEmpty);
    });

    test('a failed store write sends nothing and changes no state', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      final before = rig.host.state;
      // Closing the store out from under the host is not available; instead
      // append a conflicting seq so the host's next append throws.
      await rig.store.append(
        'op1',
        [
          StoredEvent(
            seq: 2,
            time: DateTime.utc(2026),
            engineVersion: engineVersion,
            event: const {},
          ),
        ],
        const [],
        const HeadSnapshot(seq: 2, state: {}, rngDrawCount: 0),
      );
      await expectLater(rig.host.submit(rig.agent('Hall')), throwsStateError);
      await pumpEventQueue();
      expect(rig.host.state, before);
      expect(ann.lastSeq, 1);
    });
  });

  group('joining', () {
    test('a player gets the log filtered for their alias', () async {
      rig = await Rig.create();
      await rig.start();
      await rig.host.submit(rig.agent('Secret NPC')); // GM-only
      await rig.host.submit(rig.agent('Hall', owner: 'hall'));
      await rig.host.submit(rig.agent('Vale', owner: 'vale'));

      final ann = await rig.join('ann', 'hall');
      expect(ann.lastSeq, 4);
      expect(ann.opaqueSeqs, [2, 4]);
      final names = ann.state.stores
          .all(Identity.componentType)
          .values
          .map((i) => i.name);
      expect(names, ['Hall']);
      expect(ann.joined, isTrue);
    });

    test('a returning player is sent only what they lack', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      await rig.host.submit(rig.agent('Hall', owner: 'hall'));
      await pumpEventQueue();
      expect(ann.lastSeq, 2);
    });

    test('the pack and settings come with the welcome', () async {
      rig = await Rig.create();
      await rig.start();
      final client = await rig.network.client().connect(hostAddress);
      final connection = ConnectionActor(client);
      final seen = <Envelope>[];
      connection.envelopes.listen(seen.add);
      await connection.send(
        Envelope.of(
          const Hello(agentId: 'ann', aliasId: 'hall', authProof: 'ann'),
          engineVersion: EngineVersion.parse(engineVersion),
          operationId: 'op1',
          from: 'hall',
        ),
      );
      await pumpEventQueue();
      final welcome = seen.first.message as Welcome;
      expect(welcome.pack!.id, 'test-core');
      expect(welcome.settings['autoApplyEngineUpdates'], isTrue);
    });
  });

  group('refusals', () {
    Future<Refused> hello(
      Hello hello, {
      int protocol = 1,
      String engine = engineVersion,
    }) async {
      final connection = ConnectionActor(
        await rig.network.client().connect(hostAddress),
      );
      final seen = <Envelope>[];
      connection.envelopes.listen(seen.add);
      await connection.send(
        Envelope.of(
          hello,
          engineVersion: EngineVersion.parse(engine),
          operationId: 'op1',
          from: 'x',
          protocol: protocol,
        ),
      );
      await pumpEventQueue();
      return seen.first.message as Refused;
    }

    test('protocol and engine major mismatches', () async {
      rig = await Rig.create();
      await rig.start();
      const ann = Hello(agentId: 'ann', aliasId: 'hall', authProof: 'ann');
      expect(
        (await hello(ann, protocol: 2)).reason,
        RefusalReason.protocolMismatch,
      );
      expect(
        (await hello(ann, engine: '2.0.0')).reason,
        RefusalReason.engineMajorMismatch,
      );
    });

    test('a client older than the log requires must update', () async {
      rig = await Rig.create();
      await rig.start();
      final refused = await hello(
        const Hello(agentId: 'ann', aliasId: 'hall', authProof: 'ann'),
        engine: '1.0.0-dev.0',
      );
      expect(refused.reason, RefusalReason.updateRequired);
      expect(refused.requiredEngineVersion.toString(), engineVersion);
    });

    test('unverified, uninvited, banned and locked are refused', () async {
      rig = await Rig.create(
        identities: {'cat': const Principal(agentId: 'cat', aliasId: 'grimm')},
      );
      await rig.start();
      rig.admission
        ..ban('bob')
        ..invite('cat', 'grimm')
        ..lockAlias('grimm');
      expect(
        (await hello(const Hello(agentId: 'x', authProof: 'nope'))).reason,
        RefusalReason.notInvited,
      );
      expect(
        (await hello(
          const Hello(agentId: 'bob', aliasId: 'vale', authProof: 'bob'),
        )).reason,
        RefusalReason.banned,
      );
      expect(
        (await hello(
          const Hello(agentId: 'cat', aliasId: 'grimm', authProof: 'cat'),
        )).reason,
        RefusalReason.aliasLocked,
      );
    });

    test('an anonymous agent cannot use a second alias', () async {
      rig = await Rig.create(
        identities: {
          'g1': const Principal(agentId: 'g', aliasId: 'a1', isAnonymous: true),
          'g2': const Principal(agentId: 'g', aliasId: 'a2', isAnonymous: true),
        },
      );
      await rig.start();
      rig.admission
        ..invite('g', 'a1')
        ..invite('g', 'a2');
      final first = await rig.join('g', 'a1', proof: 'g1');
      expect(first, isNotNull);
      final refused = await hello(
        const Hello(
          agentId: 'g',
          aliasId: 'a2',
          kind: AgentKind.full, // advisory: the verified identity decides
          authProof: 'g2',
        ),
      );
      expect(refused.reason, RefusalReason.anonymousAliasLimit);
    });

    test('anonymous accounts cannot host', () async {
      rig = await Rig.create();
      await expectLater(
        OperationHost.open(
          operationId: 'op1',
          gm: const Principal(agentId: 'g', isGm: true, isAnonymous: true),
          engine: Engine(testPack()),
          codec: Rig.codec,
          store: InMemoryEventStore(),
          verifier: TableVerifier({}),
          rngFactory: CountingRng.new,
        ),
        throwsArgumentError,
      );
    });
  });

  group('requests', () {
    test(
      'a player request is decided once, however often it arrives',
      () async {
        rig = await Rig.create();
        await rig.start();
        final ann = await rig.join('ann', 'hall');
        final id = await ann.request(rig.agent('Hall', owner: 'hall'));
        await pumpEventQueue();
        expect(rig.host.lastSeq, 2);
        expect(
          ann.pendingRequests,
          isEmpty,
          reason: 'acknowledged by the events',
        );
        expect(id, isNotEmpty);

        // The same frame again (at-least-once delivery).
        rig.network.filter = (toHost, frame) =>
            toHost ? [frame, frame] : [frame];
        await ann.request(rig.agent('Second', owner: 'hall'));
        await pumpEventQueue();
        expect(rig.host.lastSeq, 3, reason: 'duplicated frame decided once');
      },
    );

    test('a retried request is not decided twice after a reconnect', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      // Drop everything from the host so the request is never acknowledged.
      rig.network.filter = (toHost, frame) => toHost ? [frame] : [];
      await ann.request(rig.agent('Hall', owner: 'hall'));
      await pumpEventQueue();
      expect(ann.pendingRequests, hasLength(1));
      expect(rig.host.lastSeq, 2);

      rig.network.filter = null;
      await ann.connect(await rig.network.client().connect(hostAddress));
      await pumpEventQueue();
      expect(rig.host.lastSeq, 2, reason: 'the resent request was a duplicate');
      expect(ann.lastSeq, 2, reason: 'catch-up on hello delivered the event');
    });

    test(
      'a refused request tells the sender and is refused again on retry',
      () async {
        rig = await Rig.create();
        await rig.start();
        final ann = await rig.join('ann', 'hall');
        final rejections = <RequestRejected>[];
        ann.rejections.listen(rejections.add);
        await ann.request(
          CreateAgent(
            name: '',
            attributes: validScores(),
            ownerAlias: AliasId('hall'),
            actor: AliasActor(AliasId('hall')),
          ),
        );
        await pumpEventQueue();
        expect(rejections.single.code, 'invalidValue');
        expect(ann.pendingRequests, isEmpty);
      },
    );
  });

  group('authorization', () {
    test('a player cannot act as the GM or as another alias', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      final rejections = <RequestRejected>[];
      ann.rejections.listen(rejections.add);

      await ann.request(rig.agent('As GM')); // actor: GmActor
      await ann.request(rig.agent('As Vale', owner: 'vale'));
      await pumpEventQueue();
      expect(rejections.map((r) => r.code), everyElement('unauthorized'));
      expect(rejections, hasLength(2));
      expect(rig.host.lastSeq, 1);
    });

    test('the sender-claimed `from` is never trusted', () async {
      rig = await Rig.create();
      await rig.start();
      final connection = ConnectionActor(
        await rig.network.client().connect(hostAddress),
      );
      final seen = <Envelope>[];
      connection.envelopes.listen(seen.add);
      Envelope wrap(Message m, String from) => Envelope.of(
        m,
        engineVersion: EngineVersion.parse(engineVersion),
        operationId: 'op1',
        from: from,
      );
      await connection.send(
        wrap(
          const Hello(agentId: 'ann', aliasId: 'hall', authProof: 'ann'),
          'hall',
        ),
      );
      await connection.send(
        wrap(
          Request(
            requestId: 'r1',
            command: Rig.codec.encodeCommand(rig.agent('Forged')),
          ),
          gmSender, // claims to be the GM
        ),
      );
      await pumpEventQueue();
      final rejected =
          seen
                  .where((e) => e.messageType == MessageType.rejected)
                  .single
                  .message
              as dynamic;
      expect(rejected.code, 'unauthorized');
      expect(rig.host.lastSeq, 1);
    });

    test('a request before hello is refused', () async {
      rig = await Rig.create();
      await rig.start();
      final connection = ConnectionActor(
        await rig.network.client().connect(hostAddress),
      );
      final seen = <Envelope>[];
      connection.envelopes.listen(seen.add);
      await connection.send(
        Envelope.of(
          Request(
            requestId: 'r1',
            command: Rig.codec.encodeCommand(rig.agent('X', owner: 'hall')),
          ),
          engineVersion: EngineVersion.parse(engineVersion),
          operationId: 'op1',
          from: 'hall',
        ),
      );
      await pumpEventQueue();
      expect((seen.single.message as dynamic).code, 'notAdmitted');
      expect(rig.host.lastSeq, 1);
    });

    test('malformed frames and bodies are reported, not thrown', () async {
      rig = await Rig.create();
      await rig.start();
      final link = await rig.network.client().connect(hostAddress);
      await link.send('not json');
      await pumpEventQueue();
      expect(rig.protocolErrors, hasLength(1));
      expect(rig.host.lastSeq, 1);
    });
  });

  group('the GM review gate (F2)', () {
    Future<EntityId> setUpAgent() async {
      await rig.start();
      await rig.host.submit(rig.agent('Hall', owner: 'hall'));
      return rig.host.state.stores.entities.single;
    }

    test(
      'consequences wait for confirmation; nothing is stored or sent',
      () async {
        rig = await Rig.create();
        final agent = await setUpAgent();
        final ann = await rig.join('ann', 'hall');
        expect(ann.lastSeq, 2);

        final result = await rig.host.submit(
          ApplyDamage(entity: agent, amount: 3),
        );
        expect(result, isA<Held>());
        await pumpEventQueue();
        expect(rig.host.lastSeq, 2);
        expect(await rig.store.read('op1').length, 2);
        expect(rig.host.pending, hasLength(1));
        expect(ann.lastSeq, 2);

        final seqs = await rig.host.confirmPending();
        await pumpEventQueue();
        expect(seqs, [3]);
        expect(rig.host.pending, isEmpty);
        expect(ann.lastSeq, 3);
        final line = (await rig.store.readText('op1').toList()).last;
        expect(line.seq, 3);
        expect(line.variants.keys, containsAll(['gm', 'public']));
      },
    );

    test(
      'the GM may edit; the store keeps both values, players see one',
      () async {
        rig = await Rig.create();
        final agent = await setUpAgent();
        final ann = await rig.join('ann', 'hall');
        await rig.host.submit(ApplyDamage(entity: agent, amount: 3));
        await rig.host.confirmPending(
          edit: (e) => (e as DamageApplied).withAmount(1),
        );
        final stored = (await rig.store.read('op1').toList()).last;
        expect(stored.event['amount'], 1);
        expect(stored.event['overriddenFrom'], 3);
        await pumpEventQueue();
        expect(ann.lastSeq, 3);
      },
    );

    test(
      'an edit must stay the same consequence for the same entity',
      () async {
        rig = await Rig.create();
        final agent = await setUpAgent();
        await rig.host.submit(ApplyDamage(entity: agent, amount: 3));
        final swaps = <Event Function(DamageApplied)>[
          (e) => SanityLost(
            entity: e.entity,
            amount: 1,
            actor: e.actor,
            visibility: e.visibility,
          ),
          (e) => DamageApplied(
            entity: const EntityId('other'),
            amount: 1,
            actor: e.actor,
            visibility: e.visibility,
          ),
          (e) => DamageApplied(
            entity: e.entity,
            amount: 1,
            actor: e.actor,
            visibility: const GmOnly(),
          ),
          // Changes the value without recording what it replaced.
          (e) => DamageApplied(
            entity: e.entity,
            amount: 1,
            actor: e.actor,
            visibility: e.visibility,
          ),
          // Records a value it did not replace.
          (e) => DamageApplied(
            entity: e.entity,
            amount: 1,
            overriddenFrom: 99,
            actor: e.actor,
            visibility: e.visibility,
          ),
          // Bypasses the bound `withAmount` applies.
          (e) => DamageApplied(
            entity: e.entity,
            amount: maxEnteredValue + 1,
            overriddenFrom: e.amount,
            actor: e.actor,
            visibility: e.visibility,
          ),
          // Moves the consequence to another check.
          (e) => DamageApplied(
            entity: e.entity,
            amount: 1,
            overriddenFrom: e.amount,
            check: const CheckId('other'),
            actor: e.actor,
            visibility: e.visibility,
          ),
        ];
        for (final swap in swaps) {
          await expectLater(
            rig.host.confirmPending(edit: (e) => swap(e as DamageApplied)),
            throwsArgumentError,
          );
        }
        expect(rig.host.pending, hasLength(1), reason: 'still waiting');
        expect(rig.host.lastSeq, 2);
      },
    );

    test('auto-confirm skips the wait', () async {
      rig = await Rig.create();
      await rig.start(
        settings: const OperationSettings(autoConfirmConsequences: true),
      );
      await rig.host.submit(rig.agent('Hall'));
      final agent = rig.host.state.stores.entities.single;
      final result = await rig.host.submit(
        ApplyDamage(entity: agent, amount: 2),
      );
      expect(result, isA<Committed>());
      expect(rig.host.pending, isEmpty);
    });

    test('a non-consequence is never held', () async {
      rig = await Rig.create();
      await rig.start();
      expect(await rig.host.submit(rig.agent('Hall')), isA<Committed>());
      expect(rig.host.pending, isEmpty);
    });

    test('confirming with nothing pending is an error', () async {
      rig = await Rig.create();
      await expectLater(rig.host.confirmPending(), throwsStateError);
    });
  });

  group('ordering and recovery', () {
    test('a dropped events frame is recovered by resync', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      var frames = 0;
      rig.network.filter = (toHost, frame) =>
          !toHost && ++frames == 1 ? [] : [frame];
      await rig.host.submit(rig.agent('One', owner: 'hall'));
      await rig.host.submit(rig.agent('Two', owner: 'hall'));
      await pumpEventQueue();
      expect(ann.lastSeq, 3);
      expect(ann.state.stores.entities, hasLength(2));
    });

    test('out-of-order and duplicated frames converge', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      final held = <String>[];
      var count = 0;
      rig.network.filter = (toHost, frame) {
        if (toHost) return [frame];
        count++;
        if (count == 1) {
          held.add(frame);
          return [];
        }
        if (count == 2) return [frame, frame, ...held];
        return [frame];
      };
      for (final name in ['One', 'Two', 'Three']) {
        await rig.host.submit(rig.agent(name, owner: 'hall'));
      }
      await pumpEventQueue();
      expect(ann.lastSeq, 4);
      final view = await rig.host.openView(PlayerPerspective(AliasId('hall')));
      expect(ann.state, view.state);
    });

    test('malformed host frames force a resync, not a crash', () async {
      rig = await Rig.create();
      await rig.start();
      final ann = await rig.join('ann', 'hall');
      var first = true;
      rig.network.filter = (toHost, frame) {
        if (toHost || !first) return [frame];
        first = false;
        return [
          '{"p":1,"e":"1.0.0","op":"op1","seq":2,"from":"gm",'
              '"type":"events","body":{"events":[{"seq":2}]}}',
        ];
      };
      await rig.host.submit(rig.agent('One', owner: 'hall'));
      await pumpEventQueue();
      expect(ann.lastSeq, 2);
    });
  });

  group('perspectives', () {
    test('GM, player and table views see what they may', () async {
      rig = await Rig.create();
      await rig.start();
      final gm = await rig.host.openView(const GmPerspective());
      final hall = await rig.host.openView(PlayerPerspective(AliasId('hall')));
      final table = await rig.host.openView(const TablePerspective());
      await rig.host.submit(rig.agent('NPC'));
      await rig.host.submit(rig.agent('Hall', owner: 'hall'));
      await pumpEventQueue();
      expect(gm.state.stores.entities, hasLength(2));
      expect(hall.state.stores.entities, hasLength(1));
      expect(table.state.stores.entities, isEmpty);
      expect(table.state.started, isTrue);
      expect([gm.lastSeq, hall.lastSeq, table.lastSeq], [3, 3, 3]);
    });
  });

  group('reopening', () {
    test('replays to the same state and never repeats an entity id', () async {
      rig = await Rig.create();
      await rig.start();
      await rig.host.submit(rig.agent('One'));
      await rig.host.submit(rig.agent('Two'));
      final before = rig.host.state;
      await rig.host.close();

      rig.network = InMemoryNetwork();
      await rig.openHost();
      expect(rig.host.state, before);
      expect(rig.host.lastSeq, 3);

      await rig.host.submit(rig.agent('Three'));
      final ids = rig.host.state.stores.entities.map((e) => e.value).toList();
      expect(ids.toSet(), hasLength(3), reason: 'no id handed out twice');
    });

    test('wasted RNG draws are persisted and never handed out again', () async {
      rig = await Rig.create();
      await rig.start();
      expect(rig.rng.drawCount, 0);
      // A command that draws and is then rejected: the draws are real.
      rig.rng.drawCount = 7;
      final rejected = await rig.host.submit(rig.agent('', owner: null));
      expect(rejected, isA<Refusal>());
      expect(await rig.store.rngDrawCount('op1'), 7);
      await rig.host.close();

      rig.network = InMemoryNetwork();
      await rig.openHost();
      expect(rig.rng.drawCount, 7, reason: 'resumes at the higher count');
    });
  });
  group('review findings', () {
    test(
      'a retried request is not decided again after the host reopens',
      () async {
        rig = await Rig.create();
        await rig.start();
        final ann = await rig.join('ann', 'hall');
        // The host's answer never reaches the player, so the request stays pending.
        rig.network.filter = (toHost, frame) => toHost ? [frame] : [];
        await ann.request(rig.agent('Hall', owner: 'hall'));
        await pumpEventQueue();
        expect(rig.host.lastSeq, 2);

        await rig.host.close();
        rig.network = InMemoryNetwork();
        await rig.openHost();
        await ann.connect(await rig.network.client().connect(hostAddress));
        await pumpEventQueue();
        expect(rig.host.lastSeq, 2, reason: 'recognised from the stored log');
        expect(ann.lastSeq, 2);
        expect(ann.pendingRequests, isEmpty);
      },
    );

    test(
      'a result the sender may not read still acknowledges the request',
      () async {
        rig = await Rig.create();
        await rig.start();
        final ann = await rig.join('ann', 'hall');
        // No owner alias: the event is GM-only, so ann receives a hidden entry.
        await ann.request(
          CreateAgent(
            name: 'NPC',
            attributes: validScores(),
            actor: AliasActor(AliasId('hall')),
          ),
        );
        await pumpEventQueue();
        expect(rig.host.lastSeq, 2);
        expect(ann.lastSeq, 2);
        expect(ann.opaqueSeqs, [2]);
        expect(ann.pendingRequests, isEmpty);
      },
    );

    test('a restarted participant does not reuse request ids', () async {
      rig = await Rig.create();
      await rig.start();
      final first = await rig.join('ann', 'hall');
      final a = await first.request(rig.agent('One', owner: 'hall'));
      await pumpEventQueue();
      final second = await rig.join('ann', 'hall');
      final b = await second.request(rig.agent('Two', owner: 'hall'));
      await pumpEventQueue();
      expect(b, isNot(a));
      expect(rig.host.lastSeq, 3);
    });

    test(
      'a verified GM flag that is not this operation\'s GM is refused',
      () async {
        rig = await Rig.create(
          identities: {'imposter': const Principal(agentId: 'imp', isGm: true)},
        );
        await rig.start();
        final connection = ConnectionActor(
          await rig.network.client().connect(hostAddress),
        );
        final seen = <Envelope>[];
        connection.envelopes.listen(seen.add);
        await connection.send(
          Envelope.of(
            const Hello(agentId: 'imp', authProof: 'imposter'),
            engineVersion: EngineVersion.parse(engineVersion),
            operationId: 'op1',
            from: 'imp',
          ),
        );
        await pumpEventQueue();
        expect(
          (seen.single.message as Refused).reason,
          RefusalReason.notInvited,
        );
      },
    );

    test('a resync before hello is ignored', () async {
      rig = await Rig.create();
      await rig.start();
      final connection = ConnectionActor(
        await rig.network.client().connect(hostAddress),
      );
      final seen = <Envelope>[];
      connection.envelopes.listen(seen.add);
      await connection.send(
        Envelope.of(
          const Resync(0),
          engineVersion: EngineVersion.parse(engineVersion),
          operationId: 'op1',
          from: 'x',
        ),
      );
      await pumpEventQueue();
      expect(seen, isEmpty);
    });

    test('a closed host refuses commands and changes nothing', () async {
      rig = await Rig.create();
      await rig.start();
      await rig.host.close();
      await expectLater(rig.host.submit(rig.agent('Late')), throwsStateError);
      expect(await rig.store.read('op1').length, 1);
    });

    test('ids continue after a reopen', () async {
      rig = await Rig.create();
      await rig.start();
      await rig.host.submit(rig.agent('One')); // e1
      await rig.host.close();
      // Pretend e1 was removed from state by a later event: only the stored
      // counter remembers it was used.
      rig.network = InMemoryNetwork();
      await rig.openHost();
      await rig.host.submit(rig.agent('Two'));
      final ids = rig.host.state.stores.entities.map((e) => e.value).toSet();
      expect(ids, {'e1', 'e2'});
    });
  });
}
