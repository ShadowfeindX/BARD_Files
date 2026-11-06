import 'dart:async';

import 'clock.dart';
import 'event_store.dart';
import 'mailbox.dart';

/// Why a head snapshot is being mirrored (S-5, 04 §The episode loop).
enum HeadMirrorReason {
  /// The snapshot interval has passed since the last mirror.
  interval,

  /// The Handler paused the episode.
  pause,

  /// The episode is closing.
  close,

  /// A major migration is about to read the head.
  preMigration,
}

/// Receives the head snapshot when it is due to leave the device, for
/// example the Realtime Database mirror. The relay supplies it; the store
/// actor only decides when.
typedef HeadMirrorSink = Future<void> Function(
  String episodeId,
  HeadSnapshot head,
  HeadMirrorReason reason,
);

/// The one door to a device's [EventStore] (04 §Coarse actors).
///
/// Every call runs in a private [Mailbox], so appends, reads and snapshot
/// work are strictly ordered with no locks. It also decides when the head
/// snapshot is mirrored: after an append once [snapshotInterval] has passed
/// since the last mirror (or since the first append, before any), and on demand with [mirrorHead] for pause, close
/// and migration. The head snapshot itself is written with every batch by the
/// store; the interval only paces the mirror.
///
/// The interval is a setting of the host machine (S-5, R 2026-11-05), so it
/// is passed in and may be changed while the actor runs.
final class StoreActor implements EventStore {
  /// Creates an actor over [store].
  ///
  /// With no [mirror] nothing is mirrored and [snapshotInterval] has no
  /// effect. [snapshotInterval] must be positive.
  StoreActor({
    required this._store,
    required this._clock,
    Duration snapshotInterval = defaultSnapshotInterval,
    this._mirror,
  }) : _snapshotInterval = _checkInterval(snapshotInterval);

  /// The default interval: 5 minutes (R, 2026-11-05). The interval is a
  /// per-machine host setting; the app reads it from the host's settings and
  /// passes it in, and may change it while an episode runs.
  static const Duration defaultSnapshotInterval = Duration(minutes: 5);

  final EventStore _store;
  final Clock _clock;
  final HeadMirrorSink? _mirror;
  final Mailbox _mailbox = Mailbox();
  final Map<String, DateTime> _lastMirrored = {};

  Duration _snapshotInterval;

  static Duration _checkInterval(Duration value) {
    if (value <= Duration.zero) {
      throw ArgumentError.value(value, 'snapshotInterval', 'must be positive');
    }
    return value;
  }

  /// How long after the last mirror an append triggers the next one.
  Duration get snapshotInterval => _snapshotInterval;

  /// Changes the interval; it applies from the next append.
  set snapshotInterval(Duration value) =>
      _snapshotInterval = _checkInterval(value);

  @override
  Future<void> append(
    String episodeId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  ) async {
    await _mailbox.run(() => _store.append(episodeId, events, text, head));
    // The batch is committed. The mirror runs outside the mailbox so a slow
    // sink never blocks other store calls. A failure must not make the caller
    // think the append failed, so it is retried on the next append. A sink
    // should still return quickly: this future waits for it.
    final now = _clock.now();
    final last = _lastMirrored.putIfAbsent(episodeId, () => now);
    if (_mirror != null && now.difference(last) >= _snapshotInterval) {
      try {
        await _mirror(episodeId, head, HeadMirrorReason.interval);
        _lastMirrored[episodeId] = now;
      } on Object {
        // Retried on the next append; the head is safe in the local store.
      }
    }
  }

  /// Mirrors the current head now, for [reason] (pause, close, migration).
  ///
  /// Does nothing when there is no sink or nothing is stored. A failing sink
  /// throws here: these moments are explicit and the caller must know.
  Future<void> mirrorHead(String episodeId, HeadMirrorReason reason) =>
      _mailbox.run(() async {
        final sink = _mirror;
        final head = await _store.headSnapshot(episodeId);
        if (sink == null || head == null) return;
        await sink(episodeId, head, reason);
        _lastMirrored[episodeId] = _clock.now();
      });

  @override
  Stream<StoredEvent> read(String episodeId, {int fromSeq = 1}) =>
      _stream(() => _store.read(episodeId, fromSeq: fromSeq));

  @override
  Stream<TextLogLine> readText(String episodeId, {int fromSeq = 1}) =>
      _stream(() => _store.readText(episodeId, fromSeq: fromSeq));

  @override
  Future<HeadSnapshot?> headSnapshot(String episodeId) =>
      _mailbox.run(() => _store.headSnapshot(episodeId));

  @override
  Future<void> saveRngDrawCount(String episodeId, int drawCount) =>
      _mailbox.run(() => _store.saveRngDrawCount(episodeId, drawCount));

  @override
  Future<int> rngDrawCount(String episodeId) =>
      _mailbox.run(() => _store.rngDrawCount(episodeId));

  /// Reads in the mailbox's order, so a read queued after an append sees it,
  /// and hands the items out as a stream.
  Stream<T> _stream<T>(Stream<T> Function() open) =>
      Stream.fromFuture(_mailbox.run(() => open().toList()))
          .expand((items) => items);
}
