import 'dart:async';

import 'package:engine/engine.dart' hide Visibility;
import 'package:protocol/protocol.dart' hide PackPin, Rejected;
import 'package:session/session.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../models.dart';
import '../protocol_engine_codec.dart';
import 'episode_projection.dart';
import 'episode_service.dart';

/// [EpisodeService] over a real `EpisodeHost` in "in person, one device"
/// mode (04 §Play modes): the GM's commands and the players' requests all go
/// through the host's loop, held consequences wait in its review gate, and
/// every log is the per-perspective view of the stored events.
///
/// Players act through [EpisodeHost.submit] with their alias as the actor
/// because no transport is involved on one device; the transport path
/// (authorization per player) comes with the networked modes.
class SessionEpisodeService implements EpisodeService {
  SessionEpisodeService._(this._host, this._store, this._pack)
    : _projection = EpisodeProjection(_pack);

  /// The episode id one-device play uses.
  static const String oneDeviceEpisodeId = 'demo';

  /// Fixed demo seed so a run is reproducible; the rolls are still logged.
  static final RngSeed demoSeed = RngSeed(1, 2, 3, 4);

  /// Opens episode [episodeId] from [packFiles] over [store] (default: a
  /// new in-memory store).
  ///
  /// An empty store is a new episode: it is started, and with
  /// [seedDemoAgents] two demo agents are added (a new episode passes false
  /// and the GM adds agents). A store that holds the episode resumes it from
  /// its log and adds nothing. [verifier], [admission] and [authorizer]
  /// decide who may join over a transport given to [listen]; the defaults
  /// admit nobody. Throws [StateError] listing the pack problems if it
  /// fails.
  static Future<SessionEpisodeService> open(
    Map<String, String> packFiles, {
    bool seedDemoAgents = true,
    String episodeId = oneDeviceEpisodeId,
    EventStore? store,
    DiagnosticLog? diagnostics,
    IdentityVerifier? verifier,
    Admission? admission,
    Authorizer authorizer = const DefaultAuthorizer(),
  }) async {
    final loaded = loadPack(packFiles);
    final pack = loaded.pack;
    if (pack == null) {
      throw StateError(
        'The rules pack did not load:\n${loaded.issues.join('\n')}',
      );
    }
    final events = store ?? InMemoryEventStore();
    final host = await EpisodeHost.open(
      episodeId: episodeId,
      gm: const Principal(agentId: 'gm', isGm: true),
      engine: Engine(pack),
      codec: const ProtocolEngineCodec(),
      store: events,
      rngFactory: (draws) => XoshiroRng(demoSeed, drawCount: draws),
      verifier: verifier ?? _NoLinksVerifier(),
      admission: admission,
      authorizer: authorizer,
      diagnostics: diagnostics,
    );
    final service = SessionEpisodeService._(host, events, pack);
    try {
      if (host.lastSeq == 0) {
        await service._seed(seedDemoAgents: seedDemoAgents);
      } else {
        service._resume();
        await service._refresh();
      }
    } catch (_) {
      await host.close();
      rethrow;
    }
    host.states.listen((_) => unawaited(service._serial(service._refresh)));
    host.pendingChanges.listen(
      (_) => unawaited(service._serial(service._refresh)),
    );
    return service;
  }

  final EpisodeHost _host;
  final EventStore _store;
  final RulesPack _pack;
  final EpisodeProjection _projection;

  /// The episode's id.
  String get episodeId => _host.episodeId;

  /// The store the episode is kept in, for the report bundle.
  EventStore get store => _store;

  /// The last committed `seq`.
  int get lastSeq => _host.lastSeq;

  /// The pack in play.
  RulesPack get pack => _pack;

  /// Whether held consequences are confirmed without the Handler's review.
  bool get autoConfirm =>
      _host.state.meta?.settings.autoConfirmConsequences ?? false;

  /// The aliases that own an agent: the agent codes players join with.
  Set<String> get aliasIds => {for (final a in _agents.value) a.id};

