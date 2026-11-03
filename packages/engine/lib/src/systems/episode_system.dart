import '../commands/commands.dart';
import '../decision.dart';
import '../events/events.dart';
import '../pack/rules_pack.dart';
import '../state/episode_state.dart';
import '../version.dart';

/// The episode's lifecycle: starting it and its settings. Proposed system;
/// 01 §Systems does not list one for this.
final class EpisodeSystem {
  /// Creates the system for [pack].
  const EpisodeSystem(this.pack);

  /// The pack the engine is bound to.
  final RulesPack pack;

  /// Decides an [EpisodeCommand].
  Decision decide(EpisodeState state, EpisodeCommand command) =>
      switch (command) {
        StartEpisode() => _start(state, command),
      };

  /// Applies an [EpisodeEvent].
  EpisodeState evolve(EpisodeState state, EpisodeEvent event) =>
      switch (event) {
        EpisodeStarted() => state.copyWith(
          meta: EpisodeMeta(
            episodeId: event.episodeId,
            engineVersion: event.engineVersion,
            packRef: event.packRef,
            settings: event.settings,
          ),
        ),
      };

  Decision _start(EpisodeState state, StartEpisode command) {
    if (state.started) {
      return const Rejected(
        Rejection(
          RejectionCode.alreadyStarted,
          'The episode has already started.',
        ),
      );
    }
    if (command.episodeId.isEmpty) {
      return const Rejected(
        Rejection(RejectionCode.invalidValue, 'The episode id is empty.'),
      );
    }
    return Accepted([
      EpisodeStarted(
        episodeId: command.episodeId,
        engineVersion: engineVersion,
        packRef: pack.ref,
        settings: command.settings,
        actor: command.actor,
      ),
    ]);
  }
}
