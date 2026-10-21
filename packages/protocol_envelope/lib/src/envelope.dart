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
    required this.operationId,
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
  /// [seq] is required for [Events] (the first event's `seq`) and refused for
  /// every other message.
  factory Envelope.of(
    Message message, {
    required EngineVersion engineVersion,
    required String operationId,
    required String from,
    int? seq,
    int protocol = protocolMajor,
  }) => Envelope(
    protocol: protocol,
    engineVersion: engineVersion,
    operationId: operationId,
    seq: seq,
    from: from,
    type: message.type.wire,
    body: message.toBody(),
  );

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
      operationId: reqString(map, 'op'),
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
    required this.operationId,
    required this.from,
    required this.type,
    required this.body,
    this.seq,
  });

  /// `p`: protocol major.
  final int protocol;

  /// `e`: the sender's engine version.
  final EngineVersion engineVersion;

  /// `op`: operation id.
  final String operationId;

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
    return Message.fromBody(known, body);
  }

  /// Encodes this envelope as JSON-compatible data.
  JsonMap toJson() => {
    'p': protocol,
    'e': engineVersion.toString(),
    'op': operationId,
    if (seq != null) 'seq': seq,
    'from': from,
    'type': type,
    'body': body,
  };
}
