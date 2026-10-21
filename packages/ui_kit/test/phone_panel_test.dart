import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

const _threads = [
  PhoneThreadData(
    id: 'gm',
    title: 'The Handler',
    messages: [
      PhoneMessageData(text: 'Need backup', fromMe: true),
      PhoneMessageData(text: 'On it', fromMe: false),
    ],
  ),
  PhoneThreadData(
    id: 'alias:hall',
    title: 'Hall',
    messages: [PhoneMessageData(text: 'Meet at 9', fromMe: false)],
  ),
];

Widget _panel(
  Signal<List<PhoneThreadData>> threads,
  void Function(String, String) onSend, {
  String? disabled,
  int maxLength = 2000,
}) => MaterialApp(
  theme: BardTheme.dark(),
  home: Scaffold(
    body: SizedBox(
      width: 700,
      height: 500,
      child: PhonePanel(
        threads: threads,
        onSend: onSend,
        sendDisabledReason: disabled,
        maxLength: maxLength,
      ),
    ),
  ),
);

IconButton _sendButton(WidgetTester t) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

void main() {
  testWidgets('shows the first thread and switches on tap', (t) async {
    await t.pumpWidget(_panel(signal(_threads), (_, _) {}));
    expect(find.text('Need backup'), findsOneWidget);
    expect(find.text('Meet at 9'), findsNothing);
    await t.tap(find.text('Hall'));
    await t.pump();
    expect(find.text('Meet at 9'), findsOneWidget);
    expect(find.text('Need backup'), findsNothing);
  });

  testWidgets('empty state', (t) async {
    await t.pumpWidget(_panel(signal(<PhoneThreadData>[]), (_, _) {}));
    expect(find.text('No messages yet.'), findsOneWidget);
  });

  testWidgets('sending reports the open thread and clears the box', (t) async {
    final sent = <(String, String)>[];
    await t.pumpWidget(
      _panel(signal(_threads), (id, text) => sent.add((id, text))),
    );
    await t.tap(find.text('Hall'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Running late');
    await t.pump();
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    expect(sent, [('alias:hall', 'Running late')]);
    expect(find.text('Running late'), findsNothing);
    expect(_sendButton(t).onPressed, isNull);
  });

  testWidgets('blank text cannot be sent', (t) async {
    await t.pumpWidget(_panel(signal(_threads), (_, _) {}));
    await t.enterText(find.byType(TextField), '   ');
    await t.pump();
    expect(_sendButton(t).onPressed, isNull);
  });

  testWidgets('the cap counts UTF-16 code units', (t) async {
    await t.pumpWidget(_panel(signal(_threads), (_, _) {}, maxLength: 10));
    // Five emoji are ten code units: allowed. Six are twelve: too long.
    await t.enterText(find.byType(TextField), '😀' * 5);
    await t.pump();
    expect(find.text('10 / 10'), findsOneWidget);
    expect(_sendButton(t).onPressed, isNotNull);
    await t.enterText(find.byType(TextField), '😀' * 6);
    await t.pump();
    expect(find.text('Too long'), findsOneWidget);
    expect(_sendButton(t).onPressed, isNull);
  });

  testWidgets('a disabled reason replaces the compose box', (t) async {
    await t.pumpWidget(
      _panel(
        signal(_threads),
        (_, _) {},
        disabled: 'Sign in to send messages.',
      ),
    );
    expect(find.text('Sign in to send messages.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Need backup'), findsOneWidget);
  });

  testWidgets('new messages appear when the signal changes', (t) async {
    final threads = signal(_threads);
    await t.pumpWidget(_panel(threads, (_, _) {}));
    threads.value = [
      PhoneThreadData(
        id: 'gm',
        title: 'The Handler',
        messages: [
          ..._threads.first.messages,
          const PhoneMessageData(text: 'Careful', fromMe: false),
        ],
      ),
      _threads.last,
    ];
    await t.pump();
    expect(find.text('Careful'), findsOneWidget);
  });

  testWidgets('a vanished thread is never the send target', (t) async {
    final threads = signal(_threads);
    final sent = <(String, String)>[];
    await t.pumpWidget(_panel(threads, (id, text) => sent.add((id, text))));
    await t.tap(find.text('Hall'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Hello');
    threads.value = [_threads.first];
    await t.pump();
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    expect(sent, [('gm', 'Hello')]);
  });

  testWidgets('invisible-only text cannot be sent', (t) async {
    await t.pumpWidget(_panel(signal(_threads), (_, _) {}));
    await t.enterText(find.byType(TextField), '\u200B\u00AD\u3164 \u202E');
    await t.pump();
    expect(_sendButton(t).onPressed, isNull);
  });
}
