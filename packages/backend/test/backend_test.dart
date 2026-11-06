import 'dart:convert';
import 'dart:io';

import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:session/session.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('bard_backend_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('the file sink appends one JSON line per entry', () {
    final file = File('${temp.path}/logs/op1.diagnostic.jsonl');
    final sink = DiagnosticFileSink(file);
    final log = DiagnosticLog(clock: FakeClock(), sinks: [sink])
      ..record(DiagnosticCategory.network, 'a', {'seq': 1})
      ..record(DiagnosticCategory.request, 'b', {'text': 'hidden'});
    final lines = const LineSplitter().convert(file.readAsStringSync());
    expect(lines, hasLength(2));
    expect(jsonDecode(lines.first)['kind'], 'a');
    expect(lines.last, isNot(contains('hidden')));
    expect(log.entries, hasLength(2));
    expect(sink.failed, isFalse);
  });

  test('the file sink never throws; it stops and says so', () {
    final dir = Directory('${temp.path}/blocked')..createSync();
    // A directory where the file should be: every write fails.
    final sink = DiagnosticFileSink(File(dir.path));
    DiagnosticLog(clock: FakeClock(), sinks: [sink])
      ..record(DiagnosticCategory.network, 'a')
      ..record(DiagnosticCategory.network, 'b');
    expect(sink.failed, isTrue);
  });

  test('the bundle is written as separate files in a new folder', () async {
    final bundle = ReportBundle(
      episodeId: 'op1',
      createdAt: DateTime.utc(2026, 11, 6, 12),
      files: {'game-log.jsonl': '{}\n', 'diagnostic-log.jsonl': '{}\n'},
    );
    final first = await writeReportBundle(bundle, temp);
    final second = await writeReportBundle(bundle, temp);
    expect(first.path, isNot(second.path));
    expect(second.path, endsWith('-2'));
    expect(File('${first.path}/game-log.jsonl').readAsStringSync(), '{}\n');
    expect(File('${first.path}/diagnostic-log.jsonl').existsSync(), isTrue);
  });

  test('a file name that could leave the folder is refused', () {
    final bundle = ReportBundle(
      episodeId: 'op1',
      createdAt: DateTime.utc(2026),
      files: {'../evil': 'x'},
    );
    expect(writeReportBundle(bundle, temp), throwsArgumentError);
  });
}
