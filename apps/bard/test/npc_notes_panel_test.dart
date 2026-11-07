import 'package:backend/backend.dart';
import 'package:bard/data/services/npc_notes_service.dart';
import 'package:bard/ui/console/npc_notes_panel.dart';
import 'package:bard/ui/console/npc_notes_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  late NpcNotesStore store;
  final sent = <(String, String)>[];

  setUp(() async {
    sent.clear();
    store = await NpcNotesStore.inMemory();
  });

  NpcNotesViewModel model({bool canSend = true}) => NpcNotesViewModel(
    NpcNotesService(store),
    campaignId: 'c1',
    npcs: const [
      NpcOption(id: 'mara', name: 'Mara'),
      NpcOption(id: 'ellis', name: 'Ellis'),
    ],
    sendAs: canSend
        ? (id, text) async {
            sent.add((id, text));
            return null;
          }
        : null,
  );

  Future<void> pump(WidgetTester tester, NpcNotesViewModel m) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appearance = (await tester.runAsync(
      () => ThemeController.load(rootBundle),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: appearance.themeData.value,
        home: Scaffold(
          body: SingleChildScrollView(child: NpcNotesPanel(model: m)),
        ),
      ),
    );
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('npc-notes-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('nothing but the picker shows until an NPC is chosen', (
    tester,
  ) async {
    await pump(tester, model());
    expect(find.byKey(const ValueKey('npc-notes-text')), findsNothing);
    await choose(tester, 'Mara');
    expect(find.byKey(const ValueKey('npc-notes-text')), findsOneWidget);
  });

  testWidgets('text, a pin and a prepared message are saved in the store', (
    tester,
  ) async {
    await pump(tester, model());
    await choose(tester, 'Mara');
    await tester.enterText(
      find.byKey(const ValueKey('npc-notes-text')),
      'Lies about the key.',
    );
    await tester.tap(find.byKey(const ValueKey('npc-notes-save')));
    await tester.enterText(
      find.byKey(const ValueKey('npc-pin-field')),
      'Afraid of dogs',
    );
    await tester.tap(find.byKey(const ValueKey('npc-pin-add')));
    await tester.enterText(
      find.byKey(const ValueKey('npc-msg-field')),
      'Leave now.',
    );
    await tester.tap(find.byKey(const ValueKey('npc-msg-add')));
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(() => store.notes('c1', 'mara')))!;
    expect(saved.text, 'Lies about the key.');
    expect(saved.pinned, ['Afraid of dogs']);
    expect(saved.prepared.single.text, 'Leave now.');
    expect(find.text('Afraid of dogs'), findsOneWidget);
    expect(find.text('Leave now.'), findsOneWidget);
  });

  testWidgets('send passes the NPC id and text to the sender', (tester) async {
    final m = model();
    await tester.runAsync(
      () => store.addPrepared('c1', 'mara', text: 'Leave now.'),
    );
    await pump(tester, m);
    await choose(tester, 'Mara');
    await tester.tap(find.byKey(const ValueKey('npc-msg-send-m1')));
    await tester.pumpAndSettle();
    expect(sent, [('mara', 'Leave now.')]);
  });

  testWidgets('without a sender there is no send button', (tester) async {
    await tester.runAsync(
      () => store.addPrepared('c1', 'mara', text: 'Leave now.'),
    );
    await pump(tester, model(canSend: false));
    await choose(tester, 'Mara');
    expect(find.byKey(const ValueKey('npc-msg-send-m1')), findsNothing);
    expect(find.text('Leave now.'), findsOneWidget);
  });

  testWidgets('a too-long prepared message shows the error and is not kept', (
    tester,
  ) async {
    await pump(tester, model());
    await choose(tester, 'Mara');
    await tester.enterText(
      find.byKey(const ValueKey('npc-msg-field')),
      'x' * (maxPreparedMessageUnits + 1),
    );
    await tester.tap(find.byKey(const ValueKey('npc-msg-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('npc-notes-error')), findsOneWidget);
    final saved = (await tester.runAsync(() => store.notes('c1', 'mara')))!;
    expect(saved.prepared, isEmpty);
  });

  testWidgets('switching NPC shows that NPC\'s notes', (tester) async {
    await tester.runAsync(() => store.setText('c1', 'mara', 'about Mara'));
    await tester.runAsync(() => store.setText('c1', 'ellis', 'about Ellis'));
    await pump(tester, model());
    await choose(tester, 'Mara');
    expect(find.text('about Mara'), findsOneWidget);
    await choose(tester, 'Ellis');
    expect(find.text('about Ellis'), findsOneWidget);
    expect(find.text('about Mara'), findsNothing);
  });

  testWidgets('unpin removes a pinned detail', (tester) async {
    await tester.runAsync(() => store.pin('c1', 'mara', 'Afraid of dogs'));
    await pump(tester, model());
    await choose(tester, 'Mara');
    await tester.tap(find.byKey(const ValueKey('npc-unpin-0')));
    await tester.pumpAndSettle();
    expect(find.text('Afraid of dogs'), findsNothing);
  });
}
