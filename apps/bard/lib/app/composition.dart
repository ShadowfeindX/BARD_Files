import 'dart:io';
import 'dart:math';

import 'package:backend/backend.dart';
import 'package:engine/engine.dart' show RulesPack, loadPack;
import 'package:flutter/services.dart';
import 'package:session/session.dart';

import '../data/lan_access.dart';
import '../data/pack_assets.dart';
import '../data/report_saver.dart';
import '../data/services/episode_service.dart';
import '../data/services/participant_episode_service.dart';
import '../data/services/session_episode_service.dart';

/// How this machine takes part in play (04 §Play modes).
enum PlayMode {
  /// "In person, one device": every panel on this machine, nothing on the
  /// network.
  oneDevice,

  /// This machine hosts over the LAN and runs the Handler console.
  host,

  /// This machine joined a LAN host as one player.
  join,
}

/// What players need to reach this host: shown on the Handler's screen.
class HostInfo {
  /// Creates the description.
  const HostInfo({
    required this.joinCode,
    required this.port,
    required this.addresses,
  });

  /// The code players type.
  final String joinCode;

  /// The port the host listens on.
  final int port;

  /// This machine's LAN addresses (IPv4, loopback left out).
  final List<String> addresses;
}

/// The campaign the demo keeps NPC notes under: one fixed campaign, since
/// the demo has no campaign records yet.
const String demoCampaignId = 'demo';

/// The one place services are built and injected (07 §Layering).
class Composition {
  /// Creates a composition over [episode].
  Composition({
    required this.episode,
    this.mode = PlayMode.oneDevice,
    this.hosting,
    this.reports,
    this.local,
    this.pack,
    this._onDispose,
  });

  /// Composition backed by a real host over the shipped pack, in "in person,
  /// one device" mode. The episode is kept in memory.
  ///
  /// [seedDemoAgents] adds two demo agents; a new episode leaves it false.
  /// With [local], reports can be saved into its reports folder.
  static Future<Composition> inProcess(
    AssetBundle bundle, {
    bool seedDemoAgents = true,
    LocalData? local,
  }) async {
    final diagnostics = DiagnosticLog();
    final service = await SessionEpisodeService.open(
      await loadPackFiles(bundle),
      seedDemoAgents: seedDemoAgents,
      diagnostics: diagnostics,
    );
    return Composition(
      episode: service,
      local: local,
      pack: service.pack,
      reports: local == null
          ? null
          : _hostReports(service, diagnostics, local, transport: 'none'),
    );
  }

  /// Hosts over the LAN on this machine, with the episode kept on disk in
  /// [local].
  ///
  /// Resumes the episode this machine hosted last, so a killed host carries
  /// on from its store, with the same join code and, when it is free, the
  /// same port, so players reconnect on their own. [newEpisode] starts a
  /// fresh one instead (with two demo agents when [seedDemoAgents]).
  /// Listens on every IPv4 interface unless [bindAddress] is given, at
  /// [port] when it is not 0.
  static Future<Composition> host(
    Map<String, String> packFiles,
    LocalData local, {
    bool newEpisode = false,
    bool seedDemoAgents = true,
    InternetAddress? bindAddress,
    int port = 0,
  }) async {
    final saved = newEpisode ? null : await local.settings.lastHostedEpisode();
    final episodeId = saved?.episodeId ?? _newEpisodeId();
    await local.settings.setLastHostedEpisode(
      HostedEpisode(episodeId: episodeId),
    );
    final diagnostics = DiagnosticLog(
      sinks: [
        DiagnosticFileSink(File(local.paths.hostDiagnosticLog(episodeId))),
      ],
    );
    final store = StoreActor(
      store: local.events,
      clock: const SystemClock(),
      snapshotInterval: await local.hostSettings.snapshotInterval(),
    );
    late final SessionEpisodeService service;
    service = await SessionEpisodeService.open(
      packFiles,
      episodeId: episodeId,
      seedDemoAgents: seedDemoAgents,
      store: store,
      diagnostics: diagnostics,
      verifier: const LanVerifier(),
      admission: LanAdmission(() => service.aliasIds),
      authorizer: lanAuthorizer,
    );
    final LanHostTransport transport;
    try {
      transport = await _bind(
        bindAddress,
        port != 0 ? port : saved?.port,
        saved?.joinCode,
        diagnostics,
      );
      await local.settings.setLastHostedEpisode(
        HostedEpisode(
          episodeId: episodeId,
          joinCode: transport.joinCode,
          port: transport.port,
        ),
      );
    } catch (_) {
      await service.dispose();
      rethrow;
    }
    service.listen(transport, liveness: const Liveness());
    return Composition(
      episode: service,
      mode: PlayMode.host,
      local: local,
      pack: service.pack,
      hosting: HostInfo(
        joinCode: transport.joinCode,
        port: transport.port,
        addresses: await lanAddresses(),
      ),
      reports: _hostReports(service, diagnostics, local, transport: 'lan'),
      onDispose: transport.close,
    );
  }

