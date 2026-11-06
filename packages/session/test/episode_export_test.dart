import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/rig.dart';
import 'support/test_codec.dart';
import 'support/test_pack.dart';

StoredEvent _event(int seq) => StoredEvent(
  seq: seq,
  time: DateTime.utc(2026, 11, 5, 12, 0, seq),
  engineVersion: '0.1.0',
  event: {'type': 'noted', 'n': seq},
  agentId: seq == 2 ? 'ann' : null,
  requestId: seq == 2 ? 'r1' : null,
);

TextLogLine _line(int seq) => TextLogLine(
  seq: seq,
  time: DateTime.utc(2026, 11, 5, 12, 0, seq),
  variants: {'gm': 'line $seq', 'public': 'seen $seq'},
);

Future<InMemoryEventStore> _filled() async {
  final store = InMemoryEventStore();
  await store.append(
    'e1',
    [_event(1), _event(2), _event(3)],
    [_line(1), _line(2), _line(3)],
    const HeadSnapshot(
      seq: 3,
      state: {'x': 1},
      rngDrawCount: 7,
      nextEntityNumber: 4,
    ),
  );
  await store.saveRngDrawCount('e1', 11);
  return store;
}

void main() {
  group('export and import', () {
    test('round-trips log, text, head and draw count through a file', () async {
      final export = await exportEpisode(await _filled(), 'e1');
      final file = export.encode();
      final target = InMemoryEventStore();
      await importEpisode(target, EpisodeExport.decode(file));

      final events = await target.read('e1').toList();
      expect([for (final e in events) e.seq], [1, 2, 3]);
      expect(events[1].agentId, 'ann');
      expect(events[1].requestId, 'r1');
      expect(events[0].time, DateTime.utc(2026, 11, 5, 12, 0, 1));
      expect(events[2].event, {'type': 'noted', 'n': 3});
      final text = await target.readText('e1').toList();
      expect(text[1].variants, {'gm': 'line 2', 'public': 'seen 2'});
      final head = (await target.headSnapshot('e1'))!;
      expect(head.seq, 3);
      expect(head.state, {'x': 1});
      expect(head.nextEntityNumber, 4);
      expect(await target.rngDrawCount('e1'), 11);
    });

    test('can import under another episode id', () async {
      final export = await exportEpisode(await _filled(), 'e1');
      final target = InMemoryEventStore();
      await importEpisode(target, export, asEpisodeId: 'copy');
      expect(await target.read('copy').length, 3);
      expect(await target.headSnapshot('e1'), isNull);
    });

    test('refuses to import over an episode that has a log', () async {
      final export = await exportEpisode(await _filled(), 'e1');
      await expectLater(
        importEpisode(await _filled(), export),
        throwsStateError,
      );
    });

    test('exporting an empty episode is an error', () async {
      await expectLater(
        exportEpisode(InMemoryEventStore(), 'none'),
        throwsStateError,
      );
    });

    test('decode rejects what is not a valid export', () async {
      final good = jsonDecode(
        (await exportEpisode(await _filled(), 'e1')).encode(),
      ) as Map<String, Object?>;
      String with_(void Function(Map<String, Object?>) edit) {
        final copy = jsonDecode(jsonEncode(good)) as Map<String, Object?>;
        edit(copy);
        return jsonEncode(copy);
      }

      expect(() => EpisodeExport.decode('nope'), throwsFormatException);
      expect(() => EpisodeExport.decode('{}'), throwsFormatException);
      expect(
        () => EpisodeExport.decode(with_((m) => m['formatVersion'] = 2)),
        throwsFormatException,
      );
      expect(
        () => EpisodeExport.decode(
          with_((m) => (m['events']! as List).removeAt(1)),
        ),
        throwsFormatException,
        reason: 'a gap in seq',
      );
      expect(
        () =>
            EpisodeExport.decode(with_((m) => (m['head']! as Map)['seq'] = 2)),
        throwsFormatException,
        reason: 'snapshot behind the log',
      );
      expect(
        () => EpisodeExport.decode(with_((m) => m.remove('head'))),
        throwsFormatException,
      );
    });

    test('a host resumes play from an imported export', () async {
      final rig = await Rig.create();
      await rig.start();
      await rig.host.submit(rig.agent('One'));
      await rig.host.submit(rig.agent('Two'));
      final state = rig.host.state;
      final lastSeq = rig.host.lastSeq;
      final file = (await exportEpisode(rig.store, 'op1')).encode();
      await rig.close();

      final fresh = InMemoryEventStore();
      await importEpisode(fresh, EpisodeExport.decode(file));
      final resumed = await EpisodeHost.open(
        episodeId: 'op1',
        gm: gmIdentity,
        engine: Engine(testPack()),
        codec: const TestCodec(),
        store: fresh,
        verifier: TableVerifier({}),
        rngFactory: CountingRng.new,
      );
      expect(resumed.state, state);
      expect(resumed.lastSeq, lastSeq);
      await resumed.submit(rig.agent('Three'));
      expect(resumed.lastSeq, lastSeq + 1);
      await resumed.close();
    });
  });
}
