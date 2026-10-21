import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

/// One event as a recipient receives it (the items of an `events` body).
///
/// Proposed wire shape, since the engine event does not carry its own `seq`:
/// `{"seq": n, "event": {...}}` for [FullEntry], `{"seq": n, "redacted":
/// true}` for [RedactedEntry], `{"seq": n, "hidden": true}` for
/// [HiddenEntry]. A full entry sent to the agent whose request caused it
/// also carries `"req": "<requestId>"`, which acknowledges the request.
sealed class EventEntry {
  const EventEntry(this.seq, {this.requestId});

  /// The event's GM-assigned sequence number.
  final int seq;

  /// The request this event answers, when the recipient sent it. Present on
  /// redacted and hidden entries too, so a request whose result the sender
  /// may not read is still acknowledged.
  final String? requestId;

  /// Encodes this entry with [codec].
  JsonMap toJson(EngineCodec codec);

  /// Decodes an entry; throws [ProtocolFormatException] when malformed.
  static EventEntry fromJson(JsonMap json, EngineCodec codec) {
    final seq = json['seq'];
    if (seq is! int || seq < 1) {
      throw const ProtocolFormatException('entry "seq" must be >= 1');
    }
    final req = json['req'];
    if (req != null && req is! String) {
      throw const ProtocolFormatException('entry "req" must be a string');
    }
    if (json['redacted'] == true) {
      return RedactedEntry(seq, requestId: req as String?);
    }
    if (json['hidden'] == true) {
      return HiddenEntry(seq, requestId: req as String?);
    }
    final event = json['event'];
    if (event is! Map<String, Object?>) {
      throw const ProtocolFormatException('entry has no "event"');
    }
    return FullEntry(seq, codec.decodeEvent(event), requestId: req as String?);
  }
}

/// The whole event.
final class FullEntry extends EventEntry {
  /// Creates a full entry.
  const FullEntry(super.seq, this.event, {super.requestId});

  /// The event.
  final Event event;

  @override
  JsonMap toJson(EngineCodec codec) => {
    'seq': seq,
    'event': codec.encodeEvent(event),
    if (requestId != null) 'req': requestId,
  };
}

/// An event the recipient knows happened but may not read.
final class RedactedEntry extends EventEntry {
  /// Creates a redacted entry.
  const RedactedEntry(super.seq, {super.requestId});

  @override
  JsonMap toJson(EngineCodec codec) => {
    'seq': seq,
    'redacted': true,
    if (requestId != null) 'req': requestId,
  };
}

/// A sequence slot whose content is not for the recipient.
final class HiddenEntry extends EventEntry {
  /// Creates a hidden entry.
  const HiddenEntry(super.seq, {super.requestId});

  @override
  JsonMap toJson(EngineCodec codec) => {
    'seq': seq,
    'hidden': true,
    if (requestId != null) 'req': requestId,
  };
}

/// What applying a frame of entries did.
enum FeedResult {
  /// New entries were applied.
  applied,

  /// Every entry was already applied; nothing changed.
  duplicate,

  /// Entries are missing before the first one; the caller should resync.
  gap,
}

/// A recipient's view of the operation: a non-canonical engine fed with
/// entries (04 §Participants). Used by remote participants and by the host's
/// own perspective views.
final class PerspectiveFeed {
  /// Creates an empty feed.
  PerspectiveFeed(this.engine) : _state = const OperationState.initial();

  /// The engine that folds full entries.
  final Engine engine;

  OperationState _state;
  int _lastSeq = 0;
  final List<int> _opaque = [];

  /// The state built from what this recipient may see.
  OperationState get state => _state;

  /// The last `seq` applied, whether or not its content was readable.
  int get lastSeq => _lastSeq;

  /// Sequence numbers recorded as applied without being evolved: redacted
  /// and hidden entries.
  List<int> get opaqueSeqs => List.unmodifiable(_opaque);

  /// Applies [entries] (03 §Ordering).
  ///
  /// Entries already applied are skipped. Entries that start after
  /// `lastSeq + 1`, or are not consecutive among themselves, are a gap and
  /// change nothing. Redacted and hidden entries advance `lastSeq` without
  /// evolving state: the engine cannot evolve what it was not given.
  FeedResult apply(List<EventEntry> entries) {
    final fresh = [
      for (final e in entries)
        if (e.seq > _lastSeq) e,
    ];
    if (fresh.isEmpty) return FeedResult.duplicate;
    var expected = _lastSeq + 1;
    for (final entry in fresh) {
      if (entry.seq != expected++) return FeedResult.gap;
    }
    for (final entry in fresh) {
      switch (entry) {
        case FullEntry(:final event):
          _state = engine.evolve(_state, event);
        case RedactedEntry() || HiddenEntry():
          _opaque.add(entry.seq);
      }
      _lastSeq = entry.seq;
    }
    return FeedResult.applied;
  }
}