  /// Joins the LAN host at [info] as the agent whose code is [aliasId].
  ///
  /// This machine's agent id is made once and kept in [local]. The link
  /// opens in the background; the service's status follows it.
  static Future<Composition> join(
    Map<String, String> packFiles,
    LocalData local, {
    required LanJoinInfo info,
    required String aliasId,
  }) async {
    final loaded = loadPack(packFiles);
    final pack = loaded.pack;
    if (pack == null) {
      throw StateError(
        'The rules pack did not load:\n${loaded.issues.join('\n')}',
      );
    }
    final agentId = await local.settings.localAgentId(_newAgentId);
    final logId = 'joined-${_stamp()}';
    final diagnostics = DiagnosticLog(
      sinks: [DiagnosticFileSink(File(local.paths.joinedDiagnosticLog(logId)))],
    );
    final service = ParticipantEpisodeService.join(
      pack: pack,
      transport: LanClientTransport(diagnostics: diagnostics),
      address: info.address,
      agentId: agentId,
      aliasId: aliasId,
      diagnostics: diagnostics,
    );
    return Composition(
      episode: service,
      mode: PlayMode.join,
      local: local,
      pack: pack,
      reports: ReportSaver(
        episodeId: logId,
        // A player keeps no store: the report carries the session's
        // diagnostics and the host's report carries the log.
        store: InMemoryEventStore(),
        log: diagnostics,
        folder: local.paths.reportsFolder,
        pack: pack.ref,
        settings: () async => {
          'transport': 'lan',
          'role': 'player',
          'alias': aliasId,
          'address': info.host,
          'lastSeq': service.lastSeq,
        },
      ),
    );
  }

  /// The running episode.
  final EpisodeService episode;

  /// How this machine takes part.
  final PlayMode mode;

  /// Join details, when this machine hosts.
  final HostInfo? hosting;

  /// Saves report bundles, or null when this machine has no local folder.
  final ReportSaver? reports;

  /// This machine's local data, or null in tests that run without it.
  final LocalData? local;

  /// The pack in play.
  final RulesPack? pack;

  final Future<void> Function()? _onDispose;

  /// Closes the episode and anything this composition opened for it. The
  /// local data stays open: it belongs to the app.
  Future<void> dispose() async {
    await episode.dispose();
    await _onDispose?.call();
  }

  /// Binds at [port], or at any free port when it is null or (for a saved
  /// port) taken.
  static Future<LanHostTransport> _bind(
    InternetAddress? address,
    int? port,
    String? joinCode,
    DiagnosticLog diagnostics,
  ) async {
    if (port != null) {
      try {
        return await LanHostTransport.bind(
          address: address,
          port: port,
          joinCode: joinCode,
          diagnostics: diagnostics,
        );
      } on SocketException {
        diagnostics.record(DiagnosticCategory.network, 'lan.portTaken', {
          'port': port,
        });
      }
    }
    return LanHostTransport.bind(
      address: address,
      joinCode: joinCode,
      diagnostics: diagnostics,
    );
  }

  static ReportSaver _hostReports(
    SessionEpisodeService service,
    DiagnosticLog diagnostics,
    LocalData local, {
    required String transport,
  }) => ReportSaver(
    episodeId: service.episodeId,
    store: service.store,
    log: diagnostics,
    folder: local.paths.reportsFolder,
    pack: service.pack.ref,
    settings: () async => {
      'transport': transport,
      'role': 'handler',
      'snapshotIntervalSeconds':
          (await local.hostSettings.snapshotInterval()).inSeconds,
      'autoConfirm': service.autoConfirm,
      'lastSeq': service.lastSeq,
    },
    storeHealth: transport == 'none'
        ? null
        : () async => (await local.events.health(service.episodeId)).toJson(),
    notes: () => local.notes.exportCampaign(demoCampaignId),
  );

  static String _stamp() => DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[-:]'), '')
      .split('.')
      .first;

  static String _newEpisodeId() => 'lan-${_stamp()}';

  static String _newAgentId() {
    final random = Random.secure();
    return 'p-${List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join()}';
  }
}
