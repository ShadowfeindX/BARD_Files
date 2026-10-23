import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart' as codec;
import 'package:protocol/protocol.dart' show EngineCodec, JsonMap;

/// [EngineCodec] backed by the hand-written command and event codecs.
///
/// State snapshots have no codec yet (the host replays the log and never
/// decodes a snapshot), so [encodeState] writes only a small head summary and
/// [decodeState] refuses.
class ProtocolEngineCodec implements EngineCodec {
  /// Creates the codec.
  const ProtocolEngineCodec();

  @override
  JsonMap encodeCommand(Command command) => codec.encodeCommand(command);

  @override
  Command decodeCommand(JsonMap json) => codec.decodeCommand(json);

  @override
  JsonMap encodeEvent(Event event) => codec.encodeEvent(event);

  @override
  Event decodeEvent(JsonMap json) => codec.decodeEvent(json);

  @override
  JsonMap encodeState(OperationState state) => {
    'started': state.started,
    'entities': state.stores.entities.length,
  };

  @override
  OperationState decodeState(JsonMap json) => throw UnsupportedError(
    'State snapshots are not decoded yet; the host replays events.',
  );
}
