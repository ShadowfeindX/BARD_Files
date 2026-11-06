import 'dart:convert';
import 'dart:io';

import 'package:bard_tool/diagnostic_pack.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Directory core;
  late Directory overlay;

  void write(Directory root, String path, Object json) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('diagnostic_pack_test');
    core = Directory('${temp.path}/core')..createSync();
    overlay = Directory('${temp.path}/overlay')..createSync();
    write(core, 'manifest.json', {'id': 'core'});
    write(core, 'skills.json', {'skills': <String>[]});
    write(core, 'strings/en.json', {'language': 'en', 'a': 'core text'});
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('replaces the manifest, adds files and merges strings', () {
    write(overlay, 'manifest.json', {'id': 'diagnostic'});
    write(overlay, 'npcs/one.json', {'id': 'one'});
    write(overlay, 'strings/en.json', {'language': 'en', 'b': 'overlay text'});
    final files = diagnosticPackFiles(core, overlay);
    expect(jsonDecode(files['manifest.json']!), {'id': 'diagnostic'});
    expect(files.keys, contains('npcs/one.json'));
    expect(files['skills.json'], jsonEncode({'skills': <String>[]}));
    expect(jsonDecode(files['strings/en.json']!), {
      'language': 'en',
      'a': 'core text',
      'b': 'overlay text',
    });
  });

  test('refuses to override a core rule file', () {
    write(overlay, 'skills.json', {
      'skills': ['x'],
    });
    expect(() => diagnosticPackFiles(core, overlay), throwsArgumentError);
  });

  test('refuses a repeated string key', () {
    write(overlay, 'strings/en.json', {'language': 'en', 'a': 'again'});
    expect(() => diagnosticPackFiles(core, overlay), throwsArgumentError);
  });

  test('check reports missing, stale and extra files', () {
    write(overlay, 'npcs/one.json', {'id': 'one'});
    final files = diagnosticPackFiles(core, overlay);
    final target = Directory('${temp.path}/out');
    expect(checkDiagnosticPack(files, target), isNotEmpty);
    writeDiagnosticPack(files, target);
    expect(checkDiagnosticPack(files, target), isEmpty);
    File('${target.path}/npcs/one.json').writeAsStringSync('{}');
    File('${target.path}/extra.json').writeAsStringSync('{}');
    expect(checkDiagnosticPack(files, target), hasLength(2));
  });
}
