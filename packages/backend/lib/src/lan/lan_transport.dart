import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:protocol/protocol.dart' show maxFrameLength;
import 'package:session/session.dart';

import 'frame_guard.dart';
import 'guarded_socket.dart';

/// The most UTF-8 bytes a frame of [maxFrameLength] UTF-16 units can take:
/// one unit is at most 3 bytes (a surrogate pair is 2 units and 4 bytes).
/// The socket stops reading a message past this many bytes.
const int maxFrameBytes = 3 * maxFrameLength;

/// Everything a player needs to join a LAN host, and nothing else (the LAN
/// QR carries exactly this): host, port and join code.
///
/// As an [Address] it is `ws://<host>:<port>/join?code=<joinCode>`.
final class LanJoinInfo {
  /// Creates join info.
  const LanJoinInfo({
    required this.host,
    required this.port,
    required this.joinCode,
  });

  /// Reads join info from [address]. Throws [FormatException] when it is
  /// not a LAN join address.
  factory LanJoinInfo.parse(Address address) {
    final uri = Uri.parse(address.value);
    final code = uri.queryParameters['code'];
    if (uri.scheme != 'ws' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.path != joinPath ||
        code == null ||
        code.isEmpty) {
      throw FormatException('Not a LAN join address', address.value);
    }
    return LanJoinInfo(host: uri.host, port: uri.port, joinCode: code);
  }

  /// The path the host serves.
  static const String joinPath = '/join';

  /// The host's LAN address (an IP address or a name).
  final String host;

  /// The host's port.
  final int port;

  /// The code the host checks before a link opens.
  final String joinCode;

  /// The join address a player connects to.
  Address get address => Address(
    Uri(
      scheme: 'ws',
      host: host,
      port: port,
      path: joinPath,
      queryParameters: {'code': joinCode},
    ).toString(),
  );
}

/// Makes a random join code: [length] characters from an alphabet without
/// look-alikes (no 0/O, 1/I/L).
String newJoinCode({int length = 6, Random? random}) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final source = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(source.nextInt(alphabet.length)),
  ]);
}

/// The IPv4 addresses of this machine's network interfaces, loopback left
/// out: the candidates to show as the host address.
Future<List<String>> lanAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (!address.isLoopback) address.address,
  ];
}

/// The host side of the LAN transport (S-6: `dart:io` HTTP server and
/// WebSockets, no package): players open `ws://host:port/join?code=...`.
///
/// A request with the wrong path or join code gets an HTTP error and never
/// becomes a link. Every connection is read through a [WebSocketFrameGuard],
/// so a message longer than [maxFrameBytes] closes the socket before it is
/// buffered; a frame longer than [maxFrameLength] UTF-16 units is dropped.
/// Both are recorded in [diagnostics].
final class LanHostTransport implements Transport {
  LanHostTransport._(
    this._socket,
    this._server,
    this.joinCode,
    this.diagnostics,
  );

  /// Listens on [address] (default: every IPv4 interface) at [port] (default:
  /// any free port). [joinCode] defaults to [newJoinCode].
  static Future<LanHostTransport> bind({
    InternetAddress? address,
    int port = 0,
    String? joinCode,
    DiagnosticLog? diagnostics,
  }) async {
    final socket = await ServerSocket.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    final server = HttpServer.listenOn(
      GuardedServerSocket(
        socket,
        (connection) => GuardedSocket(
          connection,
          WebSocketFrameGuard(maxMessageBytes: maxFrameBytes),
          onOversize: (guard) => _recordOversize(diagnostics, guard),
        ),
      ),
    );
    final transport = LanHostTransport._(
      socket,
      server,
      joinCode ?? newJoinCode(),
      diagnostics,
    );
    server.listen(
      transport._onRequest,
      onError: (Object e) => diagnostics?.record(
        DiagnosticCategory.network,
        'lan.serverError',
        {'type': e.runtimeType.toString()},
      ),
    );
    return transport;
  }

  final HttpServer _server;

  // `HttpServer.listenOn` never closes the socket it was given, so [close]
  // closes it; otherwise the port stays bound until the process exits.
  final ServerSocket _socket;
  final StreamController<Link> _links = StreamController<Link>();
  final Set<_WebSocketLink> _open = {};
  bool _closing = false;

  /// The code players must send.
  final String joinCode;

  /// Where refusals and dropped frames are noted, or null.
  final DiagnosticLog? diagnostics;

  /// The port the host listens on.
  int get port => _server.port;

  /// Join info for players who reach this machine at [host].
  LanJoinInfo joinInfo(String host) =>
      LanJoinInfo(host: host, port: port, joinCode: joinCode);

  @override
  Stream<Link> incoming() => _links.stream;

  @override
  Future<Link> connect(Address address) =>
      throw UnsupportedError('A host transport only accepts links.');

  /// Stops listening and closes every open link.
  Future<void> close() async {
    // Set first: an upgrade that finishes while the links below close must
    // not add a link nobody will close.
    _closing = true;
    await _server.close(force: true);
    await _socket.close();
    for (final link in _open.toList()) {
      await link.close();
    }
    // Not awaited: the future completes only once a listener has seen the
    // done event, and a paused listener may never take it.
    unawaited(_links.close());
  }

