/// SHA-256 (FIPS 180-4), written out because the engine may import only the
/// Dart SDK, which has no hash functions.
///
/// It is used for pack content hashes only, not for security. Every
/// intermediate is masked to 32 bits and stays below 2^53, so the result is
/// the same on the VM and the web; tests pin the standard test vectors on
/// both.
library;

/// The SHA-256 digest of [bytes] as 64 lowercase hexadecimal digits.
String sha256Hex(List<int> bytes) {
  final hash = List<int>.of(_initial);
  final words = List<int>.filled(64, 0);
  for (final block in _blocks(bytes)) {
    for (var t = 0; t < 16; t++) {
      words[t] =
          (block[4 * t] << 24 |
              block[4 * t + 1] << 16 |
              block[4 * t + 2] << 8 |
              block[4 * t + 3]) &
          _mask;
    }
    for (var t = 16; t < 64; t++) {
      words[t] =
          (_smallSigma1(words[t - 2]) +
              words[t - 7] +
              _smallSigma0(words[t - 15]) +
              words[t - 16]) &
          _mask;
    }
    var a = hash[0], b = hash[1], c = hash[2], d = hash[3];
    var e = hash[4], f = hash[5], g = hash[6], h = hash[7];
    for (var t = 0; t < 64; t++) {
      final t1 =
          (h + _bigSigma1(e) + _choose(e, f, g) + _k[t] + words[t]) & _mask;
      final t2 = (_bigSigma0(a) + _majority(a, b, c)) & _mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    hash[0] = (hash[0] + a) & _mask;
    hash[1] = (hash[1] + b) & _mask;
    hash[2] = (hash[2] + c) & _mask;
    hash[3] = (hash[3] + d) & _mask;
    hash[4] = (hash[4] + e) & _mask;
    hash[5] = (hash[5] + f) & _mask;
    hash[6] = (hash[6] + g) & _mask;
    hash[7] = (hash[7] + h) & _mask;
  }
  return hash.map((w) => w.toRadixString(16).padLeft(8, '0')).join();
}

/// [bytes] padded as the standard requires and split into 64-byte blocks.
Iterable<List<int>> _blocks(List<int> bytes) sync* {
  final padded = <int>[...bytes, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  // Message length in bits as a 64-bit big-endian number. Split into two
  // 32-bit halves with arithmetic, since shifts truncate to 32 bits on the
  // web.
  final bits = bytes.length * 8;
  final high = bits ~/ 0x100000000;
  final low = bits % 0x100000000;
  for (final half in [high, low]) {
    padded.addAll([half >> 24 & 0xff, half >> 16 & 0xff, half >> 8 & 0xff]);
    padded.add(half & 0xff);
  }
  for (var i = 0; i < padded.length; i += 64) {
    yield padded.sublist(i, i + 64);
  }
}

const _mask = 0xffffffff;

int _rotr(int x, int n) => (x >> n | x << (32 - n)) & _mask;

int _choose(int x, int y, int z) => (x & y) ^ (~x & _mask & z);

int _majority(int x, int y, int z) => (x & y) ^ (x & z) ^ (y & z);

int _bigSigma0(int x) => _rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22);

int _bigSigma1(int x) => _rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25);

int _smallSigma0(int x) => _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);

int _smallSigma1(int x) => _rotr(x, 17) ^ _rotr(x, 19) ^ (x >> 10);

const _initial = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
