import 'package:protocol/protocol.dart';

/// One narrated log line (P12, 04 §Interfaces). Text is written at play time,
/// one variant per audience: `gm`, `public`, `redacted`, `alias:<id>`.
final class TextLogLine {
  /// Creates a line.
  const TextLogLine({
    required this.seq,
    required this.time,
    required this.variants,
  });

  /// The event this line narrates.
  final int seq;

  /// When it was written.
  final DateTime time;

  /// Text per audience key.
  final Map<String, String> variants;

  /// The line as JSON, for stores and exports. [time] is written in UTC.
  JsonMap toJson() => {
    'seq': seq,
    'time': time.toUtc().toIso8601String(),
    'variants': Map<String, String>.of(variants),
  };

  /// Reads a line written by [toJson].
  factory TextLogLine.fromJson(Map<String, Object?> json) => TextLogLine(
    seq: json['seq']! as int,
    time: DateTime.parse(json['time']! as String),
    variants: Map<String, String>.from(json['variants']! as Map),
  );
}

/// An event as stored: encoded by the engine codec, so a store never needs to
/// know engine types (sembast, RTDB and Firestore all hold JSON).
final class StoredEvent {
  /// Creates a stored event.
  const StoredEvent({
    required this.seq,
    required this.time,
    required this.engineVersion,
    required this.event,
    this.agentId,
    this.requestId,
  });

  /// GM-assigned sequence number, from 1.
  final int seq;

  /// When the GM host committed it.
  final DateTime time;

  /// Engine version that wrote it (the `e` rule 3 of version negotiation
  /// compares against).
  final String engineVersion;

  /// The encoded event.
  final JsonMap event;

  /// The agent whose request caused the event, if one did. With [requestId]
  /// it lets a reopened host recognise a retried request it already decided.
  final String? agentId;

  /// The request that caused the event.
  final String? requestId;

  /// The event as JSON, for stores and exports. [time] is written in UTC.
  JsonMap toJson() => {
    'seq': seq,
    'time': time.toUtc().toIso8601String(),
    'engineVersion': engineVersion,
    'event': event,
    if (agentId != null) 'agentId': agentId,
    if (requestId != null) 'requestId': requestId,
  };

  /// Reads an event written by [toJson].
  factory StoredEvent.fromJson(Map<String, Object?> json) => StoredEvent(
    seq: json['seq']! as int,
    time: DateTime.parse(json['time']! as String),
    engineVersion: json['engineVersion']! as String,
    event: Map<String, Object?>.from(json['event']! as Map),
    agentId: json['agentId'] as String?,
    requestId: json['requestId'] as String?,
  );
}

/// The state at [seq], written with every batch (P12).
final class HeadSnapshot {
  /// Creates a head snapshot.
  const HeadSnapshot({
    required this.seq,
    required this.state,
    required this.rngDrawCount,
    this.nextEntityNumber = 1,
  });

  /// Last `seq` folded into [state]; 0 before the first event.
  final int seq;

  /// The encoded state.
  final JsonMap state;

  /// How many RNG draws the host had made when it was written. Reopening
  /// positions the RNG at the larger of this and the state's own count, so
  /// draws wasted by a rejected command are never handed out twice.
  final int rngDrawCount;

  /// The next number the host's entity id source will hand out. Reopening
  /// resumes at the larger of this and one past the highest id in the state,
  /// so an id is never reused even if its entity was removed.
  final int nextEntityNumber;

  /// The snapshot as JSON, for stores and exports.
  JsonMap toJson() => {
    'seq': seq,
    'state': state,
    'rngDrawCount': rngDrawCount,
    'nextEntityNumber': nextEntityNumber,
  };

  /// Reads a snapshot written by [toJson].
  factory HeadSnapshot.fromJson(Map<String, Object?> json) => HeadSnapshot(
    seq: json['seq']! as int,
    state: Map<String, Object?>.from(json['state']! as Map),
    rngDrawCount: json['rngDrawCount']! as int,
    nextEntityNumber: json['nextEntityNumber'] as int? ?? 1,
  );
}

/// Where a device keeps an episode's log (04 §Interfaces).
///
/// `append` is one durable batch: after it returns, all of events, text and
/// head are stored or none are. The sembast store (`SembastEventStore` in
/// `backend`) adds the commit marker behind this contract.
abstract interface class EventStore {
  /// Appends a batch. [events] continue the stored sequence without a gap and
  /// are never empty; [head] is at the last event's `seq`; [text] lines lie in
  /// the batch in increasing `seq` order. A breach throws and stores nothing.
  Future<void> append(
    String episodeId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  );

  /// Events from [fromSeq] on, in order.
  Stream<StoredEvent> read(String episodeId, {int fromSeq = 1});

  /// Text lines from [fromSeq] on, in order.
  Stream<TextLogLine> readText(String episodeId, {int fromSeq = 1});

  /// The state at the last committed `seq`, or null when nothing is stored.
  Future<HeadSnapshot?> headSnapshot(String episodeId);

  /// Records the RNG's real draw count outside a batch, for draws made by a
  /// command that produced no stored events (rejected, or held for review).
  Future<void> saveRngDrawCount(String episodeId, int drawCount);

  /// The largest draw count ever saved or appended; 0 when none.
  Future<int> rngDrawCount(String episodeId);
}

/// [EventStore] in memory, for tests and single-device play.
final class InMemoryEventStore implements EventStore {
  final Map<String, List<StoredEvent>> _events = {};
  final Map<String, List<TextLogLine>> _text = {};
  final Map<String, HeadSnapshot> _head = {};
  final Map<String, int> _draws = {};

  @override
  Future<void> append(
    String episodeId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  ) async {
    final log = _events.putIfAbsent(episodeId, () => []);
    if (events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'a batch needs an event');
    }
    if (head.seq != log.length + events.length) {
      throw StateError('Head snapshot is not at the last event of the batch.');
    }
    var previousLine = log.length;
    for (final line in text) {
      if (line.seq <= previousLine || line.seq > head.seq) {
        throw StateError('Text line seq ${line.seq} is outside the batch.');
      }
      previousLine = line.seq;
    }
    var next = log.length + 1;
    for (final event in events) {
      if (event.seq != next++) {
        throw StateError(
          'Expected seq ${next - 1} but got ${event.seq}: a batch must '
          'continue the stored sequence.',
        );
      }
    }
    log.addAll(events);
    _text.putIfAbsent(episodeId, () => []).addAll(text);
    _head[episodeId] = head;
    _draws[episodeId] = _max(_draws[episodeId], head.rngDrawCount);
  }

  @override
  Stream<StoredEvent> read(String episodeId, {int fromSeq = 1}) =>
      Stream.fromIterable([
        for (final e in _events[episodeId] ?? const <StoredEvent>[])
          if (e.seq >= fromSeq) e,
      ]);

  @override
  Stream<TextLogLine> readText(String episodeId, {int fromSeq = 1}) =>
      Stream.fromIterable([
        for (final l in _text[episodeId] ?? const <TextLogLine>[])
          if (l.seq >= fromSeq) l,
      ]);

  @override
  Future<HeadSnapshot?> headSnapshot(String episodeId) async =>
      _head[episodeId];

  @override
  Future<void> saveRngDrawCount(String episodeId, int drawCount) async {
    _draws[episodeId] = _max(_draws[episodeId], drawCount);
  }

  @override
  Future<int> rngDrawCount(String episodeId) async => _draws[episodeId] ?? 0;

  static int _max(int? a, int b) => a == null || b > a ? b : a;
}
