/// Codecs between the engine's commands and events and the JSON carried in
/// `protocol_envelope` message bodies (03 §Envelope).
///
/// Hand written, no code generation (P6). Every command and event has a
/// stable `type` string and a versioned shape; see `README.md`.
library;

export 'src/command_codec.dart' show decodeCommand, encodeCommand;
export 'src/event_codec.dart' show decodeEvent, encodeEvent;
export 'src/shared_codec.dart' show UnknownTypeException, shapeVersion;
