import 'dart:convert';
import 'dart:io';

import 'package:bard_tool/annotation_stripper.dart';
import 'package:test/test.dart';

void main() {
  group('stripAnnotations', () {
    test('removes listed keys and *Note keys at any depth', () {
      final report = StripReport();
      final out = stripAnnotations({
        'dc': 3,
        'source': 'Rulebook p11',
        'xpNote': 'x',
        'rows': [
          {
            'id': 'a',
            'gap': 'G1',
            'openItems': <String>[],
            'placeholder': true,
          },
        ],
      }, report);
      expect(out, {
        'dc': 3,
        'rows': [
          {'id': 'a'},
        ],
      });
      expect(report.removed, 5);
    });

    test('keeps null values (null means pending D)', () {
      final out = stripAnnotations({
        'explode': null,
        'note': 'n',
      }, StripReport());
      expect(out, {'explode': null});
    });

    test('reports an object left empty instead of dropping it', () {
      final report = StripReport();
      final out = stripAnnotations({
        'basis': {'placeholder': true, 'gap': 'G1', 'note': 'n'},
      }, report);
      expect(out, {'basis': <String, Object?>{}});
      expect(report.emptied, [r'$.basis']);
    });

    test('keeps the note inside a deprecation record', () {
      final record = {'since': '1.5.0', 'removeIn': 2, 'note': 'kept'};
      final out = stripAnnotations({'deprecated': record}, StripReport());
      expect(out, {'deprecated': record});
    });

    test('reports annotation-like keys that are not in the spec list', () {
      final report = StripReport();
      final out = stripAnnotations({
        '_note': 'x',
        'attributePlaceholder': {'placeholder': true},
      }, report);
      expect(out, containsPair('_note', 'x'));
      expect(report.suspected, [r'$._note', r'$.attributePlaceholder']);
    });
  });

  test('stripPack writes stripped json and skips other files', () {
    final dir = Directory.systemTemp.createTempSync('strip_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = Directory('${dir.path}/in/sub')..createSync(recursive: true);
    File('${dir.path}/in/a.json').writeAsStringSync('{"v":1,"note":"n"}');
    File('${dir.path}/in/sub/b.json').writeAsStringSync('[{"gap":"G1","v":2}]');
    File('${dir.path}/in/README.md').writeAsStringSync('hi');
    final reports = stripPack(
      Directory('${dir.path}/in'),
      Directory('${dir.path}/out'),
    );
    expect(reports.keys, unorderedEquals(['a.json', 'sub/b.json']));
    expect(jsonDecode(File('${dir.path}/out/a.json').readAsStringSync()), {
      'v': 1,
    });
    expect(jsonDecode(File('${dir.path}/out/sub/b.json').readAsStringSync()), [
      {'v': 2},
    ]);
    expect(File('${dir.path}/out/README.md').existsSync(), isFalse);
    expect(source.existsSync(), isTrue);
  });
}
