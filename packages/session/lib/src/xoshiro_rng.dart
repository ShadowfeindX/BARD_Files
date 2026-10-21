import 'dart:math' show Random;

import 'package:engine/engine.dart';
import 'package:xrandom/xrandom.dart' show Xoshiro128pp;

/// The 128-bit seed of an operation's RNG: four 32-bit words, not all zero.
///
/// GM-only data: it never leaves the GM's device (01 §RNG).
final class RngSeed {
  /// Creates a seed from four words in `0..0xFFFFFFFF`.
  ///
  /// Throws an [ArgumentError] when a word is out of range or all are zero
  /// (Xoshiro128++ would then only ever return zero).
  RngSeed(this.a, this.b, this.c, this.d) {
    for (final word in [a, b, c, d]) {
      RangeError.checkValueInInterval(word, 0, _maxWord, 'word');
    }
    if (a == 0 && b == 0 && c == 0 && d == 0) {
      throw ArgumentError('A seed may not be all zeros.');
    }
  }

  /// Creates a fresh seed from [source], by default `Random.secure()`.
  factory RngSeed.generate([Random? source]) {
    final random = source ?? Random.secure();
    while (true) {
      final words = List.generate(4, (_) => random.nextInt(_wordRange));
      if (words.any((w) => w != 0)) {
        return RngSeed(words[0], words[1], words[2], words[3]);
      }
    }
  }

  /// Reads a seed written by [toHex].
  ///
  /// Throws a [FormatException] unless [hex] is 32 hexadecimal digits.
  factory RngSeed.parseHex(String hex) {
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hex)) {
      throw FormatException('Expected 32 hexadecimal digits.', hex);
    }
    int word(int i) => int.parse(hex.substring(i * 8, i * 8 + 8), radix: 16);
    return RngSeed(word(0), word(1), word(2), word(3));
  }

  /// First state word.
  final int a;

  /// Second state word.
  final int b;

  /// Third state word.
  final int c;

  /// Fourth state word.
  final int d;

  /// The seed as 32 lowercase hexadecimal digits, words in order.
  String toHex() =>
      [a, b, c, d].map((w) => w.toRadixString(16).padLeft(8, '0')).join();

  @override
  bool operator ==(Object other) =>
      other is RngSeed &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d;

  @override
  int get hashCode => Object.hash(a, b, c, d);

  /// Does not print the words: the seed is GM-only.
  @override
  String toString() => 'RngSeed(<hidden>)';
}

/// The production [Rng]: `xrandom` 0.7.2's `Xoshiro128pp` (P5, 04 §RNG
/// adapter).
///
/// One draw is one 32-bit output of the generator. A die is rolled by
/// rejection sampling, so every face is equally likely: raw values at or
/// above the largest multiple of `sides` that is at most 2^32 are thrown away and drawn
/// again. Faces are computed with `%` and `<` only, never bit operators, so
/// the result is the same on the VM and the web [V-14].
///
/// The generator's own `nextInt` is not used, so a change to it in a later
/// `xrandom` version cannot change our sequence. The known-seed tests pin
/// both the raw outputs and the faces.
final class XoshiroRng implements Rng {
  /// Creates an RNG from [seed] that has already made [drawCount] draws.
  ///
  /// Reopening an operation passes the draw count from its state, and the
  /// generator is advanced to that point, so the next roll is the one that
  /// would have followed.
  XoshiroRng(RngSeed seed, {int drawCount = 0})
    : _generator = Xoshiro128pp(seed.a, seed.b, seed.c, seed.d) {
    RangeError.checkNotNegative(drawCount, 'drawCount');
    for (var i = 0; i < drawCount; i++) {
      _draw();
    }
  }

  final Xoshiro128pp _generator;
  int _drawCount = 0;

  @override
  int get drawCount => _drawCount;

  @override
  int rollDie(int sides) {
    RangeError.checkValueInInterval(sides, 1, _maxWord, 'sides');
    final limit = _wordRange - (_wordRange % sides);
    while (true) {
      final raw = _draw();
      if (raw < limit) return raw % sides + 1;
    }
  }

  int _draw() {
    _drawCount++;
    return _generator.nextRaw32();
  }
}

/// 2^32, written out because `1 << 32` is 0 on the web.
const _wordRange = 4294967296;

/// 2^32 - 1.
const _maxWord = 4294967295;
