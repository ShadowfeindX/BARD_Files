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
}

/// Where a device keeps an operation's log (04 §Interfaces).
///
/// `append` is one durable batch: after it returns, all of events, text and
/// head are stored or none are. The sembast store (row 12) adds the commit
/// marker behind this contract.
abstract interface class EventStore {
  /// Appends a batch. [events] continue the stored sequence without a gap.
  Future<void> append(
    String operationId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  );

  /// Events from [fromSeq] on, in order.
  Stream<StoredEvent> read(String operationId, {int fromSeq = 1});

  /// Text lines from [fromSeq] on, in order.
  Stream<TextLogLine> readText(String operationId, {int fromSeq = 1});

  /// The state at the last committed `seq`, or null when nothing is stored.
  Future<HeadSnapshot?> headSnapshot(String operationId);

  /// Records the RNG's real draw count outside a batch, for draws made by a
  /// command that produced no stored events (rejected, or held for review).
  Future<void> saveRngDrawCount(String operationId, int drawCount);

  /// The largest draw count ever saved or appended; 0 when none.
  Future<int> rngDrawCount(String operationId);
}

/// [EventStore] in memory, for tests and single-device play.
final class InMemoryEventStore implements EventStore {
  final Map<String, List<StoredEvent>> _events = {};
  final Map<String, List<TextLogLine>> _text = {};
  final Map<String, HeadSnapshot> _head = {};
  final Map<String, int> _draws = {};

  @override
  Future<void> append(
    String operationId,
    List<StoredEvent> events,
    List<TextLogLine> text,
    HeadSnapshot head,
  ) async {
    final log = _events.putIfAbsent(operationId, () => []);
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
    _text.putIfAbsent(operationId, () => []).addAll(text);
    _head[operationId] = head;
    _draws[operationId] = _max(_draws[operationId], head.rngDrawCount);
  }

  @override
  Stream<StoredEvent> read(String operationId, {int fromSeq = 1}) =>
      Stream.fromIterable([
        for (final e in _events[operationId] ?? const <StoredEvent>[])
          if (e.seq >= fromSeq) e,
      ]);

  @override
  Stream<TextLogLine> readText(String operationId, {int fromSeq = 1}) =>
      Stream.fromIterable([
        for (final l in _text[operationId] ?? const <TextLogLine>[])
          if (l.seq >= fromSeq) l,
      ]);

  @override
  Future<HeadSnapshot?> headSnapshot(String operationId) async =>
      _head[operationId];

  @override
  Future<void> saveRngDrawCount(String operationId, int drawCount) async {
    _draws[operationId] = _max(_draws[operationId], drawCount);
  }

  @override
  Future<int> rngDrawCount(String operationId) async =>
      _draws[operationId] ?? 0;

  static int _max(int? a, int b) => a == null || b > a ? b : a;
}
