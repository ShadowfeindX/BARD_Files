part of 'commands.dart';

/// Commands handled by `EpisodeSystem`: the episode's lifecycle.
sealed class EpisodeCommand extends Command {
  const EpisodeCommand();
}

/// Starts an episode on the engine's pack. Must be the first command.
final class StartEpisode extends EpisodeCommand {
  /// Creates a start command.
  const StartEpisode({
    required this.episodeId,
    this.settings = const EpisodeSettings(),
    this.actor = const GmActor(),
  });

  /// The episode's id, chosen outside the engine.
  final String episodeId;

  /// Initial GM settings.
  final EpisodeSettings settings;

  @override
  final Actor actor;

  @override
  bool operator ==(Object other) =>
      other is StartEpisode &&
      other.episodeId == episodeId &&
      other.settings == settings &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(StartEpisode, episodeId, settings, actor);

  @override
  String toString() => 'StartEpisode($episodeId, $settings, by $actor)';
}
