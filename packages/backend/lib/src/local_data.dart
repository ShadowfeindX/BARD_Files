import 'dart:io';

import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

import 'host_settings_store.dart';
import 'npc_notes_store.dart';
import 'sembast_event_store.dart';

/// Where this machine keeps the app's local files (07 §Local data).
///
/// One folder per user account on the machine:
///
/// * Windows: `%APPDATA%\BARD`
/// * Linux: `$XDG_DATA_HOME/bard`, or `~/.local/share/bard` when
///   `XDG_DATA_HOME` is unset or not an absolute path
///
/// The folder is found from the process environment, so no plugin is
/// needed. Inside it: `settings.db`, `notes.db`, `episodes/` (one sembast
/// file and one diagnostic log per hosted episode), `joined/` (diagnostic
/// logs of episodes joined as a player) and `reports/` (saved report
/// bundles).
final class LocalDataPaths {
  /// Paths under [root].
  const LocalDataPaths(this.root);

  /// The folder for [operatingSystem] (default: this one), read from
  /// [environment] (default: this process's).
  ///
  /// Throws [UnsupportedError] on a platform v1 does not run on, and
  /// [StateError] when the variables that name the folder are missing.
  factory LocalDataPaths.forPlatform({
    Map<String, String>? environment,
    String? operatingSystem,
  }) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    switch (os) {
      case 'windows':
        final appData = env['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return LocalDataPaths(_join(appData, 'BARD', r'\'));
        }
        final profile = env['USERPROFILE'];
        if (profile != null && profile.isNotEmpty) {
          return LocalDataPaths(
            _join(
              _join(_join(profile, 'AppData', r'\'), 'Roaming', r'\'),
              'BARD',
              r'\',
            ),
          );
        }
        throw StateError('Neither APPDATA nor USERPROFILE is set.');
      case 'linux':
        final xdg = env['XDG_DATA_HOME'];
        // The XDG spec says a relative value is invalid and must be ignored.
        if (xdg != null && xdg.startsWith('/')) {
          return LocalDataPaths(_join(xdg, 'bard', '/'));
        }
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return LocalDataPaths(
            _join(_join(_join(home, '.local', '/'), 'share', '/'), 'bard', '/'),
          );
        }
        throw StateError('Neither XDG_DATA_HOME nor HOME is set.');
      default:
        throw UnsupportedError('No local data folder on $os.');
    }
  }

  /// The app's folder.
  final String root;

  String get _sep => root.contains(r'\') ? r'\' : '/';

  /// The app settings database (appearance, this machine's agent id, the
  /// last hosted episode) and the host settings.
  String get settingsDatabase => _join(root, 'settings.db', _sep);

  /// The Handler's NPC notes database.
  String get notesDatabase => _join(root, 'notes.db', _sep);

  /// One `<episodeId>.db` and `<episodeId>.diagnostic.jsonl` per hosted
  /// episode.
  String get episodesFolder => _join(root, 'episodes', _sep);

  /// Diagnostic logs of episodes joined as a player.
  String get joinedFolder => _join(root, 'joined', _sep);

  /// Saved report bundles, one folder each.
  String get reportsFolder => _join(root, 'reports', _sep);

  /// The diagnostic log file of hosted episode [episodeId].
  String hostDiagnosticLog(String episodeId) =>
      _join(episodesFolder, '$episodeId.diagnostic.jsonl', _sep);

  /// The diagnostic log file of joined episode [episodeId].
  String joinedDiagnosticLog(String episodeId) =>
      _join(joinedFolder, '$episodeId.diagnostic.jsonl', _sep);

  static String _join(String a, String b, String sep) =>
      a.endsWith(sep) ? '$a$b' : '$a$sep$b';
}

/// Small app settings that belong to this machine, kept in `settings.db`
/// beside the [HostSettingsStore].
///
/// Values are JSON maps under fixed keys, so the app can store a setting
/// whose type lives in another package (the appearance setting is a
/// `theme_core` type) without this package depending on it.
final class AppSettingsStore {
  /// Creates a store over an already opened [database].
  AppSettingsStore(this._db);

  static final _settings = stringMapStoreFactory.store('appSettings');

  /// The key the appearance setting is stored under.
  static const String appearanceKey = 'appearance';
  static const String _agentKey = 'localAgent';
  static const String _hostedKey = 'lastHostedEpisode';

