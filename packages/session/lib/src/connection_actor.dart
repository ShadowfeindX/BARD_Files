// ignore_for_file: prefer_initializing_formals
// (private fields set from public parameters)
import 'dart:async';

import 'package:protocol/protocol.dart';

import 'transport.dart';

/// One link seen as envelopes (04 §Coarse actors): frames in, decoded
/// envelopes out, and the other way round.
///
/// Framing only. Liveness (ping scheduling) and reconnect backoff belong to
/// the real transports; a frame that is not a valid envelope is reported and
/// dropped, never thrown into the owner.
final class ConnectionActor {
  /// Wraps [link]. [onMalformed] hears about frames that failed to decode.
  ConnectionActor(
    this.link, {
    EnvelopeCodec codec = const JsonEnvelopeCodec(),
    void Function(ProtocolFormatException error)? onMalformed,
  }) : _codec = codec {
    envelopes = link.frames
        .map<Envelope?>((frame) {
          try {
            return _codec.decode(frame);
          } on ProtocolFormatException catch (e) {
            onMalformed?.call(e);
            return null;
          }
        })
        .where((e) => e != null)
        .cast<Envelope>();
  }

  /// The underlying link.
  final Link link;

  final EnvelopeCodec _codec;

  /// Decoded envelopes, in arrival order.
  late final Stream<Envelope> envelopes;

  /// Sends [envelope] as one frame.
  Future<void> send(Envelope envelope) async =>
      link.send(_codec.encode(envelope) as String);

  /// Closes the link.
  Future<void> close() => link.close();
}
