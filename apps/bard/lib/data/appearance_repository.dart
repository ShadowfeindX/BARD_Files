import 'package:backend/backend.dart';
import 'package:theme_core/theme_core.dart';

/// Where the player's appearance setting is kept (07 §The player's setting:
/// client-side only, never Firestore or RTDB).
abstract interface class AppearanceRepository {
  /// The stored setting, or the first-launch setting (System, normal) when
  /// nothing is stored.
  Future<AppearanceSetting> load();

  /// Stores [setting].
  Future<void> save(AppearanceSetting setting);
}

/// Keeps the setting for the life of the process only: for tests, and for
/// a machine whose local data folder cannot be opened.
class InMemoryAppearanceRepository implements AppearanceRepository {
  /// Creates a repository holding [initial].
  InMemoryAppearanceRepository([
    this._setting = const AppearanceSetting.initial(),
  ]);

  AppearanceSetting _setting;

  @override
  Future<AppearanceSetting> load() async => _setting;

  @override
  Future<void> save(AppearanceSetting setting) async => _setting = setting;
}

/// Keeps the setting in this machine's `settings.db`, so the chosen theme
/// and variant survive a restart.
class LocalAppearanceRepository implements AppearanceRepository {
  /// Creates a repository over [_settings].
  LocalAppearanceRepository(this._settings);

  final AppSettingsStore _settings;

  /// The stored setting; nothing stored, or a value that cannot be read,
  /// gives the first-launch setting.
  @override
  Future<AppearanceSetting> load() async {
    try {
      final json = await _settings.read(AppSettingsStore.appearanceKey);
      return json == null
          ? const AppearanceSetting.initial()
          : AppearanceSetting.fromJson(json);
    } on Object {
      return const AppearanceSetting.initial();
    }
  }

  @override
  Future<void> save(AppearanceSetting setting) =>
      _settings.write(AppSettingsStore.appearanceKey, setting.toJson());
}
