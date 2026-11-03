import 'package:engine/engine.dart';

import 'decisions.dart';
import 'test_pack.dart';

/// A started episode on [testPack] with one agent, driven command by
/// command: each accepted command's events are folded into [state] and
/// appended to [log].
///
/// One [ScriptedRng] serves the whole test, as one RNG serves an episode,
/// so its draw count stays in step with the state.
final class Table {
  /// Starts an episode and creates Agent Vale ([vale], owned by [valeAlias]):
  /// every attribute 2 except STR 1 and LCK 3; Firearms proficient.
  Table({
    Iterable<int> faces = const [],
    EpisodeSettings settings = const EpisodeSettings(),
    RulesPack? pack,
  }) : engine = Engine(pack ?? testPack()),
       rng = ScriptedRng(faces) {
    run(StartEpisode(episodeId: 'op1', settings: settings));
    run(
      CreateAgent(
        name: 'Vale',
        attributes: validScores(),
        skills: {'firearms': 'proficient'},
        ownerAlias: valeAlias,
      ),
    );
  }

  /// The alias that plays Vale.
  static const valeAlias = AliasId('alias-vale');

  /// Vale's entity id.
  static const vale = EntityId('e1');

  /// The engine under test.
  final Engine engine;

  /// The episode's RNG.
  final ScriptedRng rng;

  /// The episode's id source.
  final IdSource ids = SequentialIdSource();

  /// Current state.
  EpisodeState state = const EpisodeState.initial();

  /// Every event so far.
  final List<Event> log = [];

  /// Decides [command] without applying it.
  Decision decide(Command command) => engine.decide(state, command, rng, ids);

  /// Decides [command], which must be accepted, and applies its events.
  List<Event> run(Command command) {
    final events = accepted(decide(command));
    log.addAll(events);
    state = engine.replay(state, events);
    return events;
  }
}