  /// Accepts players' links from [transport] (LAN hosting).
  void listen(Transport transport, {Liveness? liveness}) =>
      _host.listen(transport, liveness: liveness);

  final Signal<List<AgentSheet>> _agents = signal(const []);
  final Signal<List<ActionRequestItem>> _requests = signal(const []);
  final Signal<List<ReviewItem>> _review = signal(const []);
  final Signal<List<LogEntry>> _gmLog = signal(const []);
  final Signal<List<LogEntry>> _tableLog = signal(const []);
  final Map<String, Signal<List<LogEntry>>> _playerLogs = {};
  final Signal<List<PhoneThreadData>> _gmPhone = signal(const []);
  final Map<String, Signal<List<PhoneThreadData>>> _playerPhones = {};
  final Signal<String?> _error = signal(null);
  int _nextAlias = 0;
  final List<TextEntry> _notes = [];
  final Map<String, int> _edits = {};
  List<LogEntry> _gmEvents = const [];

  /// Demo aliases and the skills they hold, as GM-entered creation data. The
  /// scores spread the pack's creation points; they are demo data, not rules.
  static const _demoAliases = {'vale': 'Agent Vale', 'quill': 'Agent Quill'};

  /// Continues alias numbering after the agents a resumed log holds.
  void _resume() {
    final pattern = RegExp(r'^agent(\d+)$');
    for (final who in _host.state.stores.all(Identity.componentType).values) {
      final match = pattern.firstMatch(who.ownerAlias?.value ?? '');
      final n = match == null ? null : int.parse(match.group(1)!);
      if (n != null && n >= _nextAlias) _nextAlias = n + 1;
    }
  }

  Future<void> _seed({required bool seedDemoAgents}) async {
    final started = await _host.submit(StartEpisode(episodeId: episodeId));
    if (started is Refusal) {
      throw StateError('Could not start the episode: ${started.message}');
    }
    if (!seedDemoAgents) {
      await _refresh();
      return;
    }
    final points = _pack.attributeCreation.points;
    final keys = [for (final a in _pack.attributes) a.key];
    for (final entry in _demoAliases.entries) {
      final scores = {
        for (final k in keys) k: _pack.attributeCreation.minPerAttribute,
      };
      var left = points - scores.values.fold<int>(0, (a, b) => a + b);
      final max = _pack.attributeCreation.maxPerAttribute;
      for (final k in keys) {
        while (left > 0 && scores[k]! < max) {
          scores[k] = scores[k]! + 1;
          left--;
        }
      }
      final result = await _host.submit(
        CreateAgent(
          name: entry.value,
          attributes: scores,
          skills: {for (final s in _pack.skills.take(2)) s.id: 'proficient'},
          ownerAlias: AliasId(entry.key),
          actor: AliasActor(AliasId(entry.key)),
        ),
      );
      if (result is Refusal) {
        throw StateError('Could not create ${entry.value}: ${result.message}');
      }
    }
    await _refresh();
  }

  // --- reads -------------------------------------------------------------

  @override
  Future<void> dispose() => _serial(_host.close);

  @override
  ReadonlySignal<List<AgentSheet>> get agents => _agents;

  @override
  ReadonlySignal<List<ActionRequestItem>> get requests => _requests;

  @override
  ReadonlySignal<List<ReviewItem>> get reviewTray => _review;

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

  @override
  List<ConditionOption> get conditions => [
    for (final c in _pack.conditions) ConditionOption(id: c.id, name: c.name),
  ];

  @override
  Future<String?> addAgent(String name, Map<String, int> scores) => _serial(
    () async {
      final alias = 'agent${_nextAlias++}';
      final result = await _host.submit(
        CreateAgent(name: name, attributes: scores, ownerAlias: AliasId(alias)),
      );
      await _refresh();
      return result is Refusal ? result.message : null;
    },
  );

  @override
  ReadonlySignal<String?> get lastError => _error;

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
  ReadonlySignal<List<LogEntry>> get gmLog => _gmLog;

  @override
  ReadonlySignal<List<LogEntry>> get tableLog => _tableLog;

