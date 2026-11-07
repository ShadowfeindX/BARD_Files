import 'dart:convert';

import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database db;
  late NpcNotesStore store;
  var n = 0;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('notes${n++}');
    store = NpcNotesStore(db);
  });
  tearDown(() => db.close());

  test('an NPC with nothing saved has empty notes', () async {
    final notes = await store.notes('c1', 'mara');
    expect(notes.isEmpty, isTrue);
    expect(notes.campaignId, 'c1');
    expect(await store.npcIdsWithNotes('c1'), isEmpty);
  });

  test('text, pinned details and prepared messages round-trip', () async {
    await store.setText('c1', 'mara', 'Lies about the key.');
    await store.pin('c1', 'mara', 'Owes the Bureau a favour');
    await store.pin('c1', 'mara', 'Afraid of dogs');
    await store.addPrepared('c1', 'mara', label: 'Warn', text: 'Leave now.');
    final notes = await store.notes('c1', 'mara');
    expect(notes.text, 'Lies about the key.');
    expect(notes.pinned, ['Owes the Bureau a favour', 'Afraid of dogs']);
    expect(notes.prepared.single.text, 'Leave now.');
    expect(notes.prepared.single.label, 'Warn');
  });

  test('notes are per campaign: the same NPC id does not collide', () async {
    await store.setText('c1', 'mara', 'one');
    await store.setText('c2', 'mara', 'two');
    expect((await store.notes('c1', 'mara')).text, 'one');
    expect((await store.notes('c2', 'mara')).text, 'two');
    expect(await store.npcIdsWithNotes('c1'), ['mara']);
  });

  test('ids that contain separators stay distinct', () async {
    await store.setText('a/b', 'c', 'x');
    await store.setText('a', 'b/c', 'y');
    expect((await store.notes('a/b', 'c')).text, 'x');
    expect((await store.notes('a', 'b/c')).text, 'y');
  });

  test('unpin removes by index and rejects a bad index', () async {
    await store.pin('c1', 'mara', 'a');
    await store.pin('c1', 'mara', 'b');
    expect((await store.unpin('c1', 'mara', 0)).pinned, ['b']);
    expect(() => store.unpin('c1', 'mara', 5), throwsRangeError);
    expect(() => store.pin('c1', 'mara', '  '), throwsArgumentError);
  });

  test('prepared ids are never reused after a delete', () async {
    await store.addPrepared('c1', 'mara', text: 'one');
    final second = await store.addPrepared('c1', 'mara', text: 'two');
    final firstId = second.prepared.first.id;
    await store.removePrepared('c1', 'mara', firstId);
    final third = await store.addPrepared('c1', 'mara', text: 'three');
    final ids = third.prepared.map((m) => m.id).toList();
    expect(ids, hasLength(2));
    expect(ids, isNot(contains(firstId)));
    expect(ids.toSet(), hasLength(2));
  });

  test('updatePrepared changes one message; unknown id throws', () async {
    final added = await store.addPrepared('c1', 'mara', text: 'old');
    final id = added.prepared.single.id;
    final updated = await store.updatePrepared(
      'c1',
      'mara',
      id,
      text: 'new',
      label: 'L',
    );
    expect(updated.prepared.single.text, 'new');
    expect(updated.prepared.single.label, 'L');
    expect(
      () => store.updatePrepared('c1', 'mara', 'nope', text: 'x'),
      throwsStateError,
    );
    expect(() => store.removePrepared('c1', 'mara', 'nope'), throwsStateError);
  });

  test('prepared text is held to the phone limit', () async {
    expect(
      () => store.addPrepared('c1', 'mara', text: ''),
      throwsArgumentError,
    );
    expect(
      () => store.addPrepared(
        'c1',
        'mara',
        text: 'x' * (maxPreparedMessageUnits + 1),
      ),
      throwsArgumentError,
    );
    final ok = await store.addPrepared(
      'c1',
      'mara',
      text: 'x' * maxPreparedMessageUnits,
    );
    expect(ok.prepared, hasLength(1));
  });

  test('quick concurrent edits do not lose each other', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++) store.pin('c1', 'mara', 'p$i'),
    ]);
    expect((await store.notes('c1', 'mara')).pinned, hasLength(10));
  });

  test('delete removes one NPC or a whole campaign', () async {
    await store.setText('c1', 'mara', 'a');
    await store.setText('c1', 'ellis', 'b');
    await store.setText('c2', 'mara', 'c');
    expect(await store.npcIdsWithNotes('c1'), ['ellis', 'mara']);
    await store.deleteNpc('c1', 'mara');
    expect(await store.npcIdsWithNotes('c1'), ['ellis']);
    await store.deleteCampaign('c1');
    expect(await store.npcIdsWithNotes('c1'), isEmpty);
    expect((await store.notes('c2', 'mara')).text, 'c');
  });

  test('export covers one campaign, sorted, and decodes as JSON', () async {
    await store.setText('c1', 'mara', 'a');
    await store.setText('c1', 'ellis', 'b');
    await store.setText('c2', 'zed', 'other');
    final json = jsonDecode(await store.exportCampaignJson('c1'));
    expect(json['campaignId'], 'c1');
    final npcs = (json['npcs'] as List).cast<Map<String, dynamic>>();
    expect(npcs.map((e) => e['npcId']), ['ellis', 'mara']);
    expect(jsonEncode(json), isNot(contains('other')));
  });

  test('a row this version cannot read counts as no notes', () async {
    final raw = stringMapStoreFactory.store('npcNotes');
    await raw.record(jsonEncode(['c1', 'mara'])).put(db, {'junk': 1});
    expect((await store.notes('c1', 'mara')).isEmpty, isTrue);
    expect((await store.setText('c1', 'mara', 'fresh')).text, 'fresh');
  });

  test('notes survive closing and reopening the database', () async {
    final factory = newDatabaseFactoryMemory();
    var d = await factory.openDatabase('persist');
    await NpcNotesStore(d).setText('c1', 'mara', 'kept');
    await d.close();
    d = await factory.openDatabase('persist');
    expect((await NpcNotesStore(d).notes('c1', 'mara')).text, 'kept');
    await d.close();
  });

  test('unreadable rows are skipped by the list and the export', () async {
    final raw = stringMapStoreFactory.store('npcNotes');
    await raw.record(jsonEncode(['c1', 'bad'])).put(db, {
      'campaignId': 'c1',
      'npcId': 'bad',
      'junk': 1,
    });
    await store.setText('c1', 'mara', 'a');
    expect(await store.npcIdsWithNotes('c1'), ['mara']);
    final export = await store.exportCampaign('c1');
    expect((export['npcs'] as List), hasLength(1));
  });

  test('cleared notes are not listed', () async {
    await store.setText('c1', 'mara', 'a');
    await store.setText('c1', 'mara', '');
    expect(await store.npcIdsWithNotes('c1'), isEmpty);
  });

  test('a row from a newer build is not overwritten', () async {
    final raw = stringMapStoreFactory.store('npcNotes');
    final key = jsonEncode(['c1', 'mara']);
    await raw.record(key).put(db, {'version': 99, 'campaignId': 'c1'});
    await expectLater(store.setText('c1', 'mara', 'x'), throwsStateError);
    expect((await raw.record(key).get(db))!['version'], 99);
  });

  test('bad arguments fail inside the future', () async {
    await expectLater(store.pin('c1', 'mara', ''), throwsArgumentError);
    await expectLater(store.unpin('c1', 'mara', 3), throwsRangeError);
  });
}
