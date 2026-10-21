import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: BardTheme.light(),
  home: Scaffold(body: child),
);

DiceBreakdownData _data({
  CheckOutcomeKind outcome = CheckOutcomeKind.success,
  int? dc = 12,
}) => DiceBreakdownData(
  title: 'Lockpicking',
  groups: const [
    DiceGroup(
      label: 'Primary d6',
      dice: [DieResult(6, exploded: true), DieResult(3)],
      subtotal: 9,
    ),
    DiceGroup(label: 'Proficiency', dice: [DieResult(4)], subtotal: 4),
  ],
  modifiers: const [ModifierLine('DEX', 2), ModifierLine('Wound', -1)],
  total: 14,
  dc: dc,
  dcLabel: dc == null ? null : 'Cat-F',
  outcome: outcome,
);

void main() {
  testWidgets('shows title, group sums, modifiers, total and DC', (t) async {
    await t.pumpWidget(_wrap(DiceBreakdownView(data: _data())));
    expect(find.text('Lockpicking'), findsOneWidget);
    expect(find.text('= 9'), findsOneWidget);
    expect(find.text('= 4'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('Total 14'), findsOneWidget);
    expect(find.text('vs DC 12 (Cat-F)'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);
  });

  testWidgets('shows no group total unless the engine supplied one', (t) async {
    const data = DiceBreakdownData(
      title: 'x',
      groups: [
        DiceGroup(label: 'g', dice: [DieResult(2)]),
      ],
      modifiers: [],
      total: 2,
      outcome: CheckOutcomeKind.failure,
    );
    await t.pumpWidget(_wrap(const DiceBreakdownView(data: data)));
    expect(find.textContaining('= '), findsNothing);
  });

  testWidgets('marks exploded dice', (t) async {
    await t.pumpWidget(_wrap(DiceBreakdownView(data: _data())));
    expect(find.text('6!'), findsOneWidget);
    expect(find.byKey(const ValueKey('die-exploded')), findsOneWidget);
    expect(find.byKey(const ValueKey('die')), findsNWidgets(2));
  });

  testWidgets('omits DC when the check has none', (t) async {
    await t.pumpWidget(_wrap(DiceBreakdownView(data: _data(dc: null))));
    expect(find.textContaining('vs DC'), findsNothing);
  });

  for (final entry in {
    CheckOutcomeKind.success: 'Success',
    CheckOutcomeKind.partial: 'Partial success',
    CheckOutcomeKind.failure: 'Failure',
  }.entries) {
    testWidgets('labels outcome ${entry.key.name}', (t) async {
      await t.pumpWidget(
        _wrap(DiceBreakdownView(data: _data(outcome: entry.key))),
      );
      expect(find.text(entry.value), findsOneWidget);
    });
  }
}
