import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'frame_guard.dart';

/// A [Socket] whose incoming bytes pass through a [WebSocketFrameGuard].
///
/// When the guard fails, the socket is destroyed before the chunk reaches
/// the HTTP or WebSocket parser, and [onOversize] hears why. Everything else
/// is passed straight to the wrapped socket.
///
/// The check sits in a `map` on the stream, not in a `listen` override:
/// `HttpResponse.detachSocket` swaps the subscription's data handler, which
/// would skip a check made in the handler.
final class GuardedSocket extends StreamView<Uint8List> implements Socket {
  /// Wraps [socket].
  factory GuardedSocket(
    Socket socket,
    WebSocketFrameGuard guard, {
    void Function(WebSocketFrameGuard guard)? onOversize,
  }) {
    final checked = socket.map((chunk) {
      final alreadyFailed = guard.failure != null;
      if (guard.add(chunk)) return chunk;
      if (!alreadyFailed) {
        socket.destroy();
        onOversize?.call(guard);
      }
      return Uint8List(0);
    });
    return GuardedSocket._(socket, checked);
  }

  GuardedSocket._(this._socket, Stream<Uint8List> checked) : super(checked);

  final Socket _socket;

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) => _socket.encoding = value;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> flush() => _socket.flush();

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _socket.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  InternetAddress get address => _socket.address;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  int get port => _socket.port;

  @override
  int get remotePort => _socket.remotePort;

  @override
  void destroy() => _socket.destroy();

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
}

/// A [ServerSocket] that hands out [GuardedSocket]s, so `HttpServer.listenOn`
/// reads every accepted connection through a guard.
final class GuardedServerSocket extends StreamView<Socket>
    implements ServerSocket {
  /// Wraps [server]; [guard] makes each connection's guarded socket.
  GuardedServerSocket(this._server, GuardedSocket Function(Socket) guard)
    : super(_server.map(guard));

  final ServerSocket _server;

  @override
  InternetAddress get address => _server.address;

  @override
  int get port => _server.port;

  @override
  Future<ServerSocket> close() async {
    await _server.close();
    return this;
  }
}
