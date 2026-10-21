import 'dart:convert';

import 'package:engine/src/pack/load/sha256.dart';
import 'package:test/test.dart';

/// FIPS 180-4 examples, plus vectors from Python's hashlib for padding edge
/// cases (55, 56 and 64 bytes), all byte values, and UTF-8 text. Run on the VM
/// and on Node.js.
void main() {
  String hex(String text) => sha256Hex(utf8.encode(text));

  test('standard vectors', () {
    expect(
      hex(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('padding edges', () {
    expect(
      hex('x' * 55),
      'd5e285683cd4efc02d021a5c62014694958901005d6f71e89e0989fac77e4072',
    );
    expect(
      hex('x' * 56),
      '04c26261370ee7541549d16dee320c723e3fd14671e66a099afe0a377c16888e',
    );
    expect(
      hex('x' * 64),
      '7ce100971f64e7001e8fe5a51973ecdfe1ced42befe7ee8d5fd6219506b5393c',
    );
  });

  test('every byte value, and UTF-8 text', () {
    expect(
      sha256Hex([for (var r = 0; r < 3; r++) ...List.generate(256, (i) => i)]),
      'f3a25aa93aa2fbba28d79260535bbd6a5eb0fc1c24a8b0f04e12b484c1dfe363',
    );
    expect(
      hex('Cat-Ω ∞'),
      '2bb038ed4cafb51094d51358c03302d7c2b4cdf97240ea08a0eb2b44df53d9f0',
    );
  });

  test('a million bytes', () {
    expect(
      sha256Hex(List.filled(1000000, 0x61)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });
}