  @override
  ReadonlySignal<List<LogEntry>> playerLog(String agentId) =>
      _playerLogs.putIfAbsent(agentId, () => signal(const []));

  @override
  ReadonlySignal<List<PhoneThreadData>> get gmPhone => _gmPhone;

  @override
  ReadonlySignal<List<PhoneThreadData>> playerPhone(String agentId) =>
      _playerPhones.putIfAbsent(agentId, () => signal(const []));

  EntityId _entityOf(String alias) =>
      _projection.entityOf(_host.state, alias) ??
      (throw StateError('No agent for alias $alias'));

  // --- commands ----------------------------------------------------------

  /// Runs UI commands and refreshes one at a time, so two quick taps cannot
  /// interleave (a second confirm must see the first one's result).
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<SubmitResult> _submit(Command command) async {
    final result = await _host.submit(command);
    _error.value = result is Refusal ? result.message : null;
    await _refresh();
    return result;
  }

  @override
  Future<void> requestAction(String agentId, String description) =>
      _serial(() => _requestAction(agentId, description));

  @override
  Future<void> resolveRequest(
    String requestId,
    String skillId,
    String difficultyKey,
  ) => _serial(() => _resolveRequest(requestId, skillId, difficultyKey));

  @override
  Future<void> declineRequest(String requestId) =>
      _serial(() => _declineRequest(requestId));

  @override
  Future<void> proposeSanityLoss(String agentId, int amount) =>
      _serial(() => _proposeSanityLoss(agentId, amount));

  @override
  Future<void> proposeCondition(String agentId, String conditionId) =>
      _serial(() => _proposeCondition(agentId, conditionId));

  @override
  Future<void> clearCondition(String agentId, String conditionId) => _serial(
    () => _submit(
      ClearCondition(
        entity: _entityOf(agentId),
        condition: conditionId,
        visibility: AliasesOnly({AliasId(agentId)}),
      ),
    ),
  );

  @override
  Future<void> editReview(String reviewId, int amount) =>
      _serial(() => _editReview(reviewId, amount));

  @override
  Future<void> confirmReview(String reviewId) =>
      _serial(() => _confirmReview(reviewId));

  @override
  Future<void> addGmNote(String text) => _serial(() => _addGmNote(text));

  @override
  Future<List<BroadcastPreviewItem>> previewBroadcast(
    String attribute,
    BroadcastOp op,
    int value,
  ) => _serial(() async {
    final names = _host.state.stores.all(Identity.componentType);
    return [
      for (final c in _host.engine.broadcastPreview(
        _host.state,
        _condition(attribute, op, value),
      ))
        BroadcastPreviewItem(
          agentId: c.alias.value,
          agentName: names[c.entity]?.name ?? '?',
          qualifies: c.qualifies,
          score: c.result?.left,
        ),
    ];
  });

  @override
  Future<String?> broadcast(
    String text,
    String attribute,
    BroadcastOp op,
    int value,
  ) => _serial(() async {
    final result = await _submit(
      BroadcastToQualifying(
        text: text,
        condition: _condition(attribute, op, value),
      ),
    );
    return result is Refusal ? result.message : null;
  });

  @override
  Future<void> sendPhone(String? fromAgentId, String threadId, String text) =>
      _serial(() async {
        final to = _projection.partyOf(threadId);
        await _submit(
          SendPhoneMessage(
            from: fromAgentId == null
                ? const PhoneGm()
                : PhoneAlias(AliasId(fromAgentId)),
            to: to,
            text: text,
            actor: fromAgentId == null
                ? const GmActor()
                : AliasActor(AliasId(fromAgentId)),
          ),
        );
      });

