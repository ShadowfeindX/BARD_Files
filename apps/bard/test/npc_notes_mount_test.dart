import 'dart:io';

import 'package:backend/backend.dart';
import 'package:bard/app/composition.dart';
import 'package:bard/app/routes.dart';
import 'package:bard/data/services/episode_projection.dart';
import 'package:bard/data/services/session_episode_service.dart';
import 'package:bard/main.dart';
import 'package:engine/engine.dart' show loadPack;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support/fake_episode_service.dart';

/// The generated pack, read from disk (needs `bash tool/build_pack.sh`).
Map<String, String> _packFiles() {
  final root = Directory(
    '../../packages/content_core/assets/generated/example-core',
  );
  return {
    for (final f in root.listSync(recursive: true).whereType<File>())
      f.path.substring(root.path.length + 1).replaceAll(r'\', '/'): f
          .readAsStringSync(),
  };
}

void main() {
  final packFiles = _packFiles();
  final pack = loadPack(packFiles).pack!;

  group('buildNpcNotes', () {
    test('lists the pack NPCs and the agents, and sends as the NPC', () async {
      final local = await LocalData.inMemory();
      addTearDown(local.close);
      final service = await SessionEpisodeService.open(packFiles);
      addTearDown(service.dispose);
      final c = Composition(episode: service, local: local, pack: service.pack);

      final model = buildNpcNotes(c)!;
      expect(model.campaignId, demoCampaignId);
      expect(
        [for (final n in model.npcs) n.id],
        [for (final n in pack.npcs) n.id],
      );
      expect(
        [for (final a in untracked(() => model.aliases.value)) a.id],
        ['vale', 'quill'],
      );
      expect(model.sendAs, isNotNull);

      final npc = pack.npcs.first;
      expect(await model.sendAs!(npc.id, 'vale', 'We need to talk.'), isNull);
      final thread = untracked(() => service.playerPhone('vale').value)
          .firstWhere((t) => t.id.startsWith('npc:'));
      expect(thread.title, EpisodeProjection.unknownNumber);
      expect(thread.messages.single.text, 'We need to talk.');
    });

    test('notes written through the panel model land in the store', () async {
      final local = await LocalData.inMemory();
      addTearDown(local.close);
      final c = Composition(
        episode: FakeEpisodeService(),
        local: local,
        pack: pack,
      );
      final model = buildNpcNotes(c)!;
      final npc = pack.npcs.first.id;
      await model.select(npc);
      expect(await model.pin('Owes the Bureau'), isTrue);
      expect((await local.notes.notes(demoCampaignId, npc)).pinned, [
        'Owes the Bureau',
      ]);
      // The fake has no NPC send, so the panel only edits.
      expect(model.sendAs, isNull);
    });

    test('a hosting machine has the panel', () async {
      final local = await LocalData.inMemory();
      addTearDown(local.close);
      final model = buildNpcNotes(
        Composition(
          episode: FakeEpisodeService(),
          mode: PlayMode.host,
          local: local,
          pack: pack,
        ),
      );
      expect(model, isNotNull);
    });

    test(
      'there is no panel without local data or on a joined machine',
      () async {
        expect(
          buildNpcNotes(Composition(episode: FakeEpisodeService(), pack: pack)),
          isNull,
        );
        final local = await LocalData.inMemory();
        addTearDown(local.close);
        expect(
          buildNpcNotes(
            Composition(
              episode: FakeEpisodeService(),
              mode: PlayMode.join,
              local: local,
              pack: pack,
            ),
          ),
          isNull,
        );
      },
    );
  });

  testWidgets('the console shows the notes panel when local data is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final local = (await tester.runAsync(LocalData.inMemory))!;
    final appearance = (await tester.runAsync(
      () => ThemeController.load(rootBundle),
    ))!;
    await tester.pumpWidget(
      BardApp(
        composition: Composition(
          episode: FakeEpisodeService(),
          local: local,
          pack: pack,
        ),
        appearance: appearance,
        local: local,
      ),
    );
    await tester.pumpAndSettle();
    // The console's tool column builds lazily, so scroll to the slot.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('npc-notes-picker')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('console-tools')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('npc-notes-picker')), findsOneWidget);
  });

  testWidgets('without local data the console has no notes panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appearance = (await tester.runAsync(
      () => ThemeController.load(rootBundle),
    ))!;
    await tester.pumpWidget(
      BardApp(
        composition: Composition(episode: FakeEpisodeService(), pack: pack),
        appearance: appearance,
      ),
    );
    await tester.pumpAndSettle();
    // Scroll the whole tool column so a lazily built panel would be found.
    await tester.drag(
      find.byKey(const ValueKey('console-tools')),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('npc-notes-picker')), findsNothing);
  });
}
