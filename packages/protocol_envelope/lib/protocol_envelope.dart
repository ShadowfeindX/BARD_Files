/// The B.A.R.D. wire envelope, message types and version negotiation.
///
/// Pure Dart and Dart SDK only: it does not depend on the engine, so
/// `apps/functions` can depend on it alone (F4). Engine command and event
/// shapes travel here as opaque JSON; their codecs live in `protocol`.
library;

export 'src/codec.dart';
export 'src/engine_version.dart';
export 'src/envelope.dart';
export 'src/json.dart' show JsonMap, ProtocolFormatException;
export 'src/messages.dart';
export 'src/negotiation.dart';
export 'src/refusal_reason.dart';
