import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:backend/backend.dart';
import 'package:backend/src/lan/frame_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart' show maxFrameLength;
import 'package:session/session.dart';

/// One frame header plus payload, client-masked with a zero key (so the
/// payload bytes stay readable).
List<int> frame(int opcode, int length, {bool fin = true, bool mask = true}) {
  final header = <int>[(fin ? 0x80 : 0) | opcode];
  final maskBit = mask ? 0x80 : 0;
  if (length < 126) {
    header.add(maskBit | length);
  } else if (length < 65536) {
    header.addAll([maskBit | 126, length >> 8, length & 0xFF]);
  } else {
    header.add(maskBit | 127);
    for (var shift = 56; shift >= 0; shift -= 8) {
      header.add((length >> shift) & 0xFF);
    }
  }
  if (mask) header.addAll([0, 0, 0, 0]);
  return [...header, ...List.filled(length, 0x61)];
}

final Uint8List httpHead = Uint8List.fromList(
  'GET /join HTTP/1.1\r\nHost: x\r\n\r\n'.codeUnits,
);

void main() {
  group('WebSocketFrameGuard', () {
    test('passes messages within the limit, in any chunking', () {
      final bytes = Uint8List.fromList([
        ...httpHead,
        ...frame(0x1, 100, fin: false),
        ...frame(0x9, 5), // a ping between fragments does not count
        ...frame(0x0, 100),
        ...frame(0x1, 200),
        ...frame(0x2, 70000),
      ]);
      final guard = WebSocketFrameGuard(maxMessageBytes: 70000);
      // One byte at a time is the worst split for the header parser.
      for (var i = 0; i < bytes.length; i++) {
        expect(guard.add(Uint8List.fromList([bytes[i]])), isTrue);
      }
      expect(guard.failure, isNull);
    });

    test('fails when continuation frames add up past the limit', () {
      final guard = WebSocketFrameGuard(maxMessageBytes: 250);
      expect(guard.add(httpHead), isTrue);
      expect(
        guard.add(Uint8List.fromList(frame(0x1, 125, fin: false))),
        isTrue,
      );
      expect(
        guard.add(Uint8List.fromList(frame(0x0, 125, fin: false))),
        isTrue,
      );
      expect(guard.add(Uint8List.fromList(frame(0x0, 1))), isFalse);
      expect(guard.failure, 'message too large');
      expect(guard.failedAt, 251);
      expect(guard.add(Uint8List(1)), isFalse);
    });

    test('fails on a single frame header that claims too much', () {
      final guard = WebSocketFrameGuard(maxMessageBytes: 1000);
      // FIN + text, masked, 64-bit length 2^40, then the mask key.
      final header = [0x81, 0xFF, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      expect(guard.add(Uint8List.fromList([...httpHead, ...header])), isFalse);
    });

    test('fails on a control frame over 125 bytes or a negative length', () {
      final ping = WebSocketFrameGuard(maxMessageBytes: 1000);
      expect(ping.add(httpHead), isTrue);
      expect(ping.add(Uint8List.fromList([0x89, 0x80 | 126, 0, 126])), isFalse);
      expect(ping.failure, 'control frame too large');
      // A close frame claiming a 64-bit length with the top bit set.
      final close = WebSocketFrameGuard(maxMessageBytes: 1000);
      final header = [0x88, 0xFF, 0x80, 0, 0, 0, 0, 0, 0, 0];
      expect(close.add(Uint8List.fromList([...httpHead, ...header])), isFalse);
      expect(close.failure, 'bad length');
    });

    test('fails on an endless HTTP header block', () {
      final guard = WebSocketFrameGuard(
        maxMessageBytes: 10,
        maxHeaderBytes: 64,
      );
      expect(guard.add(Uint8List.fromList(List.filled(65, 0x41))), isFalse);
      expect(guard.failure, 'header block too large');
    });
  });

  group('LanJoinInfo', () {
    test('round-trips through an address', () {
      const info = LanJoinInfo(
        host: '192.168.1.20',
        port: 4710,
        joinCode: 'K7Q2MX',
      );
      expect(info.address.value, 'ws://192.168.1.20:4710/join?code=K7Q2MX');
      final back = LanJoinInfo.parse(info.address);
      expect(
        [back.host, back.port, back.joinCode],
        ['192.168.1.20', 4710, 'K7Q2MX'],
      );
    });

    test('refuses other addresses', () {
      for (final bad in [
        'host',
        'http://h:1/join?code=A',
        'ws://h/join?code=A',
        'ws://h:1/other?code=A',
        'ws://h:1/join',
      ]) {
        expect(() => LanJoinInfo.parse(Address(bad)), throwsFormatException);
      }
    });

    test('join codes avoid look-alike characters', () {
      final code = newJoinCode(random: Random(1), length: 200);
      expect(code, hasLength(200));
      expect(code, isNot(matches(RegExp('[01OIL]'))));
    });
  });

  group('LAN transport over loopback', () {
    late LanHostTransport host;
    late DiagnosticLog hostLog;
    late StreamIterator<Link> accepted;

    setUp(() async {
      hostLog = DiagnosticLog(clock: FakeClock());
      host = await LanHostTransport.bind(
        address: InternetAddress.loopbackIPv4,
        joinCode: 'ABC234',
        diagnostics: hostLog,
      );
      accepted = StreamIterator(host.incoming());
    });
    tearDown(() => host.close());

    Address joinAddress() => host.joinInfo('127.0.0.1').address;

    Future<Link> nextLink() async {
      expect(await accepted.moveNext(), isTrue);
      return accepted.current;
    }

    List<String> kinds() => [for (final e in hostLog.entries) e.kind];

    test('frames arrive in order both ways, and close ends them', () async {
      final client = await const LanClientTransport().connect(joinAddress());
      final server = await nextLink();
      final atHost = <String>[];
      final hostDone = Completer<void>();
      server.frames.listen(atHost.add, onDone: hostDone.complete);
      final atClient = StreamIterator(client.frames);

      await client.send('a');
      await client.send('é ✓ 𝄞');
      await server.send('c');
      expect(await atClient.moveNext(), isTrue);
      expect(atClient.current, 'c');

      await client.close();
      await hostDone.future.timeout(const Duration(seconds: 5));
      expect(atHost, ['a', 'é ✓ 𝄞']);
      await expectLater(client.send('x'), throwsStateError);
    });

    test('a wrong join code is ConnectRefused, never a link', () async {
      final wrong = LanJoinInfo(
        host: '127.0.0.1',
        port: host.port,
        joinCode: 'WRONG2',
      ).address;
      await expectLater(
        const LanClientTransport().connect(wrong),
        throwsA(
          isA<ConnectRefused>().having((e) => e.reason, 'reason', 'joinCode'),
        ),
      );
      expect(kinds(), contains('lan.refused'));
    });

    test('a link never sends a frame over the codec limit', () async {
      final client = await const LanClientTransport().connect(joinAddress());
      await nextLink();
      expect(
        () => client.send('x' * (maxFrameLength + 1)),
        throwsArgumentError,
      );
      await client.close();
    });

    test('an over-long frame is dropped and logged; the link stays', () async {
      final raw = await WebSocket.connect(
        joinAddress().value,
        compression: CompressionOptions.compressionOff,
      );
      final server = await nextLink();
      final frames = StreamIterator(server.frames);
      raw.add('x' * (maxFrameLength + 1));
      raw.add('after');
      expect(await frames.moveNext(), isTrue);
      expect(frames.current, 'after');
      expect(kinds(), contains('lan.oversize'));
      await raw.close();
    });

    test('a fragmented message past the byte cap closes the socket', () async {
      final socket = await Socket.connect('127.0.0.1', host.port);
      socket.write(
        'GET /join?code=ABC234 HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
        'Sec-WebSocket-Version: 13\r\n\r\n',
      );
      final closed = Completer<void>();
      socket.listen(
        (_) {},
        onDone: closed.complete,
        onError: (Object _) {
          if (!closed.isCompleted) closed.complete();
        },
      );
      final server = await nextLink();
      final serverDone = Completer<void>();
      server.frames.listen((_) {}, onDone: serverDone.complete);

      const chunk = 64 * 1024;
      var sent = 0;
      var first = true;
      try {
        while (sent <= maxFrameBytes && !closed.isCompleted) {
          socket.add(frame(first ? 0x1 : 0x0, chunk, fin: false));
          first = false;
          sent += chunk;
          await socket.flush();
        }
      } on SocketException {
        // The host closed the socket mid-write.
      }
      await closed.future.timeout(const Duration(seconds: 10));
      await serverDone.future.timeout(const Duration(seconds: 10));
      expect(
        hostLog.entries.where((e) => e.kind == 'lan.oversize').single.fields,
        containsPair('reason', 'message too large'),
      );
      socket.destroy();
    });
  });
}
