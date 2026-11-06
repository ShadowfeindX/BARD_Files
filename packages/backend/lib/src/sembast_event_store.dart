import 'dart:async' show unawaited;

import 'package:session/session.dart';
import 'package:sembast/sembast.dart';

/// Opens (creating if needed) the database that holds one episode.
typedef EpisodeDatabaseOpener = Future<Database> Function(String episodeId);

/// How an episode's file is doing, for diagnostics and the saved report.
final class StoreHealth {
  /// Creates a health reading.
  const StoreHealth({
    required this.episodeId,
    required this.lastSeq,
    required this.eventCount,
    required this.textLineCount,
    required this.eventsDiscardedAtOpen,
    this.fileBytes,
  });

  /// The episode.
  final String episodeId;

  /// The commit marker: the last `seq` committed; 0 for an empty episode.
  final int lastSeq;

  /// Committed events in the file. Equals [lastSeq] unless the file is damaged.
  final int eventCount;

  /// Committed narrated lines in the file.
  final int textLineCount;

  /// Events found past the marker and deleted when the episode was opened
  /// (a batch interrupted by a crash); 0 after a clean open.
  final int eventsDiscardedAtOpen;

  /// Size of the database file, or null when the store was built without a
  /// size reader (see [SembastEventStore.new]).
  final int? fileBytes;

  /// The reading as JSON, for the report.
  Map<String, Object?> toJson() => {
    'episodeId': episodeId,
    'lastSeq': lastSeq,
    'eventCount': eventCount,
    'textLineCount': textLineCount,
    'eventsDiscardedAtOpen': eventsDiscardedAtOpen,
    if (fileBytes != null) 'fileBytes': fileBytes,
  };
}

/// Reads the size in bytes of the file at a path, or null when unknown.
typedef FileSizeReader = Future<int?> Function(String path);

/// [EventStore] on `sembast` 3.9.0: one database file per episode, opened on
/// demand (04 §Persistence).
///
/// **Durability.** A sembast transaction is not crash-atomic: a hard kill can
/// leave a batch's events on disk without its head [V-31]. So [append] writes
/// events, text lines and the new head in one transaction and then a commit
/// marker `{seq}` in a second one. When an episode is first opened, everything
/// after the marker is deleted, which is always safe because state is a fold
/// of the log. Readers never see past the marker. There is no power-loss or
/// OS-crash protection in v1: sembast calls no fsync [V-31].
///
/// **Layout** (schema version 1), the `int` keys being `seq`:
/// - `events`: `seq` -> [StoredEvent] JSON
/// - `text`: `seq` -> [TextLogLine] JSON
/// - `heads`: `seq` -> [HeadSnapshot] JSON; only the one at the marker is
///   live, older ones are removed with the marker, newer ones on open
/// - `meta`: `marker` -> `{seq}`, `rng` -> `{count}`, `schema` -> `{version}`
///
/// The class never touches the file system itself: the [EpisodeDatabaseOpener]
/// decides where databases live, so the same store runs on a `DatabaseFactory`
/// for files, memory or (later) the web.
final class SembastEventStore implements EventStore {
  /// Creates a store whose databases come from [open].
  ///
  /// [sizeOf] lets [health] report the file size; the store does not touch
  /// the file system itself, so desktop apps pass a reader built on `dart:io`.
  SembastEventStore(EpisodeDatabaseOpener open, {this._sizeOf}) : _open = open;

