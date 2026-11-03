import 'package:flutter/services.dart';

import '../data/pack_assets.dart';
import '../data/services/episode_service.dart';
import '../data/services/session_episode_service.dart';

/// The one place services are built and injected (07 §Layering).
class Composition {
  /// Creates a composition over [episode].
  const Composition({required this.episode});

  /// Composition backed by a real host over the shipped pack, in "in person,
  /// one device" mode.
  ///
  /// [seedDemoAgents] adds two demo agents; a new episode leaves it false.
  static Future<Composition> inProcess(
    AssetBundle bundle, {
    bool seedDemoAgents = true,
  }) async => Composition(
    episode: await SessionEpisodeService.open(
      await loadPackFiles(bundle),
      seedDemoAgents: seedDemoAgents,
    ),
  );

  /// The running episode.
  final EpisodeService episode;
}
