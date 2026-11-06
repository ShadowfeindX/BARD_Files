import 'dart:io';

import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:session/session.dart';

StoredEvent _event(int seq) => StoredEvent(
  seq: seq,
  time: DateTime.utc(2026, 11, 5, 12, 0, seq),
  engineVersion: '0.1.0',
  event: {
    'type': 'noted',
    'n': seq,
    'nested': {
      'list': [1, 2, 3],
    },
  },
  agentId: 'ann',
  requestId: 'r$seq',
);

HeadSnapshot _head(int seq, {int draws = 0}) => HeadSnapshot(
  seq: seq,
  state: {'seq': seq},
  rngDrawCount: draws,
  nextEntityNumber: seq + 1,
);

TextLogLine _line(int seq) => TextLogLine(
  seq: seq,
  time: DateTime.utc(2026, 11, 5, 12, 0, seq),
  variants: {'gm': 'line $seq', 'alias:hall': 'seen $seq'},
);

void main() {
  late Directory dir;
  late SembastEventStore store;

  SembastEventStore open() =>
      SembastEventStore.inDirectory(databaseFactoryIo, dir.path);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bard_event_store_');
    store = open();
  });

  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });

  group('SembastEventStore', () {
    test('an unknown episode is empty', () async {
      expect(await store.read('e1').toList(), isEmpty);
      expect(await store.readText('e1').toList(), isEmpty);
      expect(await store.headSnapshot('e1'), isNull);
      expect(await store.rngDrawCount('e1'), 0);
    });

    test('appends and reads back every field', () async {
      await store.append(
        'e1',
        [_event(1), _event(2)],
        [_line(1), _line(2)],
        _head(2, draws: 5),
      );
      await store.append('e1', [_event(3)], [_line(3)], _head(3, draws: 6));

      final events = await store.read('e1').toList();
      expect([for (final e in events) e.seq], [1, 2, 3]);
      expect(events[0].time, DateTime.utc(2026, 11, 5, 12, 0, 1));
      expect(events[0].engineVersion, '0.1.0');
      expect(events[0].agentId, 'ann');
      expect(events[0].requestId, 'r1');
      expect(events[0].event['nested'], {
        'list': [1, 2, 3],
      });
      final text = await store.readText('e1').toList();
      expect(text[2].variants, {'gm': 'line 3', 'alias:hall': 'seen 3'});
      final head = (await store.headSnapshot('e1'))!;
      expect(head.seq, 3);
      expect(head.state, {'seq': 3});
      expect(head.nextEntityNumber, 4);
      expect(await store.rngDrawCount('e1'), 6);
    });

    test('reads from a seq on', () async {
      await store.append(
        'e1',
        [_event(1), _event(2), _event(3)],
        [_line(1), _line(2), _line(3)],
        _head(3),
      );
      expect(
        [for (final e in await store.read('e1', fromSeq: 2).toList()) e.seq],
        [2, 3],
      );
      expect(
        [
          for (final l in await store.readText('e1', fromSeq: 3).toList())
            l.seq,
        ],
        [3],
      );
      expect(await store.read('e1', fromSeq: 4).toList(), isEmpty);
    });

    test('episodes are separate files', () async {
      await store.append('a', [_event(1)], [], _head(1));
      await store.append('b', [_event(1), _event(2)], [], _head(2));
      expect(await store.read('a').length, 1);
      expect(await store.read('b').length, 2);
      expect(File('${dir.path}/a.db').existsSync(), isTrue);
      expect(File('${dir.path}/b.db').existsSync(), isTrue);
    });

    test('refuses a gap, a repeat and a mismatched head', () async {
      await store.append('e1', [_event(1)], [], _head(1));
      await expectLater(
        store.append('e1', [_event(3)], [], _head(3)),
        throwsStateError,
      );
      await expectLater(
        store.append('e1', [_event(1)], [], _head(1)),
        throwsStateError,
      );
      await expectLater(
        store.append('e1', [_event(2)], [], _head(1)),
        throwsStateError,
      );
      await expectLater(
        store.append('e1', [_event(2)], [_line(5)], _head(2)),
        throwsStateError,
      );
      await expectLater(
        store.append('e1', [], [], _head(1)),
        throwsArgumentError,
      );
      // None of the refusals left anything behind.
      expect(await store.read('e1').length, 1);
      expect((await store.headSnapshot('e1'))!.seq, 1);
      await store.append('e1', [_event(2)], [], _head(2));
      expect((await store.headSnapshot('e1'))!.seq, 2);
    });

    test('refuses repeated or unordered text lines', () async {
      await expectLater(
        store.append(
          'e1',
          [_event(1), _event(2)],
          [_line(2), _line(2)],
          _head(2),
        ),
        throwsStateError,
      );
      await expectLater(
        store.append(
          'e1',
          [_event(1), _event(2)],
          [_line(2), _line(1)],
          _head(2),
        ),
        throwsStateError,
      );
      expect(await store.read('e1').toList(), isEmpty);
    });

    test('a failed open closes its database', () async {
      final path = '${dir.path}/bad.db';
      final bad = SembastEventStore((id) async {
        final db = await databaseFactoryIo.openDatabase(path, version: 1);
        await stringMapStoreFactory
            .store(SembastEventStore.metaStoreName)
            .record('schema')
            .put(db, {'version': 99});
        return db;
      });
      await expectLater(bad.read('e1').toList(), throwsStateError);
      // sembast keeps an open path cached and ignores a new version for it;
      // only a closed database runs the version change.
      var versionChanges = 0;
      final again = await databaseFactoryIo.openDatabase(
        path,
        version: 2,
        onVersionChanged: (db, oldVersion, newVersion) => versionChanges++,
      );
      expect(versionChanges, 1);
      await again.close();
    });

    test('close() waits for queued appends', () async {
      final pending = store.append('e1', [_event(1)], [_line(1)], _head(1));
      await store.close();
      await pending;
      store = open();
      expect(await store.read('e1').length, 1);
    });

    test('concurrent appends are applied in call order', () async {
      await Future.wait([
        for (var i = 1; i <= 20; i++)
          store.append('e1', [_event(i)], [], _head(i)),
      ]);
      expect(
        [for (final e in await store.read('e1').toList()) e.seq],
        [for (var i = 1; i <= 20; i++) i],
      );
    });

    test('the draw count only goes up', () async {
      await store.saveRngDrawCount('e1', 8);
      await store.saveRngDrawCount('e1', 3);
      expect(await store.rngDrawCount('e1'), 8);
      await store.append('e1', [_event(1)], [], _head(1, draws: 2));
      expect(await store.rngDrawCount('e1'), 8);
      await store.append('e1', [_event(2)], [], _head(2, draws: 9));
      expect(await store.rngDrawCount('e1'), 9);
    });

    test('everything survives closing and reopening the file', () async {
      await store.append(
        'e1',
        [_event(1), _event(2)],
        [_line(1)],
        _head(2, draws: 4),
      );
      await store.close();
      store = open();
      expect(await store.read('e1').length, 2);
      expect((await store.headSnapshot('e1'))!.seq, 2);
      expect(await store.rngDrawCount('e1'), 4);
      await store.append('e1', [_event(3)], [_line(3)], _head(3));
      expect(await store.read('e1').length, 3);
    });

    test('episode ids cannot name a path', () async {
      for (final bad in ['../x', 'a/b', r'a\b', '', 'a.b']) {
        await expectLater(store.read(bad).toList(), throwsArgumentError);
      }
    });

    test('a failed open is not cached', () async {
      var fail = true;
      final flaky = SembastEventStore((id) async {
        if (fail) throw StateError('disk busy');
        return newDatabaseFactoryMemory().openDatabase(id);
      });
      await expectLater(flaky.read('e1').toList(), throwsStateError);
      fail = false;
      expect(await flaky.read('e1').toList(), isEmpty);
      await flaky.close();
    });
  });

  group('crash recovery (V-31)', () {
    /// Writes a batch the way `append` does, then stops before the commit
    /// marker: what a hard kill between the two transactions leaves.
    Future<void> tornBatch(int seq) async {
      final db = await databaseFactoryIo.openDatabase('${dir.path}/e1.db');
      final events = intMapStoreFactory.store(
        SembastEventStore.eventsStoreName,
      );
      final text = intMapStoreFactory.store(SembastEventStore.textStoreName);
      final heads = intMapStoreFactory.store(SembastEventStore.headsStoreName);
      await db.transaction((txn) async {
        await events.record(seq).put(txn, _event(seq).toJson());
        await text.record(seq).put(txn, _line(seq).toJson());
        await heads.record(seq).put(txn, _head(seq).toJson());
      });
      await db.close();
    }

    test('an uncommitted batch is discarded when the episode opens', () async {
      await store.append(
        'e1',
        [_event(1), _event(2)],
        [_line(1), _line(2)],
        _head(2),
      );
      await store.close();
      await tornBatch(3);

      store = open();
      expect([for (final e in await store.read('e1').toList()) e.seq], [1, 2]);
      expect(
        [for (final l in await store.readText('e1').toList()) l.seq],
        [1, 2],
      );
      expect(
        (await store.headSnapshot('e1'))!.seq,
        2,
        reason: 'head rolled back',
      );
      // The next batch continues from the last commit, not the torn one.
      await store.append('e1', [_event(3)], [_line(3)], _head(3));
      expect(await store.read('e1').length, 3);
      expect((await store.headSnapshot('e1'))!.state, {'seq': 3});
    });

    test('a torn first batch leaves an empty episode', () async {
      await tornBatch(1);
      expect(await store.read('e1').toList(), isEmpty);
      expect(await store.headSnapshot('e1'), isNull);
      await store.append('e1', [_event(1)], [], _head(1));
      expect((await store.headSnapshot('e1'))!.seq, 1);
    });

    test('a layout newer than this build is refused', () async {
      final db = await databaseFactoryIo.openDatabase('${dir.path}/e1.db');
      await stringMapStoreFactory
          .store(SembastEventStore.metaStoreName)
          .record('schema')
          .put(db, {'version': SembastEventStore.schemaVersion + 1});
      await db.close();
      await expectLater(store.read('e1').toList(), throwsStateError);
    });
  });

  group('export and resume on sembast', () {
    test('a log exported from one file resumes in another', () async {
      await store.append(
        'e1',
        [_event(1), _event(2)],
        [_line(1), _line(2)],
        _head(2, draws: 3),
      );
      final file = (await exportEpisode(store, 'e1')).encode();

      final other = Directory.systemTemp.createTempSync('bard_import_');
      final target = SembastEventStore.inDirectory(
        databaseFactoryIo,
        other.path,
      );
      addTearDown(() async {
        await target.close();
        other.deleteSync(recursive: true);
      });
      await importEpisode(target, EpisodeExport.decode(file));
      expect(await target.read('e1').length, 2);
      expect((await target.headSnapshot('e1'))!.rngDrawCount, 3);
      expect(await target.rngDrawCount('e1'), 3);
      // Play continues from the imported head.
      await target.append('e1', [_event(3)], [_line(3)], _head(3));
      expect(await target.read('e1').length, 3);
    });
  });

  group('health', () {
    test(
      'reports the marker, counts, size and what recovery discarded',
      () async {
        Future<int?> size(String p) async => File(p).length();
        store = SembastEventStore.inDirectory(
          databaseFactoryIo,
          dir.path,
          sizeOf: size,
        );
        await store.append('e1', [_event(1), _event(2)], [_line(2)], _head(2));
        var h = await store.health('e1');
        expect(h.lastSeq, 2);
        expect(h.eventCount, 2);
        expect(h.textLineCount, 1);
        expect(h.eventsDiscardedAtOpen, 0);
        expect(h.fileBytes, greaterThan(0));
        expect(h.toJson()['lastSeq'], 2);
        await store.close();

        // A batch interrupted before its marker is counted when the file opens.
        final db = await databaseFactoryIo.openDatabase('${dir.path}/e1.db');
        await intMapStoreFactory
            .store(SembastEventStore.eventsStoreName)
            .record(3)
            .put(db, _event(3).toJson());
        await db.close();
        store = SembastEventStore.inDirectory(databaseFactoryIo, dir.path);
        h = await store.health('e1');
        expect(h.eventCount, 2);
        expect(h.eventsDiscardedAtOpen, 1);
        expect(h.fileBytes, isNull, reason: 'no size reader given');
        expect((await store.health('empty')).lastSeq, 0);
      },
    );
  });

  group('HostSettingsStore', () {
    test('defaults to 5 minutes, saves, and resets', () async {
      final db = await databaseFactoryIo.openDatabase('${dir.path}/host.db');
      final settings = HostSettingsStore(db);
      expect(await settings.snapshotInterval(), const Duration(minutes: 5));
      await settings.setSnapshotInterval(const Duration(seconds: 90));
      await db.close();
      final again = HostSettingsStore(
        await databaseFactoryIo.openDatabase('${dir.path}/host.db'),
      );
      expect(await again.snapshotInterval(), const Duration(seconds: 90));
      await expectLater(
        again.setSnapshotInterval(Duration.zero),
        throwsArgumentError,
      );
      await again.resetSnapshotInterval();
      expect(await again.snapshotInterval(), const Duration(minutes: 5));
    });
  });

  group('torn commits (V-31)', () {
    Future<Database> raw() =>
        databaseFactoryIo.openDatabase('${dir.path}/e1.db');
    final events = intMapStoreFactory.store(SembastEventStore.eventsStoreName);
    final text = intMapStoreFactory.store(SembastEventStore.textStoreName);
    final heads = intMapStoreFactory.store(SembastEventStore.headsStoreName);
    final meta = stringMapStoreFactory.store(SembastEventStore.metaStoreName);

    test('stale older heads left behind do not hide the live head', () async {
      await store.append('e1', [_event(1)], [_line(1)], _head(1));
      await store.close();
      // The kill came after the marker but before the old head was removed.
      final db = await raw();
      await heads.record(0).put(db, _head(0).toJson());
      await events.record(2).put(db, _event(2).toJson());
      await text.record(2).put(db, _line(2).toJson());
      await heads.record(2).put(db, _head(2).toJson());
      await meta.record('marker').put(db, {'seq': 2});
      await db.close();

      store = open();
      expect((await store.headSnapshot('e1'))!.seq, 2);
      await store.append('e1', [_event(3)], [], _head(3));
      await store.close();
      final check = await raw();
      expect(await heads.count(check), 1, reason: 'stale heads cleaned up');
      await check.close();
    });

    test(
      'a marker commit torn before the draw count keeps the log and the draws',
      () async {
        await store.append('e1', [_event(1)], [], _head(1, draws: 2));
        await store.close();
        final db = await raw();
        await events.record(2).put(db, _event(2).toJson());
        await heads.record(2).put(db, _head(2, draws: 9).toJson());
        await meta.record('marker').put(db, {
          'seq': 2,
        }); // draw count not raised
        await db.close();

        store = open();
        expect(await store.read('e1').length, 2);
        expect((await store.headSnapshot('e1'))!.seq, 2);
        // The saved count lags, so the head's own count is used.
        expect(await store.rngDrawCount('e1'), 9);
      },
    );

    test('a missing head at the marker is reported as damage', () async {
      await store.append('e1', [_event(1)], [], _head(1));
      await store.close();
      final db = await raw();
      await heads.delete(db);
      await db.close();
      store = open();
      await expectLater(store.headSnapshot('e1'), throwsStateError);
    });
  });
}
