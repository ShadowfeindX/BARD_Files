import 'dart:convert';

import 'package:protocol/protocol.dart' hide PackPin, Rejected;
import 'package:session/session.dart';
import 'package:test/test.dart';

import 'support/rig.dart';

const env = EnvironmentInfo(
  appVersion: '0.0.0',
  engineVersion: '1.0.0-dev.1',
  protocolMajor: 1,
  os: 'linux',
  osVersion: 'test',
  flutterVersion: '3.47.7',
  dartVersion: '3.13.5',
  packId: 'p',
  packVersion: '1',
  packHash: 'h',
);

List<Map<String, Object?>> jsonl(String text) => [
  for (final line in const LineSplitter().convert(text))
    jsonDecode(line) as Map<String, Object?>,
];

void main() {
  late Rig rig;

  tearDown(() => rig.close());

  Future<ReportBundle> bundle({
    bool includeNotes = false,
    Future<JsonMap?> Function()? notes,
    int errorLimit = 50,
  }) => ReportBundleBuilder.build(
    episodeId: 'op1',
    store: rig.store,
    environment: env,
    settings: {'snapshotIntervalMinutes': 5, 'transport': 'lan', 'text': 'x'},
    log: rig.hostLog,
    clock: FakeClock(DateTime.utc(2026, 11, 6, 12, 30, 5)),
    includeNotes: includeNotes,
    notes: notes,
    recentErrorLimit: errorLimit,
    storeHealth: () async => {'ok': true},
  );

  test(
    'every log is its own file, and the game log can rebuild the state',
    () async {
      rig = await Rig.create();
      await rig.start();
      await rig.host.submit(rig.agent('Hall', owner: 'hall'));
      final b = await bundle();

      expect(
        b.files.keys,
        containsAll([
          'manifest.json',
          'environment.json',
          'settings.json',
          'diagnostic-log.jsonl',
          'network-trace.jsonl',
          'recent-errors.jsonl',
          'store-health.json',
          'game-log.jsonl',
          'text-log.jsonl',
          'snapshot.json',
        ]),
      );
      expect(jsonl(b.files['game-log.jsonl']!).map((e) => e['seq']), [1, 2]);
      expect(jsonl(b.files['text-log.jsonl']!), hasLength(2));
      final snapshot = jsonDecode(b.files['snapshot.json']!) as Map;
      expect(snapshot['seq'], 2);
      expect(snapshot['state'], isNotEmpty);
      // Game events are not copied into the diagnostic log.
      expect(b.files['diagnostic-log.jsonl'], isNot(contains('Hall')));
      expect(b.folderName, 'bard-report-op1-20261106T123005');
    },
  );

  test('the network trace holds only network entries', () async {
    rig = await Rig.create();
    await rig.start();
    await rig.join('ann', 'hall');
    final b = await bundle();
    final trace = jsonl(b.files['network-trace.jsonl']!);
    expect(trace, isNotEmpty);
    expect(trace.map((e) => e['category']).toSet(), {'network'});
    expect(trace.map((e) => e['kind']), contains('hello.joined'));
  });

  test('recent errors are capped to the newest', () async {
    rig = await Rig.create();
    for (var i = 0; i < 5; i++) {
      rig.hostLog.record(DiagnosticCategory.error, 'e', {'n': i});
    }
    final b = await bundle(errorLimit: 2);
    final errors = jsonl(b.files['recent-errors.jsonl']!);
    expect(errors.map((e) => (e['fields'] as Map)['n']), [3, 4]);
  });

  test('settings pass through the redactor', () async {
    rig = await Rig.create();
    final b = await bundle();
    final settings = jsonDecode(b.files['settings.json']!) as Map;
    expect(settings['snapshotIntervalMinutes'], 5);
    expect(settings['text'], Redactor.hidden);
  });

  test('notes are left out unless ticked, and never even read', () async {
    rig = await Rig.create();
    var read = false;
    Future<JsonMap?> notes() async {
      read = true;
      return {'npc': 'Handler-only text'};
    }

    final left = await bundle(notes: notes);
    expect(read, isFalse);
    expect(left.files, isNot(contains('notes.json')));
    expect(jsonDecode(left.files['manifest.json']!)['notesRequested'], isFalse);

    final ticked = await bundle(includeNotes: true, notes: notes);
    expect(read, isTrue);
    expect(ticked.files['notes.json'], contains('Handler-only text'));
    final manifest = jsonDecode(ticked.files['manifest.json']!) as Map;
    expect(manifest['notesIncluded'], isTrue);
  });

  test('an empty store gives an empty game log and no snapshot', () async {
    rig = await Rig.create();
    final b = await bundle();
    expect(b.files['game-log.jsonl'], isEmpty);
    expect(b.files, isNot(contains('snapshot.json')));
  });
}
