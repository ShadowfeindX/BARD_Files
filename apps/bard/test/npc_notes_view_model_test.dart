import 'dart:async';

import 'package:backend/backend.dart';
import 'package:bard/data/services/npc_notes_service.dart';
import 'package:bard/ui/console/npc_notes_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  late NpcNotesStore store;

  setUp(() async => store = await NpcNotesStore.inMemory());

  NpcNotesViewModel model({
    SendAsNpc? sendAs,
    List<AliasOption> aliases = const [AliasOption(id: 'vale', name: 'Vale')],
  }) => NpcNotesViewModel(
    NpcNotesService(store),
    campaignId: 'c1',
    npcs: const [
      NpcOption(id: 'mara', name: 'Mara'),
      NpcOption(id: 'ellis', name: 'Ellis'),
    ],
    sendAs: sendAs,
    aliases: signal(aliases),
  );

  test('a late write for the previous NPC is not shown or misfiled', () async {
    final m = model();
    await m.select('mara');
    // Start a save, then switch before it finishes.
    final saving = m.saveText('Mara only');
    final switching = m.select('ellis');
    await saving;
    await switching;
    expect(m.notes.value!.npcId, 'ellis');
    expect(m.notes.value!.text, '');
    expect((await store.notes('c1', 'mara')).text, 'Mara only');
    expect((await store.notes('c1', 'ellis')).isEmpty, isTrue);
  });

  test('send is not repeated while one is in flight', () async {
    var calls = 0;
    final gate = Completer<String?>();
    final m = model(
      sendAs: (id, to, text) {
        calls++;
        return gate.future;
      },
    );
    await store.addPrepared('c1', 'mara', text: 'Go.');
    await m.select('mara');
    final a = m.send('m1');
    final b = m.send('m1');
    gate.complete('refused');
    await a;
    await b;
    expect(calls, 1);
    expect(m.error.value, 'refused');
  });

  test('a bad entry shows a message and keeps the notes', () async {
    final m = model();
    await m.select('mara');
    expect(await m.addPrepared(''), isFalse);
    expect(m.error.value, isNotNull);
    expect(await m.pin('Afraid of dogs'), isTrue);
    expect(m.error.value, isNull);
    expect(m.notes.value!.pinned, ['Afraid of dogs']);
  });

  test(
    'the only alias is the recipient; with none, send does nothing',
    () async {
      final seen = <String>[];
      Future<String?> send(String id, String to, String text) async {
        seen.add(to);
        return null;
      }

      await store.addPrepared('c1', 'mara', text: 'Go.');
      final one = model(sendAs: send);
      await one.select('mara');
      await one.send('m1');
      final none = model(sendAs: send, aliases: const []);
      await none.select('mara');
      await none.send('m1');
      expect(seen, ['vale']);
      expect(none.canSend, isFalse);
    },
  );
}