  /// Sends [text] to the agent [toAlias] as the pack NPC [npcId] (row 8's
  /// prepared messages). Returns the refusal message, or null when sent.
  ///
  /// The pack's NPCs are templates, not entities, and a phone message comes
  /// from an entity. So the first message from an NPC brings it into the
  /// episode as a GM-only, unowned agent with the template's name and the
  /// pack's minimum score in every attribute. Those scores are PLACEHOLDER:
  /// an NPC that only speaks never rolls, and an engine command that
  /// introduces an NPC from its template is an open item (09). Later
  /// messages reuse the entity, found by name.
  Future<String?> sendAsNpc(String npcId, String toAlias, String text) =>
      _serial(() async {
        final template = _pack.npcs.where((n) => n.id == npcId).firstOrNull;
        if (template == null) return 'That NPC is not in the pack.';
        var entity = _npcEntity(template.name);
        if (entity == null) {
          final created = await _host.submit(
            CreateAgent(
              name: template.name,
              attributes: {
                for (final a in _pack.attributes)
                  a.key: _pack.attributeCreation.minPerAttribute,
              },
            ),
          );
          if (created is Refusal) {
            _error.value = created.message;
            return created.message;
          }
          entity = _npcEntity(template.name);
          if (entity == null) return 'The NPC could not be added.';
        }
        final result = await _submit(
          SendPhoneMessage(
            from: PhoneNpc(entity),
            to: PhoneAlias(AliasId(toAlias)),
            text: text,
            actor: const GmActor(),
          ),
        );
        return result is Refusal ? result.message : null;
      });

  EntityId? _npcEntity(String name) => _host.state.stores
      .all(Identity.componentType)
      .entries
      .where((e) => e.value.ownerAlias == null && e.value.name == name)
      .firstOrNull
      ?.key;

  /// "[attribute] [op] [value]" as an engine condition.
  Condition _condition(String attribute, BroadcastOp op, int value) =>
      Compare(CompareOp.values.byName(op.name), Attr(attribute), Const(value));

  Future<void> _requestAction(String agentId, String description) async {
    await _submit(
      RequestAction(
        entity: _entityOf(agentId),
        description: description,
        actor: AliasActor(AliasId(agentId)),
      ),
    );
  }

  Future<void> _resolveRequest(
    String requestId,
    String skillId,
    String difficultyKey,
  ) async {
    final request = RequestId(requestId);
    final pending = _host.state.pending.requests[request];
    if (pending == null) return;
    final skill = _pack.skills.firstWhere((s) => s.id == skillId);
    final required = await _submit(
      RequireCheck(
        entity: pending.entity,
        attribute: skill.attribute,
        skill: skillId,
        difficulty: CategoryDifficulty(difficultyKey),
        request: request,
      ),
    );
    if (required is Refusal) return;
    for (final entry in _host.state.pending.checks.entries) {
      if (entry.value.spec.request == request) {
        await _submit(ResolveCheck(check: entry.key));
      }
    }
  }

  Future<void> _declineRequest(String requestId) =>
      _submit(DeclineRequest(request: RequestId(requestId)));

  Future<void> _proposeSanityLoss(String agentId, int amount) => _submit(
    ApplySanityLoss(
      entity: _entityOf(agentId),
      amount: amount,
      visibility: AliasesOnly({AliasId(agentId)}),
    ),
  );

  Future<void> _proposeCondition(String agentId, String conditionId) => _submit(
    ApplyCondition(
      entity: _entityOf(agentId),
      condition: conditionId,
      visibility: AliasesOnly({AliasId(agentId)}),
    ),
  );

  Future<void> _editReview(String reviewId, int amount) async {
    _edits[reviewId] = amount;
    await _refresh();
  }

  Future<void> _confirmReview(String reviewId) async {
    final batches = _host.pending;
    if (batches.isEmpty) return;
    if (_batchId(batches.first) != reviewId) {
      _error.value = 'Confirm held items in the order they were held.';
      return;
    }
    final amount = _edits[reviewId];
    try {
      await _host.confirmPending(
        edit: amount == null
            ? null
            : (e) => e is SanityLost ? e.withAmount(amount) : e,
      );
      _edits.remove(reviewId);
      _error.value = null;
    } on ArgumentError catch (e) {
      _error.value = '${e.message}';
    }
    await _refresh();
  }

  Future<void> _addGmNote(String text) async {
    _notes.add(TextEntry('GM note: $text', gmNote: true));
    await _refresh();
  }