  /// Creates a store with one `<episodeId>.db` file in [directory], using
  /// [factory] (`databaseFactoryIo` on desktop).
  ///
  /// Episode ids may hold only letters, digits, `_` and `-`, so an id can
  /// never name a path.
  factory SembastEventStore.inDirectory(
    DatabaseFactory factory,
    String directory, {
    FileSizeReader? sizeOf,
  }) {
    final dir = directory.endsWith('/') || directory.endsWith(r'\')
        ? directory.substring(0, directory.length - 1)
        : directory;
    return SembastEventStore((episodeId) {
      _checkEpisodeId(episodeId);
      return factory.openDatabase('$dir/$episodeId.db');
    }, sizeOf: sizeOf);
  }

  /// The layout version written to every database.
  static const int schemaVersion = 1;

  /// Store names, public so tests can build a torn batch by hand. Not for
  /// use by app code.
  static const String eventsStoreName = 'events';

  /// See [eventsStoreName].
  static const String textStoreName = 'text';

  /// See [eventsStoreName].
  static const String headsStoreName = 'heads';

  /// See [eventsStoreName].
  static const String metaStoreName = 'meta';

  static final _events = intMapStoreFactory.store(eventsStoreName);
  static final _text = intMapStoreFactory.store(textStoreName);
  static final _heads = intMapStoreFactory.store(headsStoreName);
  static final _meta = stringMapStoreFactory.store(metaStoreName);
  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final EpisodeDatabaseOpener _open;
  final FileSizeReader? _sizeOf;
  final Map<String, Future<_Episode>> _episodes = {};

  static void _checkEpisodeId(String episodeId) {
    if (!_idPattern.hasMatch(episodeId)) {
      throw ArgumentError.value(
        episodeId,
        'episodeId',
        'may hold only letters, digits, "_" and "-"',
      );
    }
  }

  Future<_Episode> _episode(String episodeId) {
    final known = _episodes[episodeId];
    if (known != null) return known;
    final opening = _openEpisode(episodeId);
    _episodes[episodeId] = opening;
    // A failed open must not stay cached, or the episode stays shut.
    unawaited(
      opening.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_episodes[episodeId], opening)) {
            _episodes.remove(episodeId);
          }
        },
      ),
    );
    return opening;
  }

  Future<_Episode> _openEpisode(String episodeId) async {
    final db = await _open(episodeId);
    try {
      return await _openAndRecover(db);
    } on Object {
      await db.close();
      rethrow;
    }
  }

  /// Rolls the database back to its commit marker (the recovery step of
  /// [V-31]) and returns the open episode.
  static Future<_Episode> _openAndRecover(Database db) async {
    var discarded = 0;
    final marker = await db.transaction((txn) async {
      final stored = await _meta.record('schema').get(txn);
      final version = stored?['version'] as int?;
      if (version != null && version > schemaVersion) {
        throw StateError(
          'Episode database has layout $version; this build reads up to '
          '$schemaVersion.',
        );
      }
      if (version == null) {
        await _meta.record('schema').put(txn, {'version': schemaVersion});
      }
      final seq = (await _meta.record('marker').get(txn))?['seq'] as int? ?? 0;
      final beyond = Finder(filter: Filter.greaterThan(Field.key, seq));
      discarded = await _events.count(
        txn,
        filter: Filter.greaterThan(Field.key, seq),
      );
      await _events.delete(txn, finder: beyond);
      await _text.delete(txn, finder: beyond);
      await _heads.delete(txn, finder: beyond);
      return seq;
    });
    return _Episode(db, marker, discarded);
  }

  @override
  Future<void> append(
    String episodeId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  ) async {
    if (events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'a batch needs an event');
    }
    final episode = await _episode(episodeId);
    return episode.mailbox.run(() async {
      var next = episode.marker + 1;
      for (final event in events) {
        if (event.seq != next++) {
          throw StateError(
            'Expected seq ${next - 1} but got ${event.seq}: a batch must '
            'continue the stored sequence.',
          );
        }
      }
      final last = events.last.seq;
      if (head.seq != last) {
        throw StateError(
          'Head snapshot is at seq ${head.seq} but the batch ends at $last.',
        );
      }
      var previousLine = episode.marker;
      for (final line in text) {
        if (line.seq <= previousLine || line.seq > last) {
          throw StateError(
            'Text line seq ${line.seq} is outside the batch '
            '(${episode.marker + 1} to $last) or not in strictly '
            'increasing order.',
          );
        }
        previousLine = line.seq;
      }
      final db = episode.db;
      await db.transaction((txn) async {
        for (final event in events) {
          await _events.record(event.seq).put(txn, event.toJson());
        }
        for (final line in text) {
          await _text.record(line.seq).put(txn, line.toJson());
        }
        await _heads.record(head.seq).put(txn, head.toJson());
      });
      // The commit: only now does the batch exist for readers and recovery.
      await db.transaction((txn) async {
        await _meta.record('marker').put(txn, {'seq': last});
        await _raiseRng(txn, head.rngDrawCount);
      });
      episode.marker = last;
      // Older heads go in a later transaction, never with the marker: a
      // transaction is not crash-atomic [V-31], so deleting the old head
      // beside the marker could lose it while the marker still points at it.
      // A kill before this line only leaves stale heads, which are harmless.
      await db.transaction((txn) async {
        await _heads.delete(
          txn,
          finder: Finder(filter: Filter.lessThan(Field.key, last)),
        );
      });
    });
  }

  static Future<void> _raiseRng(DatabaseClient txn, int count) async {
    final current = (await _meta.record('rng').get(txn))?['count'] as int? ?? 0;
    if (count > current) await _meta.record('rng').put(txn, {'count': count});
  }

  @override
  Stream<StoredEvent> read(String episodeId, {int fromSeq = 1}) async* {
    final episode = await _episode(episodeId);
    final rows = await _events.find(
      episode.db,
      finder: _range(fromSeq, episode.marker),
    );
    for (final row in rows) {
      yield StoredEvent.fromJson(row.value);
    }
  }

  @override
  Stream<TextLogLine> readText(String episodeId, {int fromSeq = 1}) async* {
    final episode = await _episode(episodeId);
    final rows = await _text.find(
      episode.db,
      finder: _range(fromSeq, episode.marker),
    );
    for (final row in rows) {
      yield TextLogLine.fromJson(row.value);
    }
  }

  /// Rows with key in [from] to [to] inclusive, in key order. Reading stops
  /// at the commit marker, so a batch in flight is never visible.
  static Finder _range(int from, int to) => Finder(
    filter: Filter.and([
      Filter.greaterThanOrEquals(Field.key, from),
      Filter.lessThanOrEquals(Field.key, to),
    ]),
    sortOrders: [SortOrder(Field.key)],
  );

  @override
  Future<HeadSnapshot?> headSnapshot(String episodeId) async {
    final episode = await _episode(episodeId);
    // In the mailbox so the marker and the head row are read between
    // appends, never across one.
    return episode.mailbox.run(() async {
      if (episode.marker == 0) return null;
      final row = await _heads.record(episode.marker).get(episode.db);
      if (row == null) {
        throw StateError(
          'Episode $episodeId has no head snapshot at its commit marker '
          '(${episode.marker}); the file is damaged.',
        );
      }
      return HeadSnapshot.fromJson(row);
    });
  }

  @override
  Future<void> saveRngDrawCount(String episodeId, int drawCount) async {
    final episode = await _episode(episodeId);
    return episode.mailbox.run(
      () => episode.db.transaction((txn) => _raiseRng(txn, drawCount)),
    );
  }

  @override
  Future<int> rngDrawCount(String episodeId) async {
    final episode = await _episode(episodeId);
    final row = await _meta.record('rng').get(episode.db);
    final saved = row?['count'] as int? ?? 0;
    // The head's own count too: a kill between the marker and the draw-count
    // write must never let a draw be handed out twice.
    final head = await headSnapshot(episodeId);
    final inHead = head?.rngDrawCount ?? 0;
    return inHead > saved ? inHead : saved;
  }

  /// Reads how [episodeId]'s file is doing. Opens (and so recovers) the
  /// episode if it is not open yet.
  Future<StoreHealth> health(String episodeId) async {
    final episode = await _episode(episodeId);
    return episode.mailbox.run(() async {
      final path = episode.db.path;
      return StoreHealth(
        episodeId: episodeId,
        lastSeq: episode.marker,
        eventCount: await _events.count(episode.db),
        textLineCount: await _text.count(episode.db),
        eventsDiscardedAtOpen: episode.discardedAtOpen,
        fileBytes: await _sizeOf?.call(path),
      );
    });
  }

  /// Closes every open episode database. The store can be used again; each
  /// episode is recovered afresh on its next use.
  Future<void> close() async {
    final open = _episodes.values.toList();
    _episodes.clear();
    for (final opening in open) {
      _Episode episode;
      try {
        episode = await opening;
      } on Object {
        continue; // never opened; its handle was closed on failure
      }
      // Let work already queued finish before the file closes.
      await episode.mailbox.run(episode.db.close);
    }
  }
}

/// One open episode database and the last committed `seq`.
final class _Episode {
  _Episode(this.db, this.marker, this.discardedAtOpen);

  /// Events deleted past the marker when this episode was opened.
  final int discardedAtOpen;

  final Database db;
  final Mailbox mailbox = Mailbox();

  /// The last `seq` whose commit marker is written; 0 for an empty episode.
  int marker;
}
