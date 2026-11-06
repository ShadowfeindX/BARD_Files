import 'dart:async';

import 'package:session/session.dart';
import 'package:test/test.dart';

StoredEvent _event(int seq) => StoredEvent(
  seq: seq,
  time: DateTime.utc(2026, 11, 5, 12, 0, seq),
  engineVersion: '0.1.0',
  event: {'type': 'noted', 'n': seq},
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
  variants: {'gm': 'line $seq'},
);

typedef _Mirrored = (String, int, HeadMirrorReason);

void main() {
  group('StoreActor', () {
    late InMemoryEventStore inner;
    late FakeClock clock;
    late List<_Mirrored> mirrored;

    StoreActor actor({
      Duration interval = const Duration(minutes: 5),
      bool failMirror = false,
    }) => StoreActor(
      store: inner,
      clock: clock,
      snapshotInterval: interval,
      mirror: (id, head, reason) async {
        if (failMirror) throw StateError('relay down');
        mirrored.add((id, head.seq, reason));
      },
    );

    setUp(() {
      inner = InMemoryEventStore();
      clock = FakeClock();
      mirrored = [];
    });

    test('passes appends and reads through, in order', () async {
      final store = actor();
      await Future.wait([
        store.append('e', [_event(1), _event(2)], [_line(1)], _head(2)),
        store.append('e', [_event(3)], [_line(3)], _head(3, draws: 4)),
      ]);
      expect(
        [for (final e in await store.read('e').toList()) e.seq],
        [1, 2, 3],
      );
      expect(
        [for (final l in await store.readText('e', fromSeq: 2).toList()) l.seq],
        [3],
      );
      expect((await store.headSnapshot('e'))!.seq, 3);
      expect(await store.rngDrawCount('e'), 4);
      await store.saveRngDrawCount('e', 9);
      expect(await store.rngDrawCount('e'), 9);
    });

    test('a failed append stays failed and later calls still run', () async {
      final store = actor();
      await expectLater(
        store.append('e', [_event(2)], [], _head(2)),
        throwsStateError,
      );
      await store.append('e', [_event(1)], [], _head(1));
      expect((await store.headSnapshot('e'))!.seq, 1);
    });

    test('mirrors the head once the interval has passed, not before', () async {
      final store = actor(interval: const Duration(minutes: 5));
      await store.append('e', [_event(1)], [], _head(1));
      clock.advance(const Duration(minutes: 4));
      await store.append('e', [_event(2)], [], _head(2));
      expect(mirrored, isEmpty);
      clock.advance(const Duration(minutes: 1));
      await store.append('e', [_event(3)], [], _head(3));
      expect(mirrored, [('e', 3, HeadMirrorReason.interval)]);
      // The interval restarts from the mirror.
      clock.advance(const Duration(minutes: 4));
      await store.append('e', [_event(4)], [], _head(4));
      expect(mirrored, hasLength(1));
    });

    test('the interval is the caller\'s: one second works too', () async {
      final store = actor(interval: const Duration(seconds: 1));
      await store.append('e', [_event(1)], [], _head(1));
      clock.advance(const Duration(seconds: 1));
      await store.append('e', [_event(2)], [], _head(2));
      expect(mirrored, hasLength(1));
    });

    test(
      'mirrorHead sends the stored head for pause, close, migration',
      () async {
        final store = actor();
        await store.mirrorHead('e', HeadMirrorReason.pause); // nothing stored
        expect(mirrored, isEmpty);
        await store.append('e', [_event(1)], [], _head(1));
        await store.mirrorHead('e', HeadMirrorReason.pause);
        await store.mirrorHead('e', HeadMirrorReason.close);
        await store.mirrorHead('e', HeadMirrorReason.preMigration);
        expect(mirrored.map((m) => m.$3), [
          HeadMirrorReason.pause,
          HeadMirrorReason.close,
          HeadMirrorReason.preMigration,
        ]);
      },
    );

    test('a failing mirror never fails a committed append', () async {
      final store = actor(
        interval: const Duration(seconds: 1),
        failMirror: true,
      );
      await store.append('e', [_event(1)], [], _head(1));
      clock.advance(const Duration(seconds: 2));
      await store.append('e', [_event(2)], [], _head(2));
      expect((await store.headSnapshot('e'))!.seq, 2);
      await expectLater(
        store.mirrorHead('e', HeadMirrorReason.close),
        throwsStateError,
      );
    });

    test('without a sink nothing is mirrored', () async {
      final store = StoreActor(
        store: inner,
        clock: clock,
        snapshotInterval: const Duration(seconds: 1),
      );
      await store.append('e', [_event(1)], [], _head(1));
      clock.advance(const Duration(minutes: 1));
      await store.append('e', [_event(2)], [], _head(2));
      await store.mirrorHead('e', HeadMirrorReason.close);
      expect(mirrored, isEmpty);
    });

    test('defaults to 5 minutes and can change while running', () async {
      final store = StoreActor(
        store: inner,
        clock: clock,
        mirror: (id, head, reason) async =>
            mirrored.add((id, head.seq, reason)),
      );
      expect(store.snapshotInterval, const Duration(minutes: 5));
      await store.append('e', [_event(1)], [], _head(1));
      store.snapshotInterval = const Duration(seconds: 30);
      clock.advance(const Duration(seconds: 30));
      await store.append('e', [_event(2)], [], _head(2));
      expect(mirrored, hasLength(1));
      expect(() => store.snapshotInterval = Duration.zero, throwsArgumentError);
      expect(store.snapshotInterval, const Duration(seconds: 30));
    });

    test('a non-positive interval is refused', () {
      expect(
        () => StoreActor(
          store: inner,
          clock: clock,
          snapshotInterval: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
