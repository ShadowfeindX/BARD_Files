import 'dart:typed_data';

/// Watches the raw bytes of one WebSocket connection and says when a peer
/// sends more than [maxMessageBytes] for one message (RFC 6455 framing).
///
/// Why this exists: `dart:io` checks `maxPayloadLength` per frame, but it
/// joins a message's continuation frames in memory with no total limit. The
/// guard reads only frame headers, counts the payload of the message being
/// built, and fails as soon as the total passes the limit, so the socket can
/// be closed before the bytes are buffered.
///
/// The bytes before the first blank line (`\r\n\r\n`) are the HTTP upgrade
/// request or response; at most [maxHeaderBytes] of them are allowed.
final class WebSocketFrameGuard {
  /// Creates a guard for one connection.
  WebSocketFrameGuard({
    required this.maxMessageBytes,
    this.maxHeaderBytes = 16 * 1024,
  });

  /// The largest data message, in payload bytes, summed over its frames.
  final int maxMessageBytes;

  /// The largest HTTP header block before the frames start.
  final int maxHeaderBytes;

  _State _state = _State.http;
  int _httpBytes = 0;
  int _crlfMatched = 0;

  // Current frame.
  bool _fin = false;
  bool _control = false;
  bool _masked = false;
  int _lengthBytesLeft = 0;
  int _length = 0;
  int _maskBytesLeft = 0;
  int _payloadLeft = 0;

  /// Payload bytes of the data message being built.
  int _messageBytes = 0;

  /// Why the guard failed, or null while the stream is within limits.
  String? failure;

  /// The size the guard saw when it failed (header or message bytes).
  int failedAt = 0;

  /// Feeds [chunk]. Returns false once the stream has passed a limit; every
  /// later call also returns false.
  bool add(Uint8List chunk) {
    if (failure != null) return false;
    var i = 0;
    while (i < chunk.length) {
      switch (_state) {
        case _State.http:
          i = _readHttp(chunk, i);
        case _State.first:
          final byte = chunk[i++];
          _fin = byte & 0x80 != 0;
          _control = byte & 0x08 != 0;
          _state = _State.second;
        case _State.second:
          final byte = chunk[i++];
          _masked = byte & 0x80 != 0;
          final short = byte & 0x7F;
          _length = 0;
          if (short == 126) {
            _lengthBytesLeft = 2;
            _state = _State.length;
          } else if (short == 127) {
            _lengthBytesLeft = 8;
            _state = _State.length;
          } else {
            _length = short;
            _lengthDone();
          }
        case _State.length:
          _length = (_length << 8) | chunk[i++];
          if (--_lengthBytesLeft == 0) _lengthDone();
        case _State.mask:
          i++;
          if (--_maskBytesLeft == 0) _startPayload();
        case _State.payload:
          final take = _payloadLeft < chunk.length - i
              ? _payloadLeft
              : chunk.length - i;
          _payloadLeft -= take;
          i += take;
          if (_payloadLeft == 0) _frameDone();
      }
      if (failure != null) return false;
    }
    return true;
  }

  int _readHttp(Uint8List chunk, int i) {
    const crlfcrlf = [13, 10, 13, 10];
    while (i < chunk.length) {
      final byte = chunk[i++];
      _httpBytes++;
      if (_httpBytes > maxHeaderBytes) {
        _fail('header block too large', _httpBytes);
        return i;
      }
      _crlfMatched = byte == crlfcrlf[_crlfMatched]
          ? _crlfMatched + 1
          : (byte == 13 ? 1 : 0);
      if (_crlfMatched == 4) {
        _state = _State.first;
        return i;
      }
    }
    return i;
  }

  void _lengthDone() {
    // A 64-bit length with the top bit set reads as negative here.
    if (_length < 0) {
      _fail('bad length', _length);
      return;
    }
    // RFC 6455 5.5: control frames carry at most 125 bytes.
    if (_control && _length > 125) {
      _fail('control frame too large', _length);
      return;
    }
    if (!_control && _messageBytes + _length > maxMessageBytes) {
      _fail('message too large', _messageBytes + _length);
      return;
    }
    if (!_control) _messageBytes += _length;
    if (_masked) {
      _maskBytesLeft = 4;
      _state = _State.mask;
    } else {
      _startPayload();
    }
  }

  void _startPayload() {
    _payloadLeft = _length;
    if (_payloadLeft == 0) {
      _frameDone();
    } else {
      _state = _State.payload;
    }
  }

  void _frameDone() {
    if (!_control && _fin) _messageBytes = 0;
    _state = _State.first;
  }

  void _fail(String reason, int size) {
    failure = reason;
    failedAt = size;
  }
}

enum _State { http, first, second, length, mask, payload }
