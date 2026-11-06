import 'package:sembast/sembast.dart';

/// Settings that belong to this machine when it hosts an episode, kept in a
/// small sembast database of their own (04 §Persistence).
///
/// Today it holds one value: how often the head snapshot is mirrored
/// (`StoreActor.snapshotInterval`, S-5). A host app reads it at start-up and
/// passes it to the `StoreActor`.
final class HostSettingsStore {
  /// Creates a store over an already opened [database].
  HostSettingsStore(this._db);

  /// The interval used until the host sets one: 5 minutes (R, 2026-11-05).
  static const Duration defaultSnapshotInterval = Duration(minutes: 5);

  static final _settings = stringMapStoreFactory.store('hostSettings');
  static const _intervalKey = 'snapshotIntervalSeconds';

  final Database _db;

  /// The saved snapshot interval, or [defaultSnapshotInterval] when none is
  /// saved or the saved value is not a positive number of seconds.
  Future<Duration> snapshotInterval() async {
    final row = await _settings.record(_intervalKey).get(_db);
    final seconds = row?['seconds'];
    return seconds is int && seconds > 0
        ? Duration(seconds: seconds)
        : defaultSnapshotInterval;
  }

  /// Saves [interval], rounded down to whole seconds. Throws
  /// [ArgumentError] when it is under one second.
  Future<void> setSnapshotInterval(Duration interval) async {
    if (interval.inSeconds < 1) {
      throw ArgumentError.value(interval, 'interval', 'must be at least 1 s');
    }
    await _settings.record(_intervalKey).put(_db, {
      'seconds': interval.inSeconds,
    });
  }

  /// Forgets the saved interval, so the default applies again.
  Future<void> resetSnapshotInterval() =>
      _settings.record(_intervalKey).delete(_db);
}
