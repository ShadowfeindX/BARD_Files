import 'dart:math' show Random;

import 'package:session/session.dart';
import 'package:test/test.dart';
import 'package:xrandom/xrandom.dart' show Xoshiro128pp;

/// Known-seed vectors (P5). Every expected number below was produced by the
/// reference C implementation of Xoshiro128++ (prng.di.unimi.it,
/// xoshiro128plusplus.c) with the same rejection-sampling die as
/// [XoshiroRng], not by this package. The program is kept in the project
/// library under `probes/xoshiro128pp-vectors/`. These tests run on the VM
/// and on the web (`dart test -p node`); if either sequence ever changes, the
/// build fails.
void main() {
  final seed = RngSeed(0x9E3779B9, 0x243F6A88, 0xB7E15162, 0xDEADBEEF);

  test('xrandom Xoshiro128pp raw output matches C for seed (1, 2, 3, 4)', () {
    final generator = Xoshiro128pp(1, 2, 3, 4);
    expect(List.generate(10, (_) => generator.nextRaw32()), [
      641, 1573767, 3222811527, 3517856514, 836907274, //
      4247214768, 3867114732, 1355841295, 495546011, 621204420,
    ]);
  });

  test('xrandom Xoshiro128pp raw output matches C for a second seed', () {
    final generator = Xoshiro128pp(seed.a, seed.b, seed.c, seed.d);
    expect(List.generate(10, (_) => generator.nextRaw32()), [
      282316279, 152864603, 3992349186, 1721490733, 3563439362, //
      2491810143, 4241777144, 1579400132, 266639861, 2739135226,
    ]);
  });

  test('dice faces match C', () {
    final rng = XoshiroRng(seed);
    final sides = [6, 4, 6, 20, 3, 6, 100, 2, 6, 6, 4, 12];
    expect(
      [for (final s in sides) rng.rollDie(s)],
      [2, 4, 1, 14, 3, 4, 45, 1, 6, 5, 2, 4],
    );
    expect(rng.drawCount, 12);
  });

  test('rejected draws are counted and redrawn', () {
    // 1431655766 sides rejects raw values >= 2863311532, about a third.
    final rng = XoshiroRng(RngSeed(1, 2, 3, 4));
    expect(List.generate(5, (_) => rng.rollDie(1431655766)), [
      642,
      1573768,
      836907275,
      1355841296,
      495546012,
    ]);
    expect(rng.drawCount, 9);
  });

  test('reopening at a draw count continues the same sequence', () {
    final first = XoshiroRng(seed);
    for (var i = 0; i < 5; i++) {
      first.rollDie(6);
    }
    final reopened = XoshiroRng(seed, drawCount: first.drawCount);
    expect(
      List.generate(20, (_) => reopened.rollDie(6)),
      List.generate(20, (_) => first.rollDie(6)),
    );
    expect(reopened.drawCount, first.drawCount);
  });

  test('a d1 always shows 1 and still draws', () {
    final rng = XoshiroRng(seed);
    expect(List.generate(3, (_) => rng.rollDie(1)), [1, 1, 1]);
    expect(rng.drawCount, 3);
  });

  test('invalid arguments', () {
    expect(() => XoshiroRng(seed).rollDie(0), throwsRangeError);
    expect(() => XoshiroRng(seed, drawCount: -1), throwsRangeError);
  });

  group('RngSeed', () {
    test('hex round trip', () {
      expect(seed.toHex(), '9e3779b9243f6a88b7e15162deadbeef');
      expect(RngSeed.parseHex(seed.toHex()), seed);
      expect(
        RngSeed.parseHex(
          '0000000100000002000000030000000'
          '4',
        ),
        RngSeed(1, 2, 3, 4),
      );
    });

    test('rejects all zeros, out-of-range words and bad hex', () {
      expect(() => RngSeed(0, 0, 0, 0), throwsArgumentError);
      expect(() => RngSeed(4294967296, 0, 0, 1), throwsRangeError);
      expect(() => RngSeed(-1, 0, 0, 1), throwsRangeError);
      expect(() => RngSeed.parseHex('xyz'), throwsFormatException);
      expect(() => RngSeed.parseHex('0' * 32), throwsArgumentError);
    });

    test('generate uses the given source and never returns all zeros', () {
      expect(RngSeed.generate(Random(1)), RngSeed.generate(Random(1)));
    });

    // Random.secure() works in browsers and on the VM, but the Node.js test
    // runner cannot reach its crypto object, so this one is skipped there.
    test('generate defaults to a secure source', () {
      expect(RngSeed.generate(), isA<RngSeed>());
    }, testOn: '!node');

    test('toString hides the words', () {
      expect(seed.toString(), isNot(contains('9e3779b9')));
    });
  });
}