  // --- projection --------------------------------------------------------

  final Expando<String> _batchIds = Expando<String>();
  int _nextBatch = 0;

  String _batchId(PendingBatch b) => _batchIds[b] ??= 'batch${_nextBatch++}';

  Future<void> _refresh() async {
    final state = _host.state;
    final identities = state.stores.all(Identity.componentType);
    _agents.value = _projection.agents(state);
    _requests.value = [
      for (final r in state.pending.requests.entries)
        ActionRequestItem(
          id: r.key.value,
          agentId: identities[r.value.entity]?.ownerAlias?.value ?? '',
          agentName: identities[r.value.entity]?.name ?? '?',
          description: r.value.description,
          status: RequestStatus.pending,
        ),
    ];
    _review.value = [
      for (final batch in _host.pending)
        for (final e in batch.events)
          if (e is SanityLost)
            ReviewItem(
              id: _batchId(batch),
              agentName: identities[e.entity]?.name ?? '?',
              label: 'Sanity loss',
              amount: _edits[_batchId(batch)] ?? e.amount,
              originalAmount: _edits.containsKey(_batchId(batch))
                  ? e.amount
                  : null,
            )
          else if (e is ConditionApplied)
            ReviewItem(
              id: _batchId(batch),
              agentName: identities[e.entity]?.name ?? '?',
              label: 'Condition',
              amount: 0,
              condition: _pack.condition(e.condition)?.name ?? e.condition,
            ),
    ];
    final codec = const ProtocolEngineCodec();
    final events = [
      await for (final stored in _store.read(episodeId))
        (stored.seq, codec.decodeEvent(stored.event)),
    ];
    final text = {await for (final t in _store.readText(episodeId)) t.seq: t};
    List<LogEntry> view(Perspective p, String? alias) => [
      for (final (seq, event) in events)
        ..._entriesFor(event, text[seq]!, p, alias, state),
    ];
    _gmEvents = view(const GmPerspective(), null);
    _gmLog.value = [..._gmEvents, ..._notes];
    _tableLog.value = view(const TablePerspective(), null);
    final names = {for (final a in _agents.value) a.id: a.name};
    _gmPhone.value = _projection.gmThreads([
      for (final (_, e) in events) e,
    ], names);
    for (final alias in names.keys) {
      final perspective = PlayerPerspective(AliasId(alias));
      final log = _playerLogs.putIfAbsent(alias, () => signal(const []));
      log.value = view(perspective, alias);
      final visible = [
        for (final (_, e) in events)
          if (deliveryFor(e.visibility, perspective) == Delivery.full)
            projectFor(e, perspective),
      ];
      final phone = _playerPhones.putIfAbsent(alias, () => signal(const []));
      phone.value = _projection.playerThreads(visible, alias, names);
    }
  }

  Iterable<LogEntry> _entriesFor(
    Event event,
    TextLogLine line,
    Perspective perspective,
    String? alias,
    EpisodeState state,
  ) {
    return switch (deliveryFor(event.visibility, perspective)) {
      Delivery.hidden => const [],
      Delivery.redacted => [
        TextEntry(line.variants['redacted'] ?? EpisodeProjection.redactedLine),
      ],
      Delivery.full => [
        ?_full(projectFor(event, perspective), line, perspective, alias, state),
      ],
    };
  }

  LogEntry? _full(
    Event event,
    TextLogLine line,
    Perspective perspective,
    String? alias,
    EpisodeState state,
  ) {
    final v = line.variants;
    final text = switch (perspective) {
      GmPerspective() => v['gm'],
      PlayerPerspective() => v['alias:$alias'] ?? v['public'],
      TablePerspective() => v['public'],
    };
    return _projection.entry(
      event,
      text,
      state,
      forPlayer: perspective is PlayerPerspective,
    );
  }
}

/// One-device mode has no links, so no identity is ever verified here.
class _NoLinksVerifier implements IdentityVerifier {
  @override
  Future<Principal?> verify(Hello hello) async => null;
}
