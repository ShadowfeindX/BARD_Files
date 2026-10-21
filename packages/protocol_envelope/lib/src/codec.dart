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

/// The JSON codec: one frame is one JSON string, via `dart:convert`.
final class JsonEnvelopeCodec implements EnvelopeCodec {
  /// Creates the codec.
  const JsonEnvelopeCodec();

  @override
  String encode(Envelope envelope) => jsonEncode(envelope.toJson());

  @override
  Envelope decode(Object frame) {
    if (frame is! String) {
      throw const ProtocolFormatException('JSON frames must be strings');
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
