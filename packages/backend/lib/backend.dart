/// Flutter and Firebase adapters behind the session and app interfaces.
///
/// The diagnostic file sink, the report bundle writer, the LAN transport,
/// the sembast `EventStore` and the host settings live here; the other
/// adapters are filled in by their owning workstreams.
library;

export 'src/diagnostic_file_sink.dart';
export 'src/host_settings_store.dart';
export 'src/lan/lan_transport.dart';
export 'src/report_bundle_writer.dart';
export 'src/sembast_event_store.dart';
