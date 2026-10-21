import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

Widget _panel(Signal<List<String>> items, {PerspectiveKind? kind}) {
  return MaterialApp(
    theme: BardTheme.dark(),
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: PerspectivePanel<String>(
          kind: kind ?? PerspectiveKind.player,
          title: 'Agent Vale',
          items: items,
          itemBuilder: (context, item) => Text(item),
          emptyText: 'Quiet.',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows header and empty state', (t) async {
    await t.pumpWidget(_panel(signal(<String>[])));
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Agent Vale'), findsOneWidget);
    expect(find.text('Quiet.'), findsOneWidget);
  });

  testWidgets('rebuilds when the signal changes', (t) async {
    final items = signal(<String>['one']);
    await t.pumpWidget(_panel(items));
    expect(find.text('one'), findsOneWidget);
    items.value = ['one', 'two'];
    await t.pump();
    expect(find.text('two'), findsOneWidget);
    expect(find.text('Quiet.'), findsNothing);
  });

  testWidgets('two panels on different signals stay independent', (t) async {
    final gm = signal(<String>['gm note']);
    final player = signal(<String>[]);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: _panel(gm, kind: PerspectiveKind.gm)),
              Expanded(child: _panel(player)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('gm note'), findsOneWidget);
    expect(find.text('GM'), findsOneWidget);
    expect(find.text('Quiet.'), findsOneWidget);
  });

  test('kind labels', () {
    expect(PerspectivePanel.kindLabel(PerspectiveKind.table), 'Table');
  });
}
