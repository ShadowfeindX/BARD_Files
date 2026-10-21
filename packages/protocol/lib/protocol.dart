/// Codecs between the engine's commands and events and the JSON carried in
/// `protocol_envelope` message bodies (03 §Envelope).
///
/// Hand written, no code generation (P6). Every command and event has a
/// stable `type` string and a versioned shape; see `README.md`.
///
/// Also re-exports `protocol_envelope`, so layers that may depend on
/// `protocol` but not on `protocol_envelope` directly (`session`, `backend`)
/// reach the envelope and message types through this library.
library;

export 'package:protocol_envelope/protocol_envelope.dart';

export 'src/command_codec.dart' show decodeCommand, encodeCommand;
export 'src/engine_codec.dart';
export 'src/event_codec.dart' show decodeEvent, encodeEvent;
export 'src/shared_codec.dart' show UnknownTypeException, shapeVersion;
