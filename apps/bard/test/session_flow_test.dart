import 'package:bard/app/composition.dart';
import 'package:bard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

/// The demo flow on a real `OperationHost` and the shipped pack. Needs
/// `bash tool/build_pack.sh` first (see docs/developer-guide/setup.md).
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final composition = (await tester.runAsync(
    () => Composition.inProcess(rootBundle),
  ))!;
  await tester.pumpWidget(BardApp(composition: composition));
  await tester.pumpAndSettle();
}

/// Lets the host's futures and streams run, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
}
