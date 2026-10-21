import 'package:bard/app/composition.dart';
import 'package:bard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support/fake_operation_service.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BardApp(composition: Composition(operation: FakeOperationService())),
  );
  await tester.pumpAndSettle();
}

Future<void> _request(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('request-field-vale')),
    text,
  );
  await tester.tap(find.byKey(const ValueKey('request-send-vale')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one-device screen shows GM, player and table panels', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Handler log'), findsOneWidget);
    expect(find.text('Your log'), findsOneWidget);
    expect(find.text('Table'), findsNWidgets(2)); // kind chip and title
    expect(find.text('Health 12   Sanity 10'), findsOneWidget);
  });

  testWidgets('request reaches the GM queue and the player log', (
    tester,
  ) async {
    await _pump(tester);
    await _request(tester, 'Pick the lock');
    expect(find.byKey(const ValueKey('request-req0')), findsOneWidget);
    expect(find.text('You ask to act: "Pick the lock".'), findsOneWidget);
  });

  testWidgets('resolving shows the breakdown on GM, player and table', (
    tester,
  ) async {
    await _pump(tester);
    await _request(tester, 'Pick the lock');
    await tester.tap(find.byKey(const ValueKey('request-req0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resolve')));
    await tester.pumpAndSettle();
    // Scripted dice 6 (exploded) then 3, plus DEX 3 for the default skill.
    expect(find.byType(DiceBreakdownView), findsNWidgets(3));
    expect(find.text('Total 12'), findsNWidgets(3));
    expect(find.text('vs DC 3 (Cat-F)'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('request-req0')), findsNothing);
  });

  testWidgets('sanity loss is held, hidden from the player, then confirmed', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sanity-hold')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-rev0')), findsOneWidget);
    expect(find.text('Agent Vale would lose 2 Sanity (held).'), findsOneWidget);
    expect(find.text('Health 12   Sanity 10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-inc-rev0')));
    await tester.pumpAndSettle();
    expect(find.text('Proposed 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-confirm-rev0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-rev0')), findsNothing);
    expect(find.text('Health 12   Sanity 7'), findsOneWidget);
    expect(find.text('Agent Vale loses 3 Sanity.'), findsOneWidget);
    expect(
      find.text('Agent Vale loses 3 Sanity (changed by the Handler from 2).'),
      findsOneWidget,
    );
  });

  testWidgets('a GM note shows on the GM log', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('note-field')),
      'Vale is lying',
    );
    await tester.tap(find.byKey(const ValueKey('note-add')));
    await tester.pumpAndSettle();
    expect(find.text('GM note: Vale is lying'), findsOneWidget);
  });
}
