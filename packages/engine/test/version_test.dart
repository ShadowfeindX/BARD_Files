@TestOn('vm')
library;

import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  test('engineVersion matches pubspec.yaml and engineApi its major', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(engineVersion, version);
    expect(engineApi, int.parse(engineVersion.split('.').first));
  });
}
