/// Flutter and Firebase adapters behind the session and app interfaces.
///
/// The diagnostic file sink, the report bundle writer and the LAN transport
/// live here; the other adapters are filled in by their owning workstreams.
library;

export 'src/diagnostic_file_sink.dart';
export 'src/lan/lan_transport.dart';
export 'src/report_bundle_writer.dart';
