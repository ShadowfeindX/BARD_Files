import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support.dart';

ThemeController _controller({
  AppearanceSetting initial = const AppearanceSetting.initial(),
  ThemeBrightness brightness = ThemeBrightness.dark,
  List<AppearanceSetting>? saved,
}) => ThemeController(
  resolver: testResolver(),
  initial: initial,
  brightness: brightness,
  onChanged: saved?.add,
);

void main() {
  test('the built-in themes load from the asset bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final themes = await loadBuiltInThemes(rootBundle);
    expect([for (final t in themes) t.id], BuiltInIds.all);
  });

  test('first launch is System, which follows the OS brightness live', () {
    final c = _controller();
    expect(c.setting.value.themeId, systemThemeId);
    expect(c.applied.value.theme.themeId, BuiltInIds.nightDesk);
    c.osBrightness.value = ThemeBrightness.light;
    expect(c.applied.value.theme.themeId, BuiltInIds.manila);
    expect(c.applied.value.usedSystem, isTrue);
  });

  test('choices list System first, then the built-ins by name', () {
    final c = _controller();
    expect(
      [for (final x in c.choices) x.label],
      ['System', 'Phosphor', 'Manila', 'Night Desk'],
    );
  });

  test('selecting a theme and variant is reported and applied', () {
    final saved = <AppearanceSetting>[];
    final c = _controller(saved: saved);
    c.selectTheme(BuiltInIds.phosphor);
    c.selectVariant(ThemeVariant.redGreenSafe);
    expect(c.applied.value.theme.themeId, BuiltInIds.phosphor);
    expect(c.applied.value.theme.variant, ThemeVariant.redGreenSafe);
    expect(saved.length, 2);
    expect(saved.last.variant, ThemeVariant.redGreenSafe);
  });

  test('the variant drop-down lists what the theme provides', () {
    final c = _controller();
    expect(c.variants, ThemeVariant.values);
  });

  test('resetting returns to System with the normal variant', () {
    final c = _controller();
    c.selectTheme(BuiltInIds.manila);
    c.selectVariant(ThemeVariant.highContrast);
    c.resetToSystem();
    expect(c.setting.value.themeId, systemThemeId);
    expect(c.setting.value.variant, ThemeVariant.normal);
  });

  test('a stored theme that is not installed falls back to System', () {
    final c = _controller(
      initial: const AppearanceSetting(
        themeId: 'gone',
        variant: ThemeVariant.normal,
      ),
    );
    expect(c.applied.value.themeMissing, isTrue);
    expect(c.setting.value.themeId, 'gone'); // never overwritten
  });

  test('every built-in theme and variant builds a theme with its tokens', () {
    final resolver = testResolver();
    for (final id in BuiltInIds.all) {
      for (final variant in ThemeVariant.values) {
        final resolved = resolver.resolve(id, variant);
        final data = buildBardThemeData(resolved);
        final tokens = data.extension<BardTokens>()!;
        expect(tokens.window, toFlutterColor(resolved.tokens['window']!));
        expect(data.scaffoldBackgroundColor, tokens.desk, reason: id);
        expect(tokens.highContrast, variant == ThemeVariant.highContrast);
      }
    }
  });

  testWidgets('a result chip shows glyph and word and a 2 px outline in '
      'high contrast', (tester) async {
    Future<void> pump(ThemeVariant variant) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: testTheme(variant: variant),
          home: const Scaffold(
            body: ResultChip(kind: ChipKind.success, label: 'Success'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    BoxDecoration decoration() =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(ResultChip),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;

    await pump(ThemeVariant.normal);
    expect(find.text('Success'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect((decoration().border! as Border).top.width, 1);

    await pump(ThemeVariant.highContrast);
    expect((decoration().border! as Border).top.width, 2);
  });

  testWidgets('a shell window draws its title bar and body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: const Scaffold(
          body: ShellWindow(title: 'Requests', child: Text('body')),
        ),
      ),
    );
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('a record card shows label cells, rows, tags and empty text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: const Scaffold(
          body: RecordCard(
            title: 'Agent Vale',
            sections: [
              RecordSection(label: 'Vitals', rows: [RecordRow('Health', '12')]),
              RecordSection(label: 'Conditions', tags: ['Bleeding']),
              RecordSection(label: 'Kit', emptyText: 'None.'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Agent Vale'), findsOneWidget);
    expect(find.text('VITALS'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Bleeding'), findsOneWidget);
    expect(find.text('None.'), findsOneWidget);
  });
}
