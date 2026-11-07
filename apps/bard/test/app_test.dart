import 'package:bard/app/composition.dart';
import 'package:bard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support/fake_episode_service.dart';

Future<ThemeController> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final appearance = (await tester.runAsync(
    () => ThemeController.load(rootBundle),
  ))!;
  await tester.pumpWidget(
    BardApp(
      composition: Composition(episode: FakeEpisodeService()),
      appearance: appearance,
    ),
  );
  await tester.pumpAndSettle();
  return appearance;
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

String _vitals(WidgetTester tester, String stat) =>
    (tester.widget<Text>(find.byKey(ValueKey('$stat-vale'))).data)!;

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
    expect(_vitals(tester, 'health'), '12');
    expect(_vitals(tester, 'sanity'), '10');
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
    expect(_vitals(tester, 'sanity'), '10');

    await tester.tap(find.byKey(const ValueKey('review-inc-rev0')));
    await tester.pumpAndSettle();
    expect(find.text('Proposed 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-confirm-rev0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-rev0')), findsNothing);
    expect(_vitals(tester, 'sanity'), '7');
    expect(find.text('Agent Vale loses 3 Sanity.'), findsOneWidget);
    expect(
      find.text('Agent Vale loses 3 Sanity (changed by the Handler from 2).'),
      findsOneWidget,
    );
  });

  testWidgets('a GM note shows on the GM log', (tester) async {
    await _pump(tester);
    await _reveal(tester, find.byKey(const ValueKey('note-field')));
    await tester.enterText(
      find.byKey(const ValueKey('note-field')),
      'Vale is lying',
    );
    await tester.tap(find.byKey(const ValueKey('note-add')));
    await tester.pumpAndSettle();
    expect(find.text('GM note: Vale is lying'), findsOneWidget);
  });

  testWidgets('broadcast preview marks who qualifies, then sends', (
    tester,
  ) async {
    await _pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('broadcast-send')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('console-tools')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    // Strength at least 2: Vale has 2, Quill has 1.
    await tester.enterText(find.byKey(const ValueKey('broadcast-value')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('broadcast-text')),
      'A cold draft.',
    );
    await tester.tap(find.byKey(const ValueKey('broadcast-preview')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('broadcast-preview-vale')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('broadcast-preview-quill')),
        matching: find.byIcon(Icons.block),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('broadcast-send')));
    await tester.pumpAndSettle();
    expect(find.text('A cold draft.'), findsNWidgets(2)); // alert + log line
    expect(find.byKey(const ValueKey('broadcast-preview-vale')), findsNothing);
  });

  testWidgets('a held condition shows on the record card once confirmed', (
    tester,
  ) async {
    await _pump(tester);
    await _reveal(tester, find.byKey(const ValueKey('condition-hold')));
    await tester.tap(find.byKey(const ValueKey('condition-hold')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('console-tools')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Agent Vale: Condition Bleeding'), findsOneWidget);
    expect(find.text('None.'), findsNWidgets(1)); // not on the card yet

    await tester.tap(find.byKey(const ValueKey('review-confirm-rev0')));
    await tester.pumpAndSettle();
    // Console picker, console chip and record-card tag.
    await _reveal(
      tester,
      find.byKey(const ValueKey('condition-clear-bleeding')),
    );
    expect(find.text('Bleeding'), findsNWidgets(3));

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Bleeding'), findsNWidgets(1)); // the picker only
  });

  testWidgets('a whisper raises an alert beside the log line, not the phone', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('whisper-vale')), findsNothing);
    final tools = find
        .descendant(
          of: find.byKey(const ValueKey('console-tools')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('broadcast-send')),
      200,
      scrollable: tools,
    );
    await tester.enterText(find.byKey(const ValueKey('broadcast-value')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('broadcast-text')),
      'A cold draft.',
    );
    await tester.tap(find.byKey(const ValueKey('broadcast-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whisper-vale')), findsOneWidget);
    expect(find.byKey(const ValueKey('whisper-quill')), findsNothing);
    // The alert and the log line.
    expect(find.text('A cold draft.'), findsNWidgets(2));
    // Not in the phone panel.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('phone-vale')),
        matching: find.text('A cold draft.'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('whisper-dismiss-vale')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whisper-vale')), findsNothing);
    expect(find.text('A cold draft.'), findsOneWidget); // log line stays
  });

  testWidgets('the appearance dialog changes theme and variant', (
    tester,
  ) async {
    final appearance = await _pump(tester);
    // System under the test platform's light brightness is Manila.
    expect(appearance.applied.value.usedSystem, isTrue);

    await tester.tap(find.byKey(const ValueKey('appearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phosphor').last);
    await tester.pumpAndSettle();
    expect(appearance.applied.value.theme.themeId, 'phosphor');
    expect(appearance.applied.value.usedSystem, isFalse);

    await tester.tap(find.byKey(const ValueKey('appearance-variant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High contrast').last);
    await tester.pumpAndSettle();
    expect(appearance.applied.value.theme.variant, ThemeVariant.highContrast);

    await tester.tap(find.byKey(const ValueKey('appearance-reset')));
    await tester.pumpAndSettle();
    expect(appearance.applied.value.usedSystem, isTrue);
    expect(appearance.setting.value.variant, ThemeVariant.normal);
  });
}
