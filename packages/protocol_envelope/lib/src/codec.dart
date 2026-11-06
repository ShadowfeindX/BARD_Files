import 'dart:convert';

import 'envelope.dart';
import 'json.dart';

/// Turns envelopes into transport frames and back.
///
/// A transport only moves opaque frames. A binary codec can implement this
/// interface later if size ever matters (03 §Envelope).
abstract interface class EnvelopeCodec {
  /// Encodes [envelope] as one frame.
  Object encode(Envelope envelope);

  /// Decodes one frame. Throws [ProtocolFormatException] on malformed input.
  Envelope decode(Object frame);
}

/// The largest frame [JsonEnvelopeCodec] sends or accepts, in UTF-16 code
/// units (Dart string length): 1 Mi.
///
/// A frame is checked before it is parsed, so a peer cannot make a client
/// parse and hold an arbitrarily large frame. The host splits `events`
/// frames to stay under it (04 §Event entries).
const int maxFrameLength = 1024 * 1024;

/// The JSON codec: one frame is one JSON string, via `dart:convert`.
final class JsonEnvelopeCodec implements EnvelopeCodec {
  /// Creates the codec. [maxLength] is the frame limit; tests may lower it.
  const JsonEnvelopeCodec({this.maxLength = maxFrameLength});

  /// The largest frame this codec sends or accepts, in UTF-16 code units.
  final int maxLength;

  /// Encodes [envelope]. Throws [ArgumentError] when the frame would be
  /// longer than [maxLength]: the sender must split it.
  @override
  String encode(Envelope envelope) {
    final frame = jsonEncode(envelope.toJson());
    if (frame.length > maxLength) {
      throw ArgumentError.value(
        frame.length,
        'envelope',
        'frame is longer than $maxLength',
      );
    }
    return frame;
  }

  /// Decodes [frame]. A frame longer than [maxLength] is refused with a
  /// [ProtocolFormatException] before it is parsed.
  @override
  Envelope decode(Object frame) {
    if (frame is! String) {
      throw const ProtocolFormatException('JSON frames must be strings');
    }
    if (frame.length > maxLength) {
      throw ProtocolFormatException(
        'frame of ${frame.length} is longer than $maxLength',
      );
    }
    final Object? json;
    try {
      json = jsonDecode(frame);
    } on FormatException catch (e) {
      throw ProtocolFormatException('frame is not valid JSON: ${e.message}');
    }
    return Envelope.fromJson(json);
  }
}
