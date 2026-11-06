// ignore_for_file: prefer_initializing_formals
// (private fields set from public parameters)
import 'dart:async';

import 'package:protocol/protocol.dart';

import 'transport.dart';

/// How a [ConnectionActor] checks that the other end is still there.
///
/// Every [interval] it sends a `ping`; any frame from the other end counts as
/// a sign of life. After [timeout] with no frame at all, the link is treated
/// as dead and closed, so its owner sees it end and can reconnect.
final class Liveness {
  /// Creates the policy. [timeout] should be a few [interval]s long, so one
  /// lost ping is not enough to drop a link.
  const Liveness({
    this.interval = const Duration(seconds: 5),
    this.timeout = const Duration(seconds: 15),
  });

  /// Time between pings.
  final Duration interval;

  /// Silence after which the link is closed.
  final Duration timeout;
}

/// One link seen as envelopes (04 §Coarse actors): frames in, decoded
/// envelopes out, and the other way round, plus liveness pings when asked.
///
/// A frame that is not a valid envelope is reported and dropped, never
/// thrown into the owner. Reconnect backoff belongs to the owner (see
/// `Reconnector`).
final class ConnectionActor {
  /// Wraps [link]. [onMalformed] hears about frames that failed to decode.
  ConnectionActor(
    this.link, {
    EnvelopeCodec codec = const JsonEnvelopeCodec(),
    void Function(ProtocolFormatException error)? onMalformed,
  }) : _codec = codec {
    envelopes = link.frames
        .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleData: (frame, sink) {
              _quiet.reset();
              sink.add(frame);
            },
            handleDone: (sink) {
              _stopPinging();
              sink.close();
            },
          ),
        )
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
  final Stopwatch _quiet = Stopwatch();
  Timer? _pinger;
  int _pings = 0;

  /// Decoded envelopes, in arrival order.
  late final Stream<Envelope> envelopes;

  /// Starts sending pings under [policy]. [envelopeFor] wraps each ping in
  /// the owner's envelope header; [onDead] runs once, just before a silent
  /// link is closed. Call after [envelopes] has a listener.
  void keepAlive(
    Liveness policy, {
    required Envelope Function(Ping ping) envelopeFor,
    void Function()? onDead,
  }) {
    _stopPinging();
    _quiet
      ..reset()
      ..start();
    _pinger = Timer.periodic(policy.interval, (_) {
      if (_quiet.elapsed >= policy.timeout) {
        _stopPinging();
        onDead?.call();
        unawaited(link.close());
        return;
      }
      unawaited(
        send(envelopeFor(Ping(nonce: '${++_pings}'))).catchError((Object _) {}),
      );
    });
  }

  void _stopPinging() {
    _pinger?.cancel();
    _pinger = null;
  }

  /// Sends [envelope] as one frame.
  Future<void> send(Envelope envelope) async =>
      link.send(_codec.encode(envelope) as String);

  /// Closes the link and stops pinging.
  Future<void> close() {
    _stopPinging();
    return link.close();
  }
}
