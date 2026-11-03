part of 'events.dart';

/// Events applied by `EpisodeSystem`.
sealed class EpisodeEvent extends Event {
  const EpisodeEvent();
}

/// The episode started: the genesis event of every log.
final class EpisodeStarted extends EpisodeEvent {
  /// Creates the event.
  const EpisodeStarted({
    required this.episodeId,
    required this.engineVersion,
    required this.packRef,
    required this.settings,
    required this.actor,
    this.visibility = const Public(),
  });

  /// The episode's id.
  final String episodeId;

  /// Engine version that started the episode.
  final String engineVersion;

  /// The pinned pack.
  final PackRef packRef;

  /// Initial GM settings.
  final EpisodeSettings settings;

  @override
  final Actor actor;

  @override
  final Visibility visibility;

  @override
  bool operator ==(Object other) =>
      other is EpisodeStarted &&
      other.episodeId == episodeId &&
      other.engineVersion == engineVersion &&
      other.packRef == packRef &&
      other.settings == settings &&
      other.actor == actor &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(
    EpisodeStarted,
    episodeId,
    engineVersion,
    packRef,
    settings,
    actor,
    visibility,
  );

  @override
  String toString() =>
      'EpisodeStarted($episodeId, engine $engineVersion, $packRef)';
}
