import 'dart:async';

/// Where a host can be reached. Opaque to the session; each transport reads
/// its own kind of address.
extension type const Address(String value) {}

/// One transport link (04 §Interfaces). Frames are opaque strings: a
/// transport only moves them.
abstract interface class Link {
  /// Frames received from the other end.
  Stream<String> get frames;

  /// Sends one frame.
  Future<void> send(String frame);

  /// Closes the link; [frames] then completes.
  Future<void> close();
}

/// One kind of transport: in-process, LAN, P2P or relay.
abstract interface class Transport {
  /// Links opened by clients (host side).
  Stream<Link> incoming();

  /// Opens a link to a host (client side).
  Future<Link> connect(Address address);
}
