import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

/// One event as a recipient receives it (the items of an `events` body,
/// 04 §Event entries).
///
/// The engine event does not carry its own `seq`, so the host wraps it:
/// `{"seq": n, "event": {...}}` for [FullEntry], `{"seq": n, "redacted":
/// true}` for [RedactedEntry], `{"seq": n, "hidden": true}` for
/// [HiddenEntry]. Every recipient gets an entry for every `seq`, so `seq`
/// stays consecutive and a gap is always a real loss. Any entry sent to the
/// agent whose request caused it also carries `"req": "<requestId>"`, which
/// acknowledges the request.
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
  ///
  /// An entry has exactly one of `event` (an object), `redacted: true` or
  /// `hidden: true`.
  static EventEntry fromJson(JsonMap json, EngineCodec codec) {
    final seq = json['seq'];
    if (seq is! int || seq < 1) {
      throw const ProtocolFormatException('entry "seq" must be >= 1');
    }
    final req = json['req'];
    if (req != null && req is! String) {
      throw const ProtocolFormatException('entry "req" must be a string');
    }
    for (final flag in const ['redacted', 'hidden']) {
      if (json.containsKey(flag) && json[flag] != true) {
        throw ProtocolFormatException('entry "$flag" must be true');
      }
    }
    final kinds = [
      for (final key in const ['event', 'redacted', 'hidden'])
        if (json.containsKey(key)) key,
    ];
    if (kinds.length != 1) {
      throw const ProtocolFormatException(
        'entry needs exactly one of "event", "redacted" or "hidden"',
      );
    }
    final requestId = req as String?;
    switch (kinds.single) {
      case 'redacted':
        return RedactedEntry(seq, requestId: requestId);
      case 'hidden':
        return HiddenEntry(seq, requestId: requestId);
    }
    final event = json['event'];
    if (event is! Map<String, Object?>) {
      throw const ProtocolFormatException('entry "event" must be an object');
    }
    return FullEntry(seq, codec.decodeEvent(event), requestId: requestId);
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

/// A recipient's view of the episode: a non-canonical engine fed with
/// entries (04 §Participants). Used by remote participants and by the host's
/// own perspective views.
final class PerspectiveFeed {
  /// Creates an empty feed.
  PerspectiveFeed(this.engine) : _state = const EpisodeState.initial();

  /// The engine that folds full entries.
  final Engine engine;

  EpisodeState _state;
  int _lastSeq = 0;
  final List<int> _opaque = [];

  /// The state built from what this recipient may see.
  EpisodeState get state => _state;

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

/// Room left in every frame for the envelope header and the `events` key,
/// unless the caller measures the header itself (see [splitEntries]).
const int frameHeaderAllowance = 4096;

/// The longest encoded event the host commits, in UTF-16 code units. It
/// leaves room for the entry's `seq`, flags and `req` (a request id is at
/// most [maxRequestIdLength] once JSON-encoded, so the entry's overhead is
/// under 320), so any committed event fits in one frame.
const int maxEventLength = maxFrameLength - frameHeaderAllowance - 1024;

/// The longest request id the host accepts, in UTF-16 code units of its
/// JSON encoding without the quotes: an escaped control character counts 6.
const int maxRequestIdLength = 256;

/// Splits encoded [entries] into frames of at most [maxCount] entries whose
/// JSON stays within [maxLength] minus [headerLength], keeping order.
///
/// [headerLength] is the room kept for the envelope header and the
/// `{"events":[]}` wrapper; the host passes its measured header. An entry
/// too large for any frame throws [ArgumentError]: the host refuses events
/// longer than [maxEventLength] before committing them, so this is a bug,
/// not a peer's doing.
List<List<JsonMap>> splitEntries(
  List<JsonMap> entries, {
  required int maxCount,
  int maxLength = maxFrameLength,
  int headerLength = frameHeaderAllowance,
}) {
  final budget = maxLength - headerLength;
  final frames = <List<JsonMap>>[];
  var current = <JsonMap>[];
  var used = 0;
  for (final entry in entries) {
    // +1 for the comma between entries.
    final size = jsonEncode(entry).length + 1;
    if (size > budget) {
      throw ArgumentError.value(entry['seq'], 'entry', 'too large for a frame');
    }
    if (current.length == maxCount || used + size > budget) {
      frames.add(current);
      current = [];
      used = 0;
    }
    current.add(entry);
    used += size;
  }
  if (current.isNotEmpty) frames.add(current);
  return frames;
}
