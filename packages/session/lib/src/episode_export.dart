import 'dart:convert';

import 'package:protocol/protocol.dart';

import 'event_store.dart';

/// An episode's local log in one piece: every event, every text line and the
/// latest head snapshot (10 §5, "Local log export and resume from export").
///
/// It is the content of one export file. Another device [importEpisode]s it
/// into an empty [EventStore] and opens the episode from there, so play
/// resumes where the export was taken. What else a "save a report" bundle
/// carries beyond log and snapshot is R's call and is not part of this type.
final class EpisodeExport {
  /// Creates an export. Prefer [exportEpisode], which reads a store.
  const EpisodeExport({
    required this.episodeId,
    required this.events,
    required this.text,
    required this.head,
    required this.rngDrawCount,
  });

  /// The `format` marker written into every export file.
  static const String formatName = 'bard-episode-export';

  /// The file layout version. Bumped only when the layout changes; an older
  /// reader refuses a newer file instead of guessing.
  static const int formatVersion = 1;

  /// The episode the log belongs to.
  final String episodeId;

  /// Every stored event, `seq` 1 to [head]`.seq`.
  final List<StoredEvent> events;

  /// The narrated lines, in increasing `seq` order. There is at most one per
  /// event and the list may be sparse; each `seq` is within the log.
  final List<TextLogLine> text;

  /// The state at the last event.
  final HeadSnapshot head;

  /// The largest RNG draw count the store had recorded.
  final int rngDrawCount;

  /// The export as a JSON document.
  JsonMap toJson() => {
    'format': formatName,
    'formatVersion': formatVersion,
    'episodeId': episodeId,
    'rngDrawCount': rngDrawCount,
    'head': head.toJson(),
    'events': [for (final e in events) e.toJson()],
    'text': [for (final l in text) l.toJson()],
  };

  /// The export as the text of an export file.
  String encode() => jsonEncode(toJson());

  /// Reads an export file's text.
  ///
  /// Throws [FormatException] when the text is not an episode export, is of a
  /// newer layout than this build reads, or its log is not a gap-free
  /// sequence ending at the snapshot's `seq`.
  factory EpisodeExport.decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Not an episode export: ${e.message}');
    }
    if (root is! Map || root['format'] != formatName) {
      throw const FormatException('Not an episode export.');
    }
    final version = root['formatVersion'];
    if (version is! int || version < 1 || version > formatVersion) {
      throw FormatException(
        'Unsupported export layout version $version (this build reads up to '
        '$formatVersion).',
      );
    }
    try {
      final export = EpisodeExport(
        episodeId: root['episodeId']! as String,
        rngDrawCount: root['rngDrawCount']! as int,
        head: HeadSnapshot.fromJson(
          Map<String, Object?>.from(root['head']! as Map),
        ),
        events: [
          for (final e in root['events']! as List)
            StoredEvent.fromJson(Map<String, Object?>.from(e as Map)),
        ],
        text: [
          for (final l in root['text']! as List)
            TextLogLine.fromJson(Map<String, Object?>.from(l as Map)),
        ],
      );
      export.validate();
      return export;
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Malformed episode export: $e');
    }
  }

  /// Throws [FormatException] unless the log runs 1 to [head]`.seq` with no
  /// gap and every text line lies inside it, in order.
  void validate() {
    var expected = 1;
    for (final event in events) {
      if (event.seq != expected) {
        throw FormatException(
          'Event log has seq ${event.seq} where $expected was expected.',
        );
      }
      expected++;
    }
    final last = events.length;
    if (last == 0) {
      throw const FormatException('The export holds no events.');
    }
    if (head.seq != last) {
      throw FormatException(
        'Snapshot is at seq ${head.seq} but the log ends at $last.',
      );
    }
    var previous = 0;
    for (final line in text) {
      if (line.seq < 1 || line.seq > last || line.seq <= previous) {
        throw FormatException(
          'Text line seq ${line.seq} is out of order or outside the log.',
        );
      }
      previous = line.seq;
    }
  }
}

/// Reads [episodeId] out of [store] as one [EpisodeExport].
///
/// Throws [StateError] when the store holds nothing for the episode.
Future<EpisodeExport> exportEpisode(EventStore store, String episodeId) async {
  final head = await store.headSnapshot(episodeId);
  if (head == null) {
    throw StateError('Nothing is stored for episode $episodeId.');
  }
  // Read to the head's seq only, so a batch committed while the export runs
  // cannot leave the log ahead of the snapshot.
  final events = [
    await for (final e in store.read(episodeId))
      if (e.seq <= head.seq) e,
  ];
  final text = [
    await for (final l in store.readText(episodeId))
      if (l.seq <= head.seq) l,
  ];
  return EpisodeExport(
    episodeId: episodeId,
    events: events,
    text: text,
    head: head,
    rngDrawCount: await store.rngDrawCount(episodeId),
  );
}

/// Writes [export] into [store] so the episode can be opened from it.
///
/// The target is [asEpisodeId], or the export's own id. It must be empty:
/// importing never merges into, or overwrites, an episode that has a log.
/// The log goes in as one batch, so the store's own atomicity applies, and
/// the RNG draw count is restored after it.
///
/// Throws [StateError] when the target already holds events or a snapshot,
/// [FormatException] when [export] is not a valid log, and [ArgumentError]
/// when the store refuses the episode id. The emptiness check and the write
/// are not one atomic step: import assumes a single writer, which holds while
/// the episode is closed.
Future<void> importEpisode(
  EventStore store,
  EpisodeExport export, {
  String? asEpisodeId,
}) async {
  export.validate();
  final target = asEpisodeId ?? export.episodeId;
  if (await store.headSnapshot(target) != null ||
      await store.read(target).isEmpty == false) {
    throw StateError(
      'Episode $target already has a stored log; import needs an empty one.',
    );
  }
  await store.append(target, export.events, export.text, export.head);
  await store.saveRngDrawCount(target, export.rngDrawCount);
}
