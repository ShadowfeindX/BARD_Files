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

/// Keeps the setting for the life of the process. The on-disk store comes
/// with the composition work (demo row 6); until then a restart returns to
/// System.
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
