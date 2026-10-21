import 'dart:async';

import 'package:engine/engine.dart';
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/entries_codec.dart';
import 'support/test_pack.dart';

AgentCreated agentCreated(
  String id,
  Visibility visibility, {
  String name = 'X',
}) => AgentCreated(
  entity: EntityId(id),
  name: name,
  attributes: validScores(),
  skills: const {},
  ownerAlias: null,
  actor: const GmActor(),
  visibility: visibility,
);

void main() {
  group('deliveryFor (03 §Visibility and perspectives)', () {
    final hall = PlayerPerspective(AliasId('hall'));
    final table = const TablePerspective();
    const gm = GmPerspective();
    final aliases = AliasesOnly({AliasId('hall')});

    test('the GM sees everything in full', () {
      for (final v in [
        const Public(),
        const GmOnly(),
        const Redacted(),
        aliases,
      ]) {
        expect(deliveryFor(v, gm), Delivery.full);
      }
    });

    test('players and the table', () {
      expect(deliveryFor(const Public(), hall), Delivery.full);
      expect(deliveryFor(const Public(), table), Delivery.full);
      expect(deliveryFor(const GmOnly(), hall), Delivery.hidden);
      expect(deliveryFor(const Redacted(), hall), Delivery.redacted);
      expect(deliveryFor(const Redacted(), table), Delivery.redacted);
      expect(deliveryFor(aliases, hall), Delivery.full);
      expect(
        deliveryFor(aliases, PlayerPerspective(AliasId('vale'))),
        Delivery.hidden,
      );
      expect(deliveryFor(aliases, table), Delivery.hidden);
    });
  });

  group('projectFor', () {
    final hall = PlayerPerspective(AliasId('hall'));
    final edited = const DamageApplied(
      entity: EntityId('e1'),
      amount: 1,
      overriddenFrom: 3,
      actor: GmActor(),
      visibility: Public(),
    );

    test('the GM and the store keep the whole event', () {
      expect(projectFor(edited, const GmPerspective()), same(edited));
    });

    test('players read the final value only', () {
      final seen = projectFor(edited, hall) as DamageApplied;
      expect(seen.amount, 1);
      expect(seen.overriddenFrom, isNull);
      expect(
        (projectFor(
          SanityLost(
            entity: const EntityId('e1'),
            amount: 2,
            overriddenFrom: 5,
            actor: const GmActor(),
            visibility: const Public(),
          ),
          hall,
        ) as SanityLost).overriddenFrom,
        isNull,
      );
      expect(
        (projectFor(
          const ConditionApplied(
            entity: EntityId('e1'),
            condition: 'dazed',
            overriddenFrom: 'stunned',
            actor: GmActor(),
            visibility: Public(),
          ),
          hall,
        ) as ConditionApplied).overriddenFrom,
        isNull,
      );
    });

    test(
      'a broadcast is narrowed to the viewer so co-recipients stay hidden',
      () {
        final delivered = BroadcastDelivered(
          text: 'Meet at dawn',
          actor: const GmActor(),
          visibility: AliasesOnly({AliasId('hall'), AliasId('vale')}),
        );
        final seen = projectFor(delivered, hall) as BroadcastDelivered;
        expect(seen.visibility.aliases, {AliasId('hall')});
        expect(seen.text, 'Meet at dawn');
        final gm = projectFor(delivered, const GmPerspective());
        expect((gm as BroadcastDelivered).visibility.aliases, hasLength(2));
      },
    );

    test('a check addressed to several aliases is narrowed to the viewer', () {
      final required = CheckRequired(
        check: const CheckId('c1'),
        spec: CheckSpec(entity: const EntityId('e1'), attribute: 'STR', dc: 10),
        actor: const GmActor(),
        visibility: AliasesOnly({AliasId('hall'), AliasId('vale')}),
      );
      final seen = projectFor(required, hall) as CheckRequired;
      expect(seen.visibility, AliasesOnly({AliasId('hall')}));
      expect(seen.check, required.check);
    });

    test('other events pass through unchanged', () {
      final created = agentCreated('e1', const Public());
      expect(projectFor(created, hall), same(created));
    });
  });

  group('PerspectiveFeed', () {
    late PerspectiveFeed feed;
    setUp(() => feed = PerspectiveFeed(Engine(testPack())));

    EventEntry full(int seq, String id, [Visibility v = const Public()]) =>
        FullEntry(seq, agentCreated(id, v));

    test('applies consecutive entries and ignores applied ones', () {
      expect(feed.apply([full(1, 'e1'), full(2, 'e2')]), FeedResult.applied);
      expect(feed.lastSeq, 2);
      expect(feed.apply([full(1, 'e1'), full(2, 'e2')]), FeedResult.duplicate);
      expect(feed.apply([full(2, 'e2'), full(3, 'e3')]), FeedResult.applied);
      expect(feed.state.stores.entities, hasLength(3));
    });

    test('a gap changes nothing', () {
      feed.apply([full(1, 'e1')]);
      expect(feed.apply([full(3, 'e3')]), FeedResult.gap);
      expect(feed.apply([full(2, 'e2'), full(4, 'e4')]), FeedResult.gap);
      expect(feed.lastSeq, 1);
      expect(feed.state.stores.entities, hasLength(1));
    });

    test('redacted and hidden entries advance seq without evolving', () {
      feed.apply([
        full(1, 'e1'),
        const RedactedEntry(2),
        const HiddenEntry(3),
        full(4, 'e4'),
      ]);
      expect(feed.lastSeq, 4);
      expect(feed.opaqueSeqs, [2, 3]);
      expect(feed.state.stores.entities, hasLength(2));
    });
  });

  group('entries on the wire', () {
    const codec = TestCodecForEntries();
    test('round trip, with and without a request ack', () {
      final entries = <EventEntry>[
        FullEntry(1, agentCreated('e1', const Public()), requestId: 'r1'),
        FullEntry(2, agentCreated('e2', const GmOnly())),
        const RedactedEntry(3),
        const HiddenEntry(4),
        const RedactedEntry(5, requestId: 'r5'),
        const HiddenEntry(6, requestId: 'r6'),
      ];
      final back = [
        for (final e in entries)
          EventEntry.fromJson(e.toJson(codec.codec), codec.codec),
      ];
      expect((back[0] as FullEntry).requestId, 'r1');
      expect((back[1] as FullEntry).requestId, isNull);
      expect(back[2], isA<RedactedEntry>());
      expect(back[3], isA<HiddenEntry>());
      expect(back.map((e) => e.seq), [1, 2, 3, 4, 5, 6]);
      expect(back.map((e) => e.requestId), [
        'r1',
        null,
        null,
        null,
        'r5',
        'r6',
      ]);
    });

    test('malformed entries are format errors', () {
      for (final bad in <Map<String, Object?>>[
        {},
        {'seq': 0},
        {'seq': 1},
        {'seq': 1, 'event': 'x'},
        {'seq': 1, 'event': <String, Object?>{}, 'req': 3},
      ]) {
        expect(
          () => EventEntry.fromJson(bad, codec.codec),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
    });
  });

  group('Mailbox', () {
    test(
      'runs tasks one at a time, in order, and survives a failure',
      () async {
        final box = Mailbox();
        final order = <String>[];
        final first = box.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          order.add('first');
        });
        final bad = box.run<void>(() => throw StateError('boom'));
        final last = box.run(() => order.add('last'));
        await expectLater(bad, throwsStateError);
        await first;
        await last;
        expect(order, ['first', 'last']);
      },
    );
  });

  group('InMemoryEventStore contract', () {
    StoredEvent stored(int seq) => StoredEvent(
      seq: seq,
      time: DateTime.utc(2026),
      engineVersion: '1.0.0',
      event: {'n': seq},
    );

    test('append continues the sequence and read honours fromSeq', () async {
      final store = InMemoryEventStore();
      await store.append(
        'op',
        [stored(1), stored(2)],
        const [],
        const HeadSnapshot(seq: 2, state: {}, rngDrawCount: 3),
      );
      await store.append(
        'op',
        [stored(3)],
        [
          TextLogLine(seq: 3, time: DateTime.utc(2026), variants: {'gm': 'x'}),
        ],
        const HeadSnapshot(seq: 3, state: {}, rngDrawCount: 3),
      );
      expect((await store.read('op', fromSeq: 2).toList()).map((e) => e.seq), [
        2,
        3,
      ]);
      expect((await store.readText('op').toList()).single.seq, 3);
      expect((await store.headSnapshot('op'))!.seq, 3);
      expect(await store.rngDrawCount('op'), 3);
      expect(await store.headSnapshot('other'), isNull);
    });

    test(
      'a batch with a gap or overlap is refused and stores nothing',
      () async {
        final store = InMemoryEventStore();
        const head = HeadSnapshot(seq: 0, state: {}, rngDrawCount: 0);
        await expectLater(
          store.append('op', [stored(2)], const [], head),
          throwsStateError,
        );
        await store.append('op', [stored(1)], const [], head);
        await expectLater(
          store.append('op', [stored(1)], const [], head),
          throwsStateError,
        );
        expect(await store.read('op').length, 1);
      },
    );

    test('the draw count never goes down', () async {
      final store = InMemoryEventStore();
      await store.saveRngDrawCount('op', 9);
      await store.saveRngDrawCount('op', 4);
      expect(await store.rngDrawCount('op'), 9);
    });
  });

  group('InMemoryNetwork (transport contract)', () {
    test(
      'frames arrive in order in both directions, and close ends them',
      () async {
        final net = InMemoryNetwork();
        final links = net
            .host(const Address('h'))
            .incoming()
            .asBroadcastStream();
        final clientLink = await net.client().connect(const Address('h'));
        final hostLink = await links.first;
        final atHost = <String>[];
        final atClient = <String>[];
        final hostFrames = hostLink.frames.asBroadcastStream();
        hostFrames.listen(atHost.add);
        clientLink.frames.listen(atClient.add);
        await clientLink.send('a');
        await clientLink.send('b');
        await hostLink.send('c');
        await pumpEventQueue();
        expect(atHost, ['a', 'b']);
        expect(atClient, ['c']);

        var done = false;
        hostFrames.listen(null, onDone: () => done = true);
        await clientLink.close();
        await pumpEventQueue();
        expect(done, isTrue);
        await expectLater(clientLink.send('x'), throwsStateError);
      },
    );

    test('connecting to nothing, or listening twice, is an error', () async {
      final net = InMemoryNetwork();
      await expectLater(
        net.client().connect(const Address('none')),
        throwsStateError,
      );
      net.host(const Address('h'));
      expect(() => net.host(const Address('h')), throwsStateError);
    });
  });

  test('FakeClock moves only when told', () {
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    clock.advance(const Duration(minutes: 5));
    expect(clock.now(), DateTime.utc(2026, 1, 1, 0, 5));
  });
}
