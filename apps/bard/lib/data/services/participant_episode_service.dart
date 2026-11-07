import 'dart:async';
import 'dart:convert';

import 'package:engine/engine.dart' hide Visibility;
import 'package:session/session.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../models.dart';
import '../protocol_engine_codec.dart';
import 'episode_projection.dart';
import 'episode_service.dart';

/// Where a joined player's link stands, for the status line.
enum JoinStatus {
  /// Opening the link or waiting for the host's welcome.
  connecting,

  /// The host welcomed this player. The host sends the player's entries in
  /// frames right after the welcome, so the state may still be empty: wait
  /// for the player's agent before acting.
  joined,

  /// The link dropped; the reconnect loop is trying again.
  reconnecting,

  /// The host or the transport refused; nothing more will be tried.
  refused,

  /// The player left.
  closed,
}

/// [EpisodeService] for a player who joined a LAN host (04 §Participants).
///
/// The state is the player's own perspective, built by an
/// [EpisodeParticipant] from the entries the host sends; requests go to the
/// host over the link, and a [Reconnector] keeps it open (a dropped player
/// resyncs from its last `seq`). The log is narrated here from those
/// entries, because the host sends events, never text.
///
/// Only the player side of [EpisodeService] works: the GM's commands throw
/// [UnsupportedError], since a joined machine shows the dossier only.
class ParticipantEpisodeService implements EpisodeService {
  ParticipantEpisodeService._(this._participant, this._pack, this.aliasId)
    : _projection = EpisodeProjection(_pack),
      _narrator = Narrator(_pack);

  /// Joins the host at [address] over [transport] as [agentId] playing
  /// [aliasId], with the shipped [pack]. Returns at once; [status] follows
  /// the link.
  static ParticipantEpisodeService join({
    required RulesPack pack,
    required Transport transport,
    required Address address,
    required String agentId,
    required String aliasId,
    DiagnosticLog? diagnostics,
    Liveness liveness = const Liveness(),
  }) {
    final participant = EpisodeParticipant(
      // The host keys the episode by its own id; a participant's id only
      // labels its envelopes.
      episodeId: 'lan',
      agentId: agentId,
      aliasId: aliasId,
      engine: Engine(pack),
      codec: const ProtocolEngineCodec(),
      diagnostics: diagnostics,
      liveness: liveness,
    );
    final service = ParticipantEpisodeService._(participant, pack, aliasId);
    diagnostics?.addSink(_StatusSink(service._status));
    participant.entries.listen(service._apply);
    participant.rejections.listen(
      (r) => service._error.value = r.message ?? 'The Handler refused that.',
    );
    service._reconnector = Reconnector(
      participant: participant,
      transport: transport,
      address: address,
      diagnostics: diagnostics,
    );
    unawaited(service._run());
    return service;
  }

  final EpisodeParticipant _participant;
  final RulesPack _pack;
  final EpisodeProjection _projection;
  final Narrator _narrator;
  late final Reconnector _reconnector;

  /// The alias this machine plays.
  final String aliasId;

  final Signal<JoinStatus> _status = signal(JoinStatus.connecting);
  final Signal<String?> _refusal = signal(null);
  final Signal<List<AgentSheet>> _agents = signal(const []);
  final Signal<List<LogEntry>> _log = signal(const []);
  final Signal<List<PhoneThreadData>> _phone = signal(const []);
  final Signal<String?> _error = signal(null);
  final List<Event> _visible = [];
  final List<String> _received = [];
  final Signal<List<ActionRequestItem>> _noRequests = signal(const []);
  final Signal<List<ReviewItem>> _noReview = signal(const []);
  final Signal<List<LogEntry>> _noLog = signal(const []);
  final Signal<List<PhoneThreadData>> _noPhone = signal(const []);

  /// Every entry received so far, one JSON object per line as on the wire:
  /// this player's view of the game log, for a report.
  String receivedEntriesJsonl() =>
      _received.isEmpty ? '' : '${_received.join('\n')}\n';

  /// Where the link stands.
  ReadonlySignal<JoinStatus> get status => _status;

  /// Why the join was refused, once [status] is [JoinStatus.refused].
  ReadonlySignal<String?> get refusal => _refusal;

  /// The last `seq` received.
  int get lastSeq => _participant.lastSeq;

  Future<void> _run() async {
    final stop = await _reconnector.run();
    if (_status.value == JoinStatus.closed) return;
    final reason = switch (stop) {
      ReconnectStop.refused => _participant.refusal?.reason.wire,
      ReconnectStop.connectRefused => 'joinCode',
      ReconnectStop.badAddress => 'address',
      ReconnectStop.stopped => null,
    };
    if (stop == ReconnectStop.stopped) return;
    _refusal.value = switch (reason) {
      'notInvited' => 'The Handler has no agent with that code.',
      'aliasLocked' => 'Another player has already joined with that code.',
      'joinCode' => 'The join code is wrong.',
      'address' => 'That is not a host address.',
      _ => 'The host refused the join ($reason).',
    };
    _status.value = JoinStatus.refused;
  }

