import 'package:engine/engine.dart';
import 'package:protocol_envelope/protocol_envelope.dart';

/// Turns engine commands, events and state into JSON and back.
///
/// The session talks to this interface only, so it can run before the real
/// codecs exist (rows 5 and 6); `protocol` supplies the implementation with
/// its fixture files. Proposed shape: 03 §Envelope says commands and events
/// have stable `type` strings, but does not name the codec API.
abstract interface class EngineCodec {
  /// Encodes [command] as the body of a `request`.
  JsonMap encodeCommand(Command command);

  /// Decodes a command; throws [ProtocolFormatException] when malformed.
  Command decodeCommand(JsonMap json);

  /// Encodes [event] for the wire or the store. The `seq` is not part of the
  /// event; the session wraps it.
  JsonMap encodeEvent(Event event);

  /// Decodes an event; throws [ProtocolFormatException] when malformed.
  Event decodeEvent(JsonMap json);

  /// Encodes [state] for a head or periodic snapshot.
  JsonMap encodeState(OperationState state);

  /// Decodes a snapshot written by [encodeState].
  OperationState decodeState(JsonMap json);
}
