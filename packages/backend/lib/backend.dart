/// Flutter and Firebase adapters behind the session and app interfaces.
///
/// The diagnostic file sink, the report bundle writer, the LAN transport,
/// the sembast `EventStore`, the host settings and the Handler's NPC notes
/// live here; the other adapters are filled in by their owning workstreams.
library;

export 'src/diagnostic_file_sink.dart';
export 'src/host_settings_store.dart';
export 'src/lan/lan_transport.dart';
export 'src/npc_notes_store.dart';
export 'src/report_bundle_writer.dart';
export 'src/sembast_event_store.dart';