  Future<void> _onRequest(HttpRequest request) async {
    final refusal = _check(request);
    if (refusal != null) {
      diagnostics?.record(DiagnosticCategory.network, 'lan.refused', {
        'reason': refusal.$2,
      });
      try {
        request.response
          ..persistentConnection = false
          ..statusCode = refusal.$1;
        await request.response.close();
      } on Object {
        // The client left before the answer; nothing to tell it.
      }
      return;
    }
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
        maxPayloadLength: maxFrameBytes,
      );
    } on Object catch (e) {
      diagnostics?.record(DiagnosticCategory.network, 'lan.upgradeFailed', {
        'type': e.runtimeType.toString(),
      });
      return;
    }
    if (_closing) {
      await socket.close();
      return;
    }
    final link = _WebSocketLink(socket, diagnostics);
    _open.add(link);
    unawaited(
      socket.done.then<void>(
        (_) => _open.remove(link),
        onError: (Object _) => _open.remove(link),
      ),
    );
    _links.add(link);
  }

  (int, String)? _check(HttpRequest request) {
    if (request.uri.path != LanJoinInfo.joinPath) {
      return (HttpStatus.notFound, 'path');
    }
    if (request.uri.queryParameters['code'] != joinCode) {
      return (HttpStatus.forbidden, 'joinCode');
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      return (HttpStatus.badRequest, 'notUpgrade');
    }
    return null;
  }
}

/// The client side of the LAN transport: [connect] opens a link to a
/// [LanJoinInfo.address], read through a [WebSocketFrameGuard] like the
/// host's.
///
/// A host that answers with HTTP 403 or 404 (wrong code or path) makes
/// [connect] throw [ConnectRefused]; other failures throw as they are, and a
/// reconnect loop retries them. A connect that takes longer than
/// [connectTimeout] throws [TimeoutException].
final class LanClientTransport implements Transport {
  /// Creates the transport.
  const LanClientTransport({
    this.diagnostics,
    this.connectTimeout = const Duration(seconds: 10),
  });

  /// Where dropped frames are noted, or null.
  final DiagnosticLog? diagnostics;

  /// The longest a TCP connect plus WebSocket upgrade may take.
  final Duration connectTimeout;

  @override
  Stream<Link> incoming() => const Stream.empty();

  @override
  Future<Link> connect(Address address) async {
    final info = LanJoinInfo.parse(address);
    final client = HttpClient();
    // Straight to the host, never through a proxy from the environment, and
    // through a guarded socket.
    client
      ..findProxy = ((_) => 'DIRECT')
      ..connectionFactory = (
        Uri uri,
        String? proxyHost,
        int? proxyPort,
      ) async => ConnectionTask.fromSocket(_guardedConnect(uri), () {});
    final connecting = WebSocket.connect(
      info.address.value,
      compression: CompressionOptions.compressionOff,
      customClient: client,
      maxPayloadLength: maxFrameBytes,
    );
    try {
      final socket = await connecting.timeout(
        connectTimeout,
        onTimeout: () {
          // An upgrade that finishes after the timeout must not leave an
          // open socket that nothing reads or closes.
          unawaited(
            connecting.then((opened) => opened.close(), onError: (Object _) {}),
          );
          throw TimeoutException('LAN connect', connectTimeout);
        },
      );
      return _WebSocketLink(socket, diagnostics);
    } on WebSocketException catch (e) {
      final status = e.httpStatusCode;
      if (status == HttpStatus.forbidden) {
        throw const ConnectRefused('joinCode');
      }
      if (status == HttpStatus.notFound) {
        throw const ConnectRefused('path');
      }
      rethrow;
    } finally {
      // Forced, so a timed-out upgrade is torn down; a WebSocket that did
      // open is detached from the client and is not affected.
      client.close(force: true);
    }
  }

  Future<Socket> _guardedConnect(Uri uri) async => GuardedSocket(
    await Socket.connect(uri.host, uri.port, timeout: connectTimeout),
    WebSocketFrameGuard(maxMessageBytes: maxFrameBytes),
    onOversize: (guard) => _recordOversize(diagnostics, guard),
  );
}

void _recordOversize(DiagnosticLog? diagnostics, WebSocketFrameGuard guard) =>
    diagnostics?.record(DiagnosticCategory.error, 'lan.oversize', {
      'reason': guard.failure,
      'bytes': guard.failedAt,
      'limit': guard.maxMessageBytes,
    });

/// One WebSocket as a [Link]: text messages are frames.
final class _WebSocketLink implements Link {
  _WebSocketLink(this._socket, this._diagnostics) {
    frames = _socket
        .where((message) {
          if (message is! String) {
            _diagnostics?.record(DiagnosticCategory.error, 'lan.binaryFrame');
            return false;
          }
          if (message.length > maxFrameLength) {
            _diagnostics?.record(DiagnosticCategory.error, 'lan.oversize', {
              'reason': 'frame too long',
              'length': message.length,
              'limit': maxFrameLength,
            });
            return false;
          }
          return true;
        })
        .cast<String>()
        .handleError((Object e) {
          _diagnostics?.record(DiagnosticCategory.network, 'lan.socketError', {
            'type': e.runtimeType.toString(),
          });
        });
  }

  final WebSocket _socket;
  final DiagnosticLog? _diagnostics;
  bool _closed = false;

  @override
  late final Stream<String> frames;

  @override
  Future<void> send(String frame) async {
    if (_closed || _socket.closeCode != null) {
      throw StateError('The link is closed.');
    }
    if (frame.length > maxFrameLength) {
      throw ArgumentError.value(
        frame.length,
        'frame',
        'longer than $maxFrameLength',
      );
    }
    _socket.add(frame);
  }

  @override
  Future<void> close() async {
    _closed = true;
    // Not awaited past a short wait: a peer that never answers the close
    // handshake must not hold the caller.
    await _socket.close().timeout(const Duration(seconds: 2), onTimeout: () {});
  }
}
