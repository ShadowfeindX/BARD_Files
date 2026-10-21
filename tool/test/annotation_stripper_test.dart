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

    test('an object that held only annotations becomes null (pending D)', () {
      final report = StripReport();
      final out = stripAnnotations({
        'basis': {'placeholder': true, 'gap': 'G1', 'note': 'n'},
        'rows': [
          {'_wrapper': 'x'},
          <String, Object?>{},
        ],
      }, report);
      expect(out, {
        'basis': null,
        'rows': [null, <String, Object?>{}],
      });
      expect(report.pending, [r'$.basis', r'$.rows[0]']);
    });

    test('a key starting with an underscore is an annotation', () {
      final report = StripReport();
      final out = stripAnnotations({
        'v': 1,
        '_note': 'n',
        '_attributePlaceholder': {'placeholder': true},
      }, report);
      expect(out, {'v': 1});
      expect(report.removed, 2);
      expect(report.pending, isEmpty);
    });

    test('keeps the note inside a deprecation record', () {
      final record = {'since': '1.5.0', 'removeIn': 2, 'note': 'kept'};
      final out = stripAnnotations({'deprecated': record}, StripReport());
      expect(out, {'deprecated': record});
    });

    test('reports annotation-like keys that are not in the spec list', () {
      final report = StripReport();
      final out = stripAnnotations({'gapFill': 1, 'xNOTE': 2}, report);
      expect(out, {'gapFill': 1, 'xNOTE': 2});
      expect(report.suspected, [r'$.gapFill', r'$.xNOTE']);
    });
  });

  group('checkPack', () {
    late Directory dir;
    late Directory source;
    late Directory target;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('strip_check');
      source = Directory('${dir.path}/in')..createSync();
      target = Directory('${dir.path}/out');
      File('${source.path}/a.json').writeAsStringSync('{"v":1,"note":"n"}');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a freshly built pack is current', () {
      stripPack(source, target);
      expect(checkPack(source, target), isEmpty);
    });

    test('a missing target, stale file and extra file are reported', () {
      expect(checkPack(source, target), hasLength(1));
      stripPack(source, target);
      File('${source.path}/a.json').writeAsStringSync('{"v":2}');
      expect(checkPack(source, target), ['a.json is out of date']);
      stripPack(source, target);
      File('${target.path}/stray.json').writeAsStringSync('{}');
      expect(checkPack(source, target), [
        'stray.json is not in the source pack',
      ]);
    });

    test('rebuilding removes files deleted from the source', () {
      File('${source.path}/b.json').writeAsStringSync('{}');
      stripPack(source, target);
      File('${source.path}/b.json').deleteSync();
      stripPack(source, target);
      expect(File('${target.path}/b.json').existsSync(), isFalse);
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
