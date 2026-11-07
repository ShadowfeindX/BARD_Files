import 'dart:io';

import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('LocalDataPaths.forPlatform', () {
    test('Windows uses APPDATA', () {
      final p = LocalDataPaths.forPlatform(
        environment: {'APPDATA': r'C:\Users\r\AppData\Roaming'},
        operatingSystem: 'windows',
      );
      expect(p.root, r'C:\Users\r\AppData\Roaming\BARD');
      expect(
        p.settingsDatabase,
        r'C:\Users\r\AppData\Roaming\BARD\settings.db',
      );
      expect(
        p.hostDiagnosticLog('lan-1'),
        r'C:\Users\r\AppData\Roaming\BARD\episodes\lan-1.diagnostic.jsonl',
      );
    });

    test('Windows falls back to USERPROFILE', () {
      final p = LocalDataPaths.forPlatform(
        environment: {'USERPROFILE': r'C:\Users\r'},
        operatingSystem: 'windows',
      );
      expect(p.root, r'C:\Users\r\AppData\Roaming\BARD');
    });

    test('Linux uses an absolute XDG_DATA_HOME', () {
      final p = LocalDataPaths.forPlatform(
        environment: {'XDG_DATA_HOME': '/data', 'HOME': '/home/r'},
        operatingSystem: 'linux',
      );
      expect(p.root, '/data/bard');
      expect(p.reportsFolder, '/data/bard/reports');
    });

    test('Linux ignores a relative XDG_DATA_HOME and uses HOME', () {
      final p = LocalDataPaths.forPlatform(
        environment: {'XDG_DATA_HOME': 'data', 'HOME': '/home/r'},
        operatingSystem: 'linux',
      );
      expect(p.root, '/home/r/.local/share/bard');
    });

    test('missing variables and other platforms throw', () {
      expect(
        () => LocalDataPaths.forPlatform(
          environment: {},
          operatingSystem: 'linux',
        ),
        throwsStateError,
      );
      expect(
        () => LocalDataPaths.forPlatform(
          environment: {},
          operatingSystem: 'windows',
        ),
        throwsStateError,
      );
      expect(
        () => LocalDataPaths.forPlatform(
          environment: {},
          operatingSystem: 'macos',
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('LocalData', () {
    test('settings survive closing and reopening the files', () async {
      final dir = await Directory.systemTemp.createTemp('bard_local');
      addTearDown(() => dir.delete(recursive: true));
      final paths = LocalDataPaths('${dir.path}/bard');

      var data = await LocalData.open(paths);
      await data.settings.write(AppSettingsStore.appearanceKey, {
        'themeId': 'x',
      });
      await data.settings.setLastHostedEpisode('lan-1');
      final agent = await data.settings.localAgentId(() => 'agent-a');
      await data.hostSettings.setSnapshotInterval(const Duration(minutes: 2));
      await data.notes.setText('demo', 'mara', 'Lies.');
      await data.close();

      data = await LocalData.open(paths);
      addTearDown(data.close);
      expect(await data.settings.read(AppSettingsStore.appearanceKey), {
        'themeId': 'x',
      });
      expect(await data.settings.lastHostedEpisode(), 'lan-1');
      expect(await data.settings.localAgentId(() => 'agent-b'), agent);
      expect(
        await data.hostSettings.snapshotInterval(),
        const Duration(minutes: 2),
      );
      expect((await data.notes.notes('demo', 'mara')).text, 'Lies.');
      expect(File(paths.settingsDatabase).existsSync(), isTrue);
    });

    test('nothing saved reads as null', () async {
      final data = await LocalData.open(
        const LocalDataPaths('/mem'),
        factory: newDatabaseFactoryMemory(),
      );
      addTearDown(data.close);
      expect(await data.settings.read(AppSettingsStore.appearanceKey), isNull);
      expect(await data.settings.lastHostedEpisode(), isNull);
    });
  });
}
