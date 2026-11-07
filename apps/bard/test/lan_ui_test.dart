import 'package:backend/backend.dart';
import 'package:bard/app/composition.dart';
import 'package:bard/data/appearance_repository.dart';
import 'package:bard/data/report_saver.dart';
import 'package:bard/main.dart';
import 'package:bard/ui/home/lan_dialogs.dart';
import 'package:engine/engine.dart' show PackRef;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:session/session.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

import 'support/fake_episode_service.dart';

/// Records saves instead of writing files.
class _RecordingSaver extends ReportSaver {
  _RecordingSaver({required bool notes})
    : super(
        episodeId: 'e',
        store: InMemoryEventStore(),
        log: DiagnosticLog(),
        folder: '/nowhere',
        pack: const PackRef(id: 'p', version: '1', contentHash: 'h'),
        settings: () async => const {},
        notes: notes ? () async => const {} : null,
      );

  final List<bool> saves = [];

  @override
  Future<String> save({bool includeNotes = false}) async {
    saves.add(includeNotes);
    return '/reports/bard-report-e';
  }
}

Future<void> _pump(
  WidgetTester tester, {
  LocalData? local,
  ReportSaver? reports,
}) async {
  tester.view.physicalSize = const Size(2600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final appearance = (await tester.runAsync(
    () => ThemeController.load(rootBundle),
  ))!;
  await tester.pumpWidget(
    BardApp(
      composition: Composition(episode: FakeEpisodeService(), reports: reports),
      appearance: appearance,
      local: local,
    ),
  );
  await tester.pumpAndSettle();
}

Future<LocalData> _memoryLocal(WidgetTester tester) async =>
    (await tester.runAsync(() => LocalData.inMemory()))!;

void main() {
  testWidgets('without local data there is no hosting, joining or report', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('host-lan')), findsNothing);
    expect(find.byKey(const ValueKey('join-lan')), findsNothing);
    expect(find.byKey(const ValueKey('save-report')), findsNothing);
  });

  testWidgets('declining the consent step does not host', (tester) async {
    final local = await _memoryLocal(tester);
    await _pump(tester, local: local);
    await tester.tap(find.byKey(const ValueKey('host-lan')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PLACEHOLDER'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-decline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hosting-line')), findsNothing);
    expect(find.byKey(const ValueKey('host-lan')), findsOneWidget);
  });

  testWidgets('the join dialog checks the address before the consent step', (
    tester,
  ) async {
    final local = await _memoryLocal(tester);
    await _pump(tester, local: local);
    await tester.tap(find.byKey(const ValueKey('join-lan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('join-address')), 'nope');
    await tester.tap(find.byKey(const ValueKey('join-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-problem')), findsOneWidget);
    expect(find.textContaining('PLACEHOLDER'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('join-address')),
      '192.168.1.20:4040',
    );
    await tester.enterText(find.byKey(const ValueKey('join-code')), 'abc234');
    await tester.enterText(find.byKey(const ValueKey('join-alias')), 'vale');
    await tester.tap(find.byKey(const ValueKey('join-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PLACEHOLDER'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-decline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-status')), findsNothing);
  });

  testWidgets('the Handler can tick "include notes" on a report', (
    tester,
  ) async {
    final saver = _RecordingSaver(notes: true);
    await _pump(tester, reports: saver);
    await tester.tap(find.byKey(const ValueKey('save-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-include-notes')));
    await tester.tap(find.byKey(const ValueKey('report-save')));
    await tester.pumpAndSettle();
    expect(saver.saves, [false, true]);
    expect(find.byKey(const ValueKey('report-saved')), findsOneWidget);
  });

  testWidgets('a player has no "include notes" tick', (tester) async {
    await _pump(tester, reports: _RecordingSaver(notes: false));
    await tester.tap(find.byKey(const ValueKey('save-report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-include-notes')), findsNothing);
  });

  test('host addresses are read as host and port', () {
    expect(parseHostAndPort(' 10.0.0.5:4040 '), (host: '10.0.0.5', port: 4040));
    expect(parseHostAndPort('10.0.0.5'), isNull);
    expect(parseHostAndPort('10.0.0.5:0'), isNull);
    expect(parseHostAndPort('a b:4040'), isNull);
  });

  test('the appearance setting survives reopening the settings', () async {
    final factory = LocalData.memoryFactory();
    var local = await LocalData.inMemory(factory: factory);
    const chosen = AppearanceSetting(
      themeId: 'manila',
      variant: ThemeVariant.highContrast,
    );
    await LocalAppearanceRepository(local.settings).save(chosen);
    await local.close();
    local = await LocalData.inMemory(factory: factory);
    addTearDown(local.close);
    final loaded = await LocalAppearanceRepository(local.settings).load();
    expect(loaded.themeId, 'manila');
    expect(loaded.variant, ThemeVariant.highContrast);
  });

  test('nothing stored or an unreadable value gives System', () async {
    final local = await LocalData.inMemory();
    addTearDown(local.close);
    final repo = LocalAppearanceRepository(local.settings);
    expect((await repo.load()).themeId, systemThemeId);
    await local.settings.write(AppSettingsStore.appearanceKey, {'themeId': 7});
    expect((await repo.load()).themeId, systemThemeId);
  });
}
