import 'dart:async';

import 'package:engine/engine.dart';
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/rig.dart';
import 'support/test_pack.dart';

/// A client transport that remembers its links, so a test can drop them,
/// and can be told to fail the next connects.
final class _TestClient implements Transport {
  _TestClient(this._inner);

  final Transport _inner;
  final List<Link> links = [];
  final List<Object> failNext = [];

  @override
  Stream<Link> incoming() => const Stream.empty();

  @override
  Future<Link> connect(Address address) async {
    if (failNext.isNotEmpty) throw failNext.removeAt(0);
    final link = await _inner.connect(address);
    links.add(link);
    return link;
  }
}

/// A transport whose connect never completes.
final class _HangingClient implements Transport {
  @override
  Stream<Link> incoming() => const Stream.empty();

  @override
  Future<Link> connect(Address address) => Completer<Link>().future;
}

void main() {
  late Rig rig;
  late List<Duration> waits;
  late DiagnosticLog annLog;

  Future<void> noWait(Duration d) async => waits.add(d);

  EpisodeParticipant ann({Liveness? liveness}) {
    final player = EpisodeParticipant(
      episodeId: 'op1',
      agentId: 'ann',
      aliasId: 'hall',
      engine: Engine(testPack()),
      codec: Rig.codec,
      authProof: 'ann',
      diagnostics: annLog,
      liveness: liveness,
    );
    rig.participants.add(player);
    return player;
  }

  setUp(() {
    waits = [];
    annLog = DiagnosticLog(clock: FakeClock());
  });

  group('Backoff', () {
    test('doubles from the first wait up to the cap', () {
      const backoff = Backoff(
        initial: Duration(seconds: 1),
        max: Duration(seconds: 5),
      );
      expect(
        [for (var i = 0; i < 5; i++) backoff.delayFor(i).inSeconds],
        [1, 2, 4, 5, 5],
      );
    });
  });

  group('Reconnector', () {
    tearDown(() => rig.close());

    test('a dropped link reconnects and catches up from lastSeq', () async {
      rig = await Rig.create();
      await rig.start();
      final client = _TestClient(rig.network.client());
      final player = ann();
      final loop = Reconnector(
        participant: player,
        transport: client,
        address: hostAddress,
        wait: noWait,
      );
      final running = loop.run();
      await pumpEventQueue();
      expect(player.joined, isTrue);
      expect(player.lastSeq, 1);

      await client.links.single.close();
      await pumpEventQueue();
      await rig.host.submit(rig.agent('One', owner: 'hall'));
      await pumpEventQueue();

      expect(client.links, hasLength(2));
      expect(player.joined, isTrue);
      expect(player.lastSeq, rig.host.lastSeq);
      expect(waits, [const Backoff().initial]);

      loop.stop();
      expect(await running, ReconnectStop.stopped);
    });

    test('connect errors back off; ConnectRefused stops the loop', () async {
      rig = await Rig.create();
      final client = _TestClient(rig.network.client())
        ..failNext.addAll([
          StateError('down'),
          StateError('down'),
          const ConnectRefused('joinCode'),
        ]);
      final loop = Reconnector(
        participant: ann(),
        transport: client,
        address: hostAddress,
        wait: noWait,
        diagnostics: annLog,
      );
      expect(await loop.run(), ReconnectStop.connectRefused);
      expect(waits, [const Backoff().initial, const Backoff().initial * 2]);
      expect(
        annLog.entries.map((e) => e.kind),
        containsAll(['link.connectFailed', 'link.connectRefused']),
      );
    });

    test('a bad address stops the loop', () async {
      rig = await Rig.create();
      final client = _TestClient(rig.network.client())
        ..failNext.add(const FormatException('not an address'));
      final loop = Reconnector(
        participant: ann(),
        transport: client,
        address: hostAddress,
        wait: noWait,
      );
      expect(await loop.run(), ReconnectStop.badAddress);
      expect(waits, isEmpty);
    });

    test('stop ends a connect that never answers, and a real wait', () async {
      rig = await Rig.create();
      final hanging = _HangingClient();
      final loop = Reconnector(
        participant: ann(),
        transport: hanging,
        address: hostAddress,
      );
      final running = loop.run();
      await pumpEventQueue();
      loop.stop();
      expect(
        await running.timeout(const Duration(seconds: 1)),
        ReconnectStop.stopped,
      );

      // A real 30 s backoff timer is cancelled by stop.
      final failing = _TestClient(rig.network.client())
        ..failNext.add(StateError('down'));
      final slow = Reconnector(
        participant: ann(),
        transport: failing,
        address: hostAddress,
        backoff: const Backoff(initial: Duration(seconds: 30)),
      );
      final waiting = slow.run();
      await pumpEventQueue();
      slow.stop();
      expect(
        await waiting.timeout(const Duration(seconds: 1)),
        ReconnectStop.stopped,
      );
    });

    test('a readable refusal stops the loop', () async {
      rig = await Rig.create();
      final player = EpisodeParticipant(
        episodeId: 'op1',
        agentId: 'mallory',
        aliasId: 'hall',
        engine: Engine(testPack()),
        codec: Rig.codec,
        authProof: 'nobody',
      );
      rig.participants.add(player);
      final loop = Reconnector(
        participant: player,
        transport: rig.network.client(),
        address: hostAddress,
        wait: noWait,
      );
      expect(await loop.run(), ReconnectStop.refused);
      expect(player.refusal, isNotNull);
      expect(waits, isEmpty);
    });

    test('a malformed welcome drops the link and the retry joins', () async {
      rig = await Rig.create();
      await rig.start();
      var broken = true;
      rig.network.filter = (toHost, frame) {
        if (toHost || !broken || !frame.contains('"type":"welcome"')) {
          return [frame];
        }
        broken = false;
        return [frame.replaceFirst('"settings"', '"nosettings"')];
      };
      final client = _TestClient(rig.network.client());
      final player = ann();
      final loop = Reconnector(
        participant: player,
        transport: client,
        address: hostAddress,
        wait: noWait,
      );
      final running = loop.run();
      await pumpEventQueue();

      expect(client.links, hasLength(2));
      expect(player.joined, isTrue);
      expect(player.lastSeq, 1);
      // The failed handshake counts as a failure, so the wait is the first.
      expect(waits, [const Backoff().initial]);
      expect(annLog.entries.map((e) => e.kind), contains('hello.malformed'));
      loop.stop();
      await running;
    });

    test('a malformed refusal is not a join and is retried', () async {
      rig = await Rig.create();
      var broken = true;
      rig.network.filter = (toHost, frame) {
        if (toHost || !broken || !frame.contains('"type":"refused"')) {
          return [frame];
        }
        broken = false;
        return [frame.replaceFirst('"reason"', '"noreason"')];
      };
      final player = EpisodeParticipant(
        episodeId: 'op1',
        agentId: 'mallory',
        aliasId: 'hall',
        engine: Engine(testPack()),
        codec: Rig.codec,
        authProof: 'nobody',
        diagnostics: annLog,
      );
      rig.participants.add(player);
      final loop = Reconnector(
        participant: player,
        transport: rig.network.client(),
        address: hostAddress,
        wait: noWait,
      );
      expect(await loop.run(), ReconnectStop.refused);
      expect(waits, [const Backoff().initial]);
      expect(
        annLog.entries.map((e) => e.kind),
        containsAllInOrder(['hello.malformed', 'hello.refused']),
      );
    });
  });

  group('Liveness', () {
    tearDown(() => rig.close());

    const fast = Liveness(
      interval: Duration(milliseconds: 10),
      timeout: Duration(milliseconds: 40),
    );

    test('a silent host is dropped by the participant', () async {
      rig = await Rig.create();
      await rig.start();
      final player = ann(liveness: fast);
      await player.connect(await rig.network.client().connect(hostAddress));
      await pumpEventQueue();
      expect(player.joined, isTrue);

      rig.network.filter = (toHost, frame) => toHost ? [frame] : [];
      expect(await player.linkDone.timeout(const Duration(seconds: 2)), true);
      expect(player.joined, isFalse);
      expect(annLog.entries.map((e) => e.kind), contains('link.timeout'));
    });

    test('pings keep a quiet but live link open', () async {
      rig = await Rig.create();
      await rig.start();
      // A wide timeout, so a loaded machine cannot fail the test.
      final player = ann(
        liveness: const Liveness(
          interval: Duration(milliseconds: 10),
          timeout: Duration(milliseconds: 120),
        ),
      );
      await player.connect(await rig.network.client().connect(hostAddress));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(player.joined, isTrue);
      expect(
        annLog.entries.map((e) => e.kind),
        isNot(contains('link.timeout')),
      );
    });

    test('the host drops a participant that stops answering', () async {
      rig = await Rig.create();
      await rig.start();
      const live = Address('live');
      rig.host.listen(rig.network.host(live), liveness: fast);
      final player = ann();
      await player.connect(await rig.network.client().connect(live));
      await pumpEventQueue();
      expect(player.joined, isTrue);

      rig.network.filter = (toHost, frame) => toHost ? [] : [frame];
      expect(await player.linkDone.timeout(const Duration(seconds: 2)), true);
      expect(rig.hostLog.entries.map((e) => e.kind), contains('link.timeout'));
    });
  });
}
