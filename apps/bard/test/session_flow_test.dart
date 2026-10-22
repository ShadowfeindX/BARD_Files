import 'package:bard/app/composition.dart';
import 'package:bard/main.dart';
import 'package:bard/ui/dossier/dossier_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

/// The demo flow on a real `OperationHost` and the shipped pack. Needs
/// `bash tool/build_pack.sh` first (see docs/developer-guide/setup.md).
Future<Composition> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final composition = (await tester.runAsync(
    () => Composition.inProcess(rootBundle),
  ))!;
  await tester.pumpWidget(BardApp(composition: composition));
  await tester.pumpAndSettle();
  return composition;
}

/// Lets the host's futures and streams run, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// Scrolls the console column until [finder] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('console-tools')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// The alias id of the agent called [name].
String _idOf(Composition composition, String name) =>
    composition.operation.agents.value.firstWhere((a) => a.name == name).id;

/// Shows [agent]'s dossier through the player picker.
Future<void> _showDossier(WidgetTester tester, String agent) async {
  await tester.tap(find.byKey(const ValueKey('player-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(agent).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a request resolves into a breakdown on all three panels', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('request-field-vale')),
      'Pick the lock',
    );
    await tester.tap(find.byKey(const ValueKey('request-send-vale')));
    await _settle(tester);
    expect(find.text('Pick the lock'), findsOneWidget); // GM queue

    await tester.tap(find.text('Pick the lock'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resolve')));
    await _settle(tester);
    expect(find.byType(DiceBreakdownView), findsNWidgets(3));
    expect(find.text('Pick the lock'), findsNothing);
  });

  testWidgets('a held Sanity loss is hidden from the player until confirmed', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sanity-hold')));
    await _settle(tester);
    expect(find.textContaining('Sanity loss 2'), findsOneWidget);
    expect(find.textContaining('loses 2 Sanity'), findsNothing);

    await tester.tap(find.byTooltip('Lower by 1'));
    await _settle(tester);
    expect(find.text('Proposed 2'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await _settle(tester);
    expect(find.text('Nothing held.'), findsOneWidget);
    // GM sees the edit note; the player's line has no "changed by" detail.
    expect(
      find.textContaining('changed by the Handler from 2'),
      findsOneWidget,
    );
  });

  testWidgets('add agent: the engine refuses bad scores, then accepts', (
    tester,
  ) async {
    await _pump(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('add-agent')));
    await tester.tap(find.byKey(const ValueKey('add-agent')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agent-name')),
      'Agent Rook',
    );
    await tester.enterText(find.byKey(const ValueKey('score-STR')), '0');
    await tester.tap(find.byKey(const ValueKey('agent-create')));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('score-DEX')), 'x');
    await tester.tap(find.byKey(const ValueKey('agent-create')));
    await tester.pumpAndSettle();
    expect(find.textContaining('whole numbers'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('score-DEX')), '1');
    await tester.tap(find.byKey(const ValueKey('agent-create')));
    await _settle(tester);
    // A score below the pack's minimum is refused by the engine.
    expect(find.byKey(const ValueKey('add-agent-error')), findsOneWidget);

    const scores = {
      'STR': '3', 'DEX': '3', 'END': '2', 'PER': '2', 'INT': '2',
      'WIS': '2', 'CHA': '2', 'WIL': '2', 'LCK': '2', //
    };
    for (final e in scores.entries) {
      final field = find.byKey(ValueKey('score-${e.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, e.value);
    }
    final create = find.byKey(const ValueKey('agent-create'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await _settle(tester);
    expect(find.byKey(const ValueKey('add-agent-error')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Agent Rook'), findsWidgets);
  });

  testWidgets('new operation replaces the host with an empty one', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('player-picker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-operation-confirm')));
    await _settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add an agent to start playing.'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-picker')), findsNothing);
  });

  testWidgets('a stat-gated broadcast reaches only the qualifying agent', (
    tester,
  ) async {
    final composition = await _pump(tester);
    // The demo agents have Charisma 1; Rook has 2.
    await tester.runAsync(
      () => composition.operation.addAgent('Agent Rook', const {
        'STR': 3, 'DEX': 3, 'END': 2, 'PER': 2, 'INT': 2,
        'WIS': 2, 'CHA': 2, 'WIL': 2, 'LCK': 2, //
      }),
    );
    await _settle(tester);

    await _reveal(tester, find.byKey(const ValueKey('broadcast-preview')));
    final attribute = find.byKey(const ValueKey('broadcast-attribute'));
    await tester.tap(attribute);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charisma').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('broadcast-value')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('broadcast-text')),
      'You hear whispers in the walls.',
    );
    await tester.tap(find.byKey(const ValueKey('broadcast-preview')));
    await _settle(tester);
    Finder previewIcon(String agent, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('broadcast-preview-$agent')),
      matching: find.byIcon(icon),
    );
    expect(
      previewIcon(_idOf(composition, 'Agent Rook'), Icons.check),
      findsOneWidget,
    );
    expect(previewIcon('vale', Icons.block), findsOneWidget);
    expect(previewIcon('quill', Icons.block), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('broadcast-send')));
    await _settle(tester);
    final inDossier = find.descendant(
      of: find.byType(DossierView),
      matching: find.textContaining('whispers in the walls'),
    );
    for (final (agent, receives) in [
      ('Agent Vale', false),
      ('Agent Quill', false),
      ('Agent Rook', true),
    ]) {
      await _showDossier(tester, agent);
      expect(
        inDossier,
        receives ? findsOneWidget : findsNothing,
        reason: agent,
      );
    }
  });

  testWidgets('a player and the Handler text each other', (tester) async {
    await _pump(tester);
    final playerPhone = find.byKey(const ValueKey('phone-vale'));
    final gmPhone = find.byKey(const ValueKey('gm-phone'));
    Finder inPhone(Finder phone, Finder what) =>
        find.descendant(of: phone, matching: what);

    await tester.enterText(
      inPhone(playerPhone, find.byType(TextField)),
      'Need backup.',
    );
    await tester.pump();
    await tester.tap(inPhone(playerPhone, find.byTooltip('Send')));
    await _settle(tester);
    expect(inPhone(playerPhone, find.text('Need backup.')), findsOneWidget);
    await _reveal(tester, gmPhone);
    expect(inPhone(gmPhone, find.text('Need backup.')), findsOneWidget);

    await tester.enterText(
      inPhone(gmPhone, find.byType(TextField)),
      'On my way.',
    );
    await tester.pump();
    await tester.tap(inPhone(gmPhone, find.byTooltip('Send')));
    await _settle(tester);
    expect(inPhone(playerPhone, find.text('On my way.')), findsOneWidget);
  });

  testWidgets('a text between two agents stays out of a third phone', (
    tester,
  ) async {
    final composition = await _pump(tester);
    await tester.runAsync(
      () => composition.operation.sendPhone('vale', 'alias:quill', 'Psst.'),
    );
    await _settle(tester);
    Finder psstIn(String alias) => find.descendant(
      of: find.byKey(ValueKey('phone-$alias')),
      matching: find.text('Psst.'),
    );
    await _showDossier(tester, 'Agent Quill');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('phone-quill')),
        matching: find.text('Agent Vale'),
      ),
    );
    await tester.pumpAndSettle();
    expect(psstIn('quill'), findsOneWidget);

    await tester.runAsync(
      () => composition.operation.addAgent('Agent Rook', const {
        'STR': 3, 'DEX': 3, 'END': 2, 'PER': 2, 'INT': 2,
        'WIS': 2, 'CHA': 2, 'WIL': 2, 'LCK': 2, //
      }),
    );
    await _settle(tester);
    await _showDossier(tester, 'Agent Rook');
    final rook = _idOf(composition, 'Agent Rook');
    for (final thread in ['Agent Vale', 'Agent Quill']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('phone-$rook')),
          matching: find.text(thread),
        ),
      );
      await tester.pumpAndSettle();
      expect(psstIn(rook), findsNothing, reason: thread);
    }
  });
}
