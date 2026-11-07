import 'dart:io';
import 'dart:math';

import 'package:backend/backend.dart';
import 'package:engine/engine.dart' show RulesPack, loadPack;
import 'package:flutter/services.dart';
import 'package:session/session.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../data/lan_access.dart';
import '../data/models.dart';

export '../data/models.dart' show HostInfo, PlayMode;
import '../data/pack_assets.dart';
import '../data/report_saver.dart';
import '../data/services/episode_service.dart';
import '../data/services/npc_notes_service.dart';
import '../data/services/participant_episode_service.dart';
import '../data/services/session_episode_service.dart';
import '../ui/console/npc_notes_view_model.dart';

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
    this.status,
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
    // Keep the saved code and port: if this start fails, the next one must
    // still offer players the address they already have.
    await local.settings.setLastHostedEpisode(
      HostedEpisode(
        episodeId: episodeId,
        joinCode: saved?.joinCode,
        port: saved?.port,
      ),
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
    LanHostTransport? transport;
    final List<String> addresses;
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
      addresses = await lanAddresses();
    } catch (_) {
      await transport?.close();
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
        addresses: addresses,
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
    final logId = 'joined-${_stamp()}-${_random(4)}';
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
      status: computed(
        () => switch (service.status.value) {
          JoinStatus.connecting => 'Connecting to the host…',
          JoinStatus.joined => 'Joined as agent $aliasId.',
          JoinStatus.reconnecting => 'Lost the host. Reconnecting…',
          JoinStatus.refused => service.refusal.value ?? 'The host refused.',
          JoinStatus.closed => 'Left the episode.',
        },
      ),
      reports: ReportSaver(
        episodeId: logId,
        // A player keeps no store, so its view of the game log goes in as
        // the entries it received; the host's report has the full log.
        store: InMemoryEventStore(),
        extraFiles: () => {
          'received-entries.jsonl': service.receivedEntriesJsonl(),
        },
        log: diagnostics,
        folder: local.paths.reportsFolder,
        pack: pack.ref,
        settings: () async => {
          'transport': 'lan',
          'role': 'player',
          'aliasId': aliasId,
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

  /// A line about the link, on a joined machine.
  final ReadonlySignal<String>? status;

  /// The Handler's NPC notes panel state, or null where there is no panel:
  /// on a joined machine, or with no local data to keep the notes in.
  ///
  /// Notes belong to [demoCampaignId]; the NPCs are the pack's; a prepared
  /// message goes to an agent's alias through
  /// [SessionEpisodeService.sendAsNpc].
  NpcNotesViewModel? npcNotes() {
    final service = episode;
    final store = local?.notes;
    final npcs = pack?.npcs;
    if (mode == PlayMode.join || store == null || npcs == null) return null;
    return NpcNotesViewModel(
      NpcNotesService(store),
      campaignId: demoCampaignId,
      npcs: [for (final n in npcs) NpcOption(id: n.id, name: n.name)],
      aliases: computed(
        () => [
          for (final a in service.agents.value)
            AliasOption(id: a.id, name: a.name),
        ],
      ),
      sendAs: service is SessionEpisodeService ? service.sendAsNpc : null,
    );
  }

  /// The report button's action, or null when reports cannot be saved.
  ReportAction? get reportAction {
    final saver = reports;
    return saver == null
        ? null
        : ReportAction(
            canIncludeNotes: saver.canIncludeNotes,
            save: saver.save,
          );
  }

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

  // The random part keeps two starts in the same second apart.
  static String _newEpisodeId() => 'lan-${_stamp()}-${_random(4)}';

  static String _random(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
  }

  static String _newAgentId() => 'p-${_random(12)}';
}