  final Database _db;

  /// The map saved under [key], or null.
  Future<Map<String, Object?>?> read(String key) async {
    final row = await _settings.record(key).get(_db);
    return row == null ? null : Map<String, Object?>.from(row);
  }

  /// Saves [value] under [key], replacing what was there.
  Future<void> write(String key, Map<String, Object?> value) =>
      _settings.record(key).put(_db, value);

  /// This machine's agent id for joining LAN episodes, made by [create] and
  /// saved the first time it is asked for.
  Future<String> localAgentId(String Function() create) =>
      _db.transaction((txn) async {
        final row = await _settings.record(_agentKey).get(txn);
        final saved = row?['id'];
        if (saved is String && saved.isNotEmpty) return saved;
        final id = create();
        await _settings.record(_agentKey).put(txn, {'id': id});
        return id;
      });

  /// The episode this machine hosted last, or null.
  Future<HostedEpisode?> lastHostedEpisode() async {
    final row = await _settings.record(_hostedKey).get(_db);
    final id = row?['id'];
    final code = row?['joinCode'];
    final port = row?['port'];
    if (id is! String || id.isEmpty) return null;
    return HostedEpisode(
      episodeId: id,
      joinCode: code is String && code.isNotEmpty ? code : null,
      port: port is int && port > 0 && port < 65536 ? port : null,
    );
  }

  /// Records [hosted] as the episode this machine hosts.
  Future<void> setLastHostedEpisode(HostedEpisode hosted) =>
      _settings.record(_hostedKey).put(_db, {
        'id': hosted.episodeId,
        'joinCode': ?hosted.joinCode,
        'port': ?hosted.port,
      });
}

/// The episode this machine hosts, with the join code and port it was
/// reached at, so a restarted host keeps the address players already have.
final class HostedEpisode {
  /// Creates the record.
  const HostedEpisode({required this.episodeId, this.joinCode, this.port});

  /// The hosted episode.
  final String episodeId;

  /// The join code players were given, or null before the first listen.
  final String? joinCode;

  /// The port the host listened on, or null before the first listen.
  final int? port;
}

/// Every local database of this machine, opened once at start-up and closed
/// when the app exits.
final class LocalData {
  LocalData._(this.paths, this._settingsDb, this._notesDb, this.events)
    : settings = AppSettingsStore(_settingsDb),
      hostSettings = HostSettingsStore(_settingsDb),
      notes = NpcNotesStore(_notesDb);

  /// Opens (creating when missing) the databases under [paths], with
  /// [factory] (default: `databaseFactoryIo`, files on disk).
  static Future<LocalData> open(
    LocalDataPaths paths, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactoryIo;
    final settingsDb = await f.openDatabase(paths.settingsDatabase);
    final Database notesDb;
    try {
      notesDb = await f.openDatabase(paths.notesDatabase);
    } catch (_) {
      await settingsDb.close();
      rethrow;
    }
    return LocalData._(
      paths,
      settingsDb,
      notesDb,
      SembastEventStore.inDirectory(
        f,
        paths.episodesFolder,
        sizeOf: (path) async {
          final file = File(path);
          return await file.exists() ? file.length() : null;
        },
      ),
    );
  }

  /// A fresh memory database factory, to pass to [inMemory] more than once.
  static DatabaseFactory memoryFactory() => newDatabaseFactoryMemory();

  /// Databases held in memory under [root], for tests and for a machine
  /// whose folder cannot be written. [factory] lets a test reopen the same
  /// memory databases; by default each call starts empty.
  static Future<LocalData> inMemory({
    String root = '/memory',
    DatabaseFactory? factory,
  }) => open(
    LocalDataPaths(root),
    factory: factory ?? newDatabaseFactoryMemory(),
  );

  /// Where the files are.
  final LocalDataPaths paths;

  final Database _settingsDb;
  final Database _notesDb;

  /// App settings.
  final AppSettingsStore settings;

  /// Settings this machine uses when it hosts (snapshot interval).
  final HostSettingsStore hostSettings;

  /// The Handler's NPC notes.
  final NpcNotesStore notes;

  /// Hosted episodes, one file each in [LocalDataPaths.episodesFolder].
  final SembastEventStore events;

  /// Closes every database.
  Future<void> close() async {
    await events.close();
    await _notesDb.close();
    await _settingsDb.close();
  }
}
