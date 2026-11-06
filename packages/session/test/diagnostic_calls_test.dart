import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/rig.dart';
import 'support/test_pack.dart';

void main() {
  late Rig rig;

  tearDown(() => rig.close());

  List<String> kinds() => [for (final e in rig.hostLog.entries) e.kind];
  DiagnosticEntry entry(String kind) =>
      rig.hostLog.entries.firstWhere((e) => e.kind == kind);

  test('opening, joining, committing and closing leave a trail', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.join('ann', 'hall');
    await rig.host.submit(rig.agent('Hall', owner: 'hall'));
    await pumpEventQueue();

    expect(
      kinds(),
      containsAllInOrder([
        'host.opened',
        'host.listening',
        'batch.committed',
        'link.opened',
        'hello.joined',
        'batch.committed',
      ]),
    );
    expect(entry('host.opened').fields['resumed'], isFalse);
    final joined = entry('hello.joined').fields;
    expect(joined['role'], 'player');
    expect(joined['hostLastSeq'], 1);
    expect(joined['agentId'], isNot('ann'));
  });

  test('a reopened host says it resumed, with the stored seq', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.host.close();
    rig.network = InMemoryNetwork();
    await rig.openHost();
    final opened = rig.hostLog.entries.where((e) => e.kind == 'host.opened');
    expect(opened.last.fields['resumed'], isTrue);
    expect(opened.last.fields['lastSeq'], 1);
    expect(kinds(), contains('host.closed'));
  });

  test('requests: committed, held, confirmed and refused', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.host.submit(rig.agent('Hall', owner: 'hall'));
    final agent = rig.host.state.stores.entities.single;
    final ann = await rig.join('ann', 'hall');
    final annLog = DiagnosticLog(clock: FakeClock());
    final bob = await rig.join('bob', 'vale', log: annLog);

    await ann.request(rig.agent('As GM')); // unauthorized
    await bob.request(rig.agent('As Ann', owner: 'hall')); // unauthorized
    await pumpEventQueue();
    final refused = entry('request.refused').fields;
    expect(refused['reason'], 'unauthorized');
    expect(refused['command'], 'CreateAgent');

    await rig.host.submit(ApplyDamage(entity: agent, amount: 2));
    await rig.host.confirmPending();
    expect(kinds(), contains('pending.confirmed'));

    // The participant side, on its own log.
    expect(annLog.entries.map((e) => e.kind), contains('hello.welcomed'));
    expect(annLog.entries.map((e) => e.kind), contains('request.rejected'));
  });

  test('a bad frame and a closed link are recorded', () async {
    rig = await Rig.create();
    await rig.start();
    final link = await rig.network.client().connect(hostAddress);
    await link.send('not json');
    await pumpEventQueue();
    await link.close();
    await pumpEventQueue();
    expect(kinds(), containsAll(['protocol.error', 'link.closed']));
    expect(entry('protocol.error').category, DiagnosticCategory.error);
  });

  test('a refused hello records only the reason', () async {
    rig = await Rig.create();
    await rig.start();
    final stranger = await rig.join('zed', 'hall', proof: 'unknown');
    expect(stranger.joined, isFalse);
    expect(entry('hello.refused').fields['reason'], 'unverified');
  });

  test('a failed store write is recorded as a store entry', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.store.append(
      'op1',
      [
        StoredEvent(
          seq: 2,
          time: DateTime.utc(2026),
          engineVersion: '1.0.0-dev.1',
          event: const {},
        ),
      ],
      const [],
      const HeadSnapshot(seq: 2, state: {}, rngDrawCount: 0),
    );
    await expectLater(rig.host.submit(rig.agent('Hall')), throwsStateError);
    final failed = entry('store.append.failed');
    expect(failed.category, DiagnosticCategory.store);
    expect(failed.fields['firstSeq'], 2);
  });

  test('a dropped frame shows as a gap and a resync with seqs', () async {
    rig = await Rig.create();
    await rig.start();
    final annLog = DiagnosticLog(clock: FakeClock());
    await rig.join('ann', 'hall', log: annLog);
    var frames = 0;
    rig.network.filter = (toHost, frame) =>
        !toHost && ++frames == 1 ? [] : [frame];
    await rig.host.submit(rig.agent('One', owner: 'hall'));
    await rig.host.submit(rig.agent('Two', owner: 'vale'));
    await pumpEventQueue();

    final gap = annLog.entries.firstWhere((e) => e.kind == 'gap.detected');
    expect(gap.fields['lastSeq'], 1);
    expect(gap.fields['firstReceivedSeq'], 3);
    expect(annLog.entries.map((e) => e.kind), contains('resync.requested'));
    expect(entry('resync.served').fields['fromSeq'], 2);
  });

  test('every call point fires in a full session', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.host.submit(rig.agent('Hall', owner: 'hall'));
    final agent = rig.host.state.stores.entities.single;
    final annLog = DiagnosticLog(clock: FakeClock());
    final ann = await rig.join('ann', 'hall', log: annLog);
    await ann.request(rig.agent('As GM'));
    await rig.host.submit(ApplyDamage(entity: agent, amount: 2));
    await rig.host.confirmPending();
    await pumpEventQueue();
    await ann.close();
    await pumpEventQueue();
    await rig.host.close();
    expect(
      kinds(),
      containsAll([
        'host.listening',
        'link.opened',
        'link.closed',
        'batch.committed',
        'request.refused',
        'pending.confirmed',
        'host.closed',
      ]),
    );
    expect(
      annLog.entries.map((e) => e.kind),
      containsAll(['link.connecting', 'hello.welcomed', 'request.rejected']),
    );
  });

  test('a host without a diagnostic log behaves the same', () async {
    rig = await Rig.create();
    await rig.host.close();
    rig.network = InMemoryNetwork();
    rig.host = await EpisodeHost.open(
      episodeId: 'op1',
      gm: gmIdentity,
      engine: Engine(testPack()),
      codec: Rig.codec,
      store: rig.store,
      verifier: rig.verifier,
      rngFactory: CountingRng.new,
    );
    rig.host.listen(rig.network.host(hostAddress));
    expect(await rig.start(), isA<Committed>());
  });

  test('a sink that throws does not break the log', () {
    final log = DiagnosticLog(clock: FakeClock(), sinks: [_Throws()])
      ..record(DiagnosticCategory.error, 'x');
    expect(log.entries, hasLength(1));
  });

  test('no entry holds message text, names or real ids', () async {
    rig = await Rig.create();
    await rig.start();
    final annLog = DiagnosticLog(clock: FakeClock());
    final ann = await rig.join('ann', 'hall', log: annLog);
    await rig.host.submit(rig.agent('Secret Name', owner: 'hall'));
    await ann.request(rig.agent('Player Typed Name', owner: 'hall'));
    await pumpEventQueue();
    final dump = [
      ...rig.hostLog.entries,
      ...annLog.entries,
    ].map((e) => jsonEncode(e.toJson())).join('\n');
    for (final leak in ['Secret Name', 'Player Typed Name', '"ann"', 'ann-']) {
      expect(dump, isNot(contains(leak)), reason: leak);
    }
  });
}

final class _Throws implements DiagnosticSink {
  @override
  void write(DiagnosticEntry entry) => throw StateError('disk full');
}
