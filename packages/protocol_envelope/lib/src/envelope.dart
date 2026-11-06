import 'engine_version.dart';
import 'json.dart';
import 'messages.dart';

/// The protocol major this package speaks (`p`).
const int protocolMajor = 1;

/// The frame every transport moves (03 §Envelope).
///
/// The header fields are decoded without interpreting the body (a missing
/// body reads as empty, `events` without `seq` fails only in [message]), so a
/// host can read `p` and `e` of a frame from a different protocol major and
/// still answer with `refused`. [type] stays a string for the same reason.
/// `e` must still be `major.minor.patch`.
final class Envelope {
  /// Creates an envelope from raw parts. Prefer [Envelope.of].
  Envelope({
    required this.protocol,
    required this.engineVersion,
    required this.episodeId,
    required this.from,
    required this.type,
    required this.body,
    this.seq,
  }) {
    if (protocol < 1) throw ArgumentError.value(protocol, 'protocol');
    if (seq != null && seq! < 1) throw ArgumentError.value(seq, 'seq');
    if ((type == MessageType.events.wire) != (seq != null)) {
      throw ArgumentError('seq is set on `events` frames and on no others');
    }
  }

  /// Wraps [message] in an envelope for this protocol major.
  ///
  /// For [Events], the envelope `seq` is the first entry's `seq`: [seq] may
  /// be left out, and when given it must equal [Events.firstSeq]. [seq] is
  /// refused for every other message.
  factory Envelope.of(
    Message message, {
    required EngineVersion engineVersion,
    required String episodeId,
    required String from,
    int? seq,
    int protocol = protocolMajor,
  }) {
    if (message is Events && seq != null && seq != message.firstSeq) {
      throw ArgumentError.value(seq, 'seq', 'must be the first entry seq');
    }
    return Envelope(
      protocol: protocol,
      engineVersion: engineVersion,
      episodeId: episodeId,
      seq: message is Events ? message.firstSeq : seq,
      from: from,
      type: message.type.wire,
      body: message.toBody(),
    );
  }

  /// Decodes an envelope from decoded JSON.
  factory Envelope.fromJson(Object? json) {
    final map = asJsonMap(json, 'envelope');
    final type = reqString(map, 'type');
    final seq = optInt(map, 'seq');
    // `seq` is only meaningful on `events`; a known non-events type with a
    // `seq` is malformed. Unknown types pass, so a header always decodes.
    final known = MessageType.fromWire(type);
    if (seq != null && known != null && known != MessageType.events) {
      throw ProtocolFormatException('"seq" is not allowed on $type');
    }
    final protocol = reqInt(map, 'p');
    if (protocol < 1) throw const ProtocolFormatException('"p" must be >= 1');
    if (seq != null && seq < 1) {
      throw const ProtocolFormatException('"seq" must be >= 1');
    }
    return Envelope._(
      protocol: protocol,
      engineVersion: EngineVersion.parse(reqString(map, 'e')),
      episodeId: reqString(map, 'ep'),
      seq: seq,
      from: reqString(map, 'from'),
      type: type,
      body: optMap(map, 'body') ?? const {},
    );
  }

  // Skips the constructor checks: fromJson has already reported them as
  // ProtocolFormatException, which callers can tell apart from a coding error.
  Envelope._({
    required this.protocol,
    required this.engineVersion,
    required this.episodeId,
    required this.from,
    required this.type,
    required this.body,
    this.seq,
  });

  /// `p`: protocol major.
  final int protocol;

  /// `e`: the sender's engine version.
  final EngineVersion engineVersion;

  /// `ep`: episode id.
  final String episodeId;

  /// `seq`: the first event's `seq`; present on `events` frames only.
  final int? seq;

  /// `from`: an alias id or [gmSender].
  final String from;

  /// `type`: the wire name of the message type.
  final String type;

  /// `body`: the message-specific payload.
  final JsonMap body;

  /// The known [MessageType], or null for a type this version does not know.
  MessageType? get messageType => MessageType.fromWire(type);

  /// Decodes [body] as a typed message. Throws [ProtocolFormatException] for
  /// an unknown [type] or a malformed body.
  Message get message {
    final known = messageType;
    if (known == null) {
      throw ProtocolFormatException('unknown message type "$type"');
    }
    if (known == MessageType.events && seq == null) {
      throw const ProtocolFormatException('"seq" is required on events');
    }
    final message = Message.fromBody(known, body);
    if (message is Events && message.firstSeq != seq) {
      throw const ProtocolFormatException(
        'envelope "seq" must be the first entry\'s "seq"',
      );
    }
    return message;
  }

  /// Encodes this envelope as JSON-compatible data.
  JsonMap toJson() => {
    'p': protocol,
    'e': engineVersion.toString(),
    'ep': episodeId,
    if (seq != null) 'seq': seq,
    'from': from,
    'type': type,
    'body': body,
  };
}