  void _apply(List<EventEntry> batch) {
    final state = _participant.state;
    // A new list each batch, so the signal sees a change.
    final log = [..._log.value];
    for (final entry in batch) {
      _received.add(jsonEncode(entry.toJson(const ProtocolEngineCodec())));
      switch (entry) {
        case FullEntry(:final event):
          _visible.add(event);
          final line = _narrator.narrate(state, event).player;
          final shown = _projection.entry(event, line, state, forPlayer: true);
          if (shown != null) log.add(shown);
        case RedactedEntry():
          log.add(const TextEntry(EpisodeProjection.redactedLine));
        case HiddenEntry():
          break;
      }
    }
    _log.value = log;
    _agents.value = _projection.agents(state);
    final names = {for (final a in _agents.value) a.id: a.name};
    _phone.value = _projection.playerThreads(
      _visible,
      aliasId,
      names,
      state: state,
    );
  }

  Future<void> _request(Command command) async {
    try {
      await _participant.request(command);
      _error.value = null;
    } on ArgumentError catch (e) {
      _error.value = '${e.message}';
    } on Object catch (e) {
      _error.value = 'The request could not be sent: $e';
    }
  }

  // --- player side -------------------------------------------------------

  @override
  Future<void> dispose() async {
    _status.value = JoinStatus.closed;
    _reconnector.stop();
    await _participant.close();
  }

  @override
  ReadonlySignal<List<AgentSheet>> get agents => _agents;

  @override
  ReadonlySignal<String?> get lastError => _error;

  @override
  ReadonlySignal<List<LogEntry>> playerLog(String agentId) => _log;

  @override
  ReadonlySignal<List<PhoneThreadData>> playerPhone(String agentId) => _phone;

  @override
  Future<void> requestAction(String agentId, String description) async {
    final entity = _projection.entityOf(_participant.state, aliasId);
    if (entity == null) {
      _error.value = 'Your agent is not here yet.';
      return;
    }
    await _request(
      RequestAction(
        entity: entity,
        description: description,
        actor: AliasActor(AliasId(aliasId)),
      ),
    );
  }

  @override
  Future<void> sendPhone(String? fromAgentId, String threadId, String text) =>
      _request(
        SendPhoneMessage(
          from: PhoneAlias(AliasId(aliasId)),
          to: _projection.partyOf(threadId),
          text: text,
          actor: AliasActor(AliasId(aliasId)),
        ),
      );

  @override
  List<SkillOption> get skills => [
    for (final s in _pack.skills)
      if (s.attribute != null)
        SkillOption(id: s.id, name: s.name, attribute: s.attribute!),
  ];

  @override
  List<DifficultyOption> get difficulties => [
    for (final d in _pack.difficultyCategories)
      DifficultyOption(key: d.key, name: d.name, dc: d.dc),
  ];

  @override
  List<ConditionOption> get conditions => [
    for (final c in _pack.conditions) ConditionOption(id: c.id, name: c.name),
  ];

  @override
  CreationLimits get creationLimits => CreationLimits(
    points: _pack.attributeCreation.points,
    min: _pack.attributeCreation.minPerAttribute,
    max: _pack.attributeCreation.maxPerAttribute,
    attributes: [
      for (final a in _pack.attributes)
        AttributeOption(key: a.key, name: a.name),
    ],
  );

  // --- the Handler's side: not on a joined machine ------------------------

  static Never _gmOnly() =>
      throw UnsupportedError('Only the host runs the Handler console.');

  @override
  ReadonlySignal<List<ActionRequestItem>> get requests => _noRequests;

  @override
  ReadonlySignal<List<ReviewItem>> get reviewTray => _noReview;

  @override
  ReadonlySignal<List<LogEntry>> get gmLog => _noLog;

  @override
  ReadonlySignal<List<LogEntry>> get tableLog => _noLog;

  @override
  ReadonlySignal<List<PhoneThreadData>> get gmPhone => _noPhone;

  @override
  Future<String?> addAgent(String name, Map<String, int> scores) => _gmOnly();

  @override
  Future<void> proposeCondition(String agentId, String conditionId) =>
      _gmOnly();

  @override
  Future<void> clearCondition(String agentId, String conditionId) => _gmOnly();

  @override
  Future<void> resolveRequest(
    String requestId,
    String skillId,
    String difficultyKey,
  ) => _gmOnly();

  @override
  Future<void> declineRequest(String requestId) => _gmOnly();

  @override
  Future<void> proposeSanityLoss(String agentId, int amount) => _gmOnly();

  @override
  Future<void> editReview(String reviewId, int amount) => _gmOnly();

  @override
  Future<void> confirmReview(String reviewId) => _gmOnly();

  @override
  Future<void> addGmNote(String text) => _gmOnly();

  @override
  Future<List<BroadcastPreviewItem>> previewBroadcast(
    String attribute,
    BroadcastOp op,
    int value,
  ) => _gmOnly();

  @override
  Future<String?> broadcast(
    String text,
    String attribute,
    BroadcastOp op,
    int value,
  ) => _gmOnly();
}

/// Follows the participant's network diagnostics to update the status line,
/// so no timer polls the link.
class _StatusSink implements DiagnosticSink {
  _StatusSink(this._status);

  final Signal<JoinStatus> _status;

  @override
  void write(DiagnosticEntry entry) {
    if (_status.value case JoinStatus.closed || JoinStatus.refused) return;
    switch (entry.kind) {
      case 'hello.welcomed':
        _status.value = JoinStatus.joined;
      case 'link.closed' || 'link.lost' || 'link.timeout':
        if (_status.value == JoinStatus.joined) {
          _status.value = JoinStatus.reconnecting;
        }
    }
  }
}
