/// Pure-Dart actors, operation loop, transport and store interfaces, Rng adapter.
///
/// See `docs/architecture/04-session.md`.
library;

export 'src/authorizer.dart';
export 'src/clock.dart';
export 'src/connection_actor.dart';
export 'src/entries.dart';
export 'src/event_store.dart';
export 'src/identity.dart';
export 'src/in_memory_transport.dart';
export 'src/mailbox.dart';
export 'src/operation_host.dart';
export 'src/operation_participant.dart';
export 'src/perspective.dart';
export 'src/transport.dart';
export 'src/xoshiro_rng.dart';
