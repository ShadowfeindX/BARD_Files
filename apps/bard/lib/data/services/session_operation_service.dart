import 'dart:async';

import 'package:engine/engine.dart' hide Visibility;
import 'package:protocol/protocol.dart' hide PackPin, Rejected;
import 'package:session/session.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../models.dart';
import '../protocol_engine_codec.dart';
import 'operation_service.dart';

/// [OperationService] over a real `OperationHost` in "in person, one device"
/// mode (04 §Play modes): the GM's commands and the players' requests all go
/// through the host's loop, held consequences wait in its review gate, and
/// every log is the per-perspective view of the stored events.
///
/// Players act through [OperationHost.submit] with their alias as the actor
/// because no transport is involved on one device; the transport path
/// (authorization per player) comes with the networked modes.
class SessionOperationService implements OperationService {
  SessionOperationService._(this._host, this._store, this._pack);

  static const _operationId = 'demo';

  /// Fixed demo seed so a run is reproducible; the rolls are still logged.
  static final RngSeed demoSeed = RngSeed(1, 2, 3, 4);

  /// Opens an operation from [packFiles], starts it, and adds two demo
  /// agents. Throws [StateError] listing the pack problems if it fails.
  static Future<SessionOperationService> open(
    Map<String, String> packFiles,
  ) async {
    final loaded = loadPack(packFiles);
    final pack = loaded.pack;
    if (pack == null) {
      throw StateError(
        'The rules pack did not load:\n${loaded.issues.join('\n')}',
      );
    }
    final store = InMemoryEventStore();
    final host = await OperationHost.open(
      operationId: _operationId,
      gm: const Principal(agentId: 'gm', isGm: true),
      engine: Engine(pack),
      codec: const ProtocolEngineCodec(),
      store: store,
      rngFactory: (draws) => XoshiroRng(demoSeed, drawCount: draws),
      verifier: _NoLinksVerifier(),
    );
    final service = SessionOperationService._(host, store, pack);
    await service._seed();
    host.states.listen((_) => unawaited(service._refresh()));
    host.pendingChanges.listen((_) => unawaited(service._refresh()));
    return service;
  }

  final OperationHost _host;
  final InMemoryEventStore _store;
  final RulesPack _pack;

  final Signal<List<AgentSheet>> _agents = signal(const []);
  final Signal<List<ActionRequestItem>> _requests = signal(const []);
  final Signal<List<ReviewItem>> _review = signal(const []);
  final Signal<List<LogEntry>> _gmLog = signal(const []);
  final Signal<List<LogEntry>> _tableLog = signal(const []);
  final Map<String, Signal<List<LogEntry>>> _playerLogs = {};
  final Signal<String?> _error = signal(null);
  final List<TextEntry> _notes = [];
  final Map<String, int> _edits = {};
  List<LogEntry> _gmEvents = const [];

  /// Demo aliases and the skills they hold, as GM-entered creation data. The
  /// scores spread the pack's creation points; they are demo data, not rules.
  static const _demoAliases = {'vale': 'Agent Vale', 'quill': 'Agent Quill'};

  Future<void> _seed() async {
    await _host.submit(const StartOperation(operationId: _operationId));
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
  ReadonlySignal<List<AgentSheet>> get agents => _agents;

  @override
  ReadonlySignal<List<ActionRequestItem>> get requests => _requests;

  @override
  ReadonlySignal<List<ReviewItem>> get reviewTray => _review;

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

  EntityId _entityOf(String alias) => _host.state.stores
      .all(Identity.componentType)
      .entries
      .firstWhere((e) => e.value.ownerAlias == AliasId(alias))
      .key;

  // --- commands ----------------------------------------------------------

  Future<SubmitResult> _submit(Command command) async {
    final result = await _host.submit(command);
    _error.value = result is Refusal ? result.message : null;
    await _refresh();
    return result;
  }

  @override
  Future<void> requestAction(String agentId, String description) async {
    await _submit(
      RequestAction(
        entity: _entityOf(agentId),
        description: description,
        actor: AliasActor(AliasId(agentId)),
      ),
    );
  }

  @override
  Future<void> resolveRequest(
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

  @override
  Future<void> declineRequest(String requestId) =>
      _submit(DeclineRequest(request: RequestId(requestId)));

  @override
  Future<void> proposeSanityLoss(String agentId, int amount) => _submit(
    ApplySanityLoss(
      entity: _entityOf(agentId),
      amount: amount,
      visibility: AliasesOnly({AliasId(agentId)}),
    ),
  );

  @override
  Future<void> editReview(String reviewId, int amount) async {
    _edits[reviewId] = amount;
    await _refresh();
  }

  @override
  Future<void> confirmReview(String reviewId) async {
    final batches = _host.pending;
    if (batches.isEmpty) return;
    if (_batchId(batches.first) != reviewId) {
      _error.value = 'Confirm held items in the order they were held.';
      return;
    }
    final amount = _edits.remove(reviewId);
    try {
      await _host.confirmPending(
        edit: amount == null
            ? null
            : (e) => e is SanityLost ? e.withAmount(amount) : e,
      );
      _error.value = null;
    } on ArgumentError catch (e) {
      _error.value = '${e.message}';
    }
    await _refresh();
  }

  @override
  Future<void> addGmNote(String text) async {
    _notes.add(TextEntry('GM note: $text', gmNote: true));
    await _refresh();
  }

  // --- projection --------------------------------------------------------

  static String _batchId(PendingBatch b) => 'batch${identityHashCode(b)}';

  Future<void> _refresh() async {
    final state = _host.state;
    final stats = DerivedStats(_pack);
    final identities = state.stores.all(Identity.componentType);
    _agents.value = [
      for (final e in identities.entries)
        if (e.value.ownerAlias != null) _sheet(state, stats, e.key, e.value),
    ];
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
            ),
    ];
    final events = await _store.read(_operationId).toList();
    final text = {
      await for (final t in _store.readText(_operationId)) t.seq: t,
    };
    List<LogEntry> view(Perspective p, String? alias) => [
      for (final stored in events)
        ..._entriesFor(stored, text[stored.seq]!, p, alias, state),
    ];
    _gmEvents = view(const GmPerspective(), null);
    _gmLog.value = [..._gmEvents, ..._notes];
    _tableLog.value = view(const TablePerspective(), null);
    for (final alias in _demoAliases.keys) {
      final log = _playerLogs.putIfAbsent(alias, () => signal(const []));
      log.value = view(PlayerPerspective(AliasId(alias)), alias);
    }
  }

  AgentSheet _sheet(
    OperationState state,
    DerivedStats stats,
    EntityId id,
    Identity who,
  ) {
    final vitals = stats.vitals(state, id);
    final scores = state.stores.get(Attributes.componentType, id)?.scores;
    return AgentSheet(
      id: who.ownerAlias!.value,
      name: who.name,
      attributes: scores?.asMap() ?? const {},
      health: vitals?.health.toInt() ?? 0,
      sanity: vitals?.sanity.toInt() ?? 0,
    );
  }

  Iterable<LogEntry> _entriesFor(
    StoredEvent stored,
    TextLogLine line,
    Perspective perspective,
    String? alias,
    OperationState state,
  ) {
    final event = const ProtocolEngineCodec().decodeEvent(stored.event);
    return switch (deliveryFor(event.visibility, perspective)) {
      Delivery.hidden => const [],
      Delivery.redacted => [
        TextEntry(line.variants['redacted'] ?? 'The Handler did something.'),
      ],
      Delivery.full => [
        _full(projectFor(event, perspective), line, perspective, alias, state),
      ],
    };
  }

  LogEntry _full(
    Event event,
    TextLogLine line,
    Perspective perspective,
    String? alias,
    OperationState state,
  ) {
    if (event is CheckResolved) return RollEntry(_breakdown(event, state));
    final v = line.variants;
    final text = switch (perspective) {
      GmPerspective() => v['gm'],
      PlayerPerspective() => v['alias:$alias'] ?? v['public'],
      TablePerspective() => v['public'],
    };
    return TextEntry(text ?? v['gm'] ?? '');
  }

  DiceBreakdownData _breakdown(CheckResolved event, OperationState state) {
    final b = event.breakdown;
    final spec = event.spec;
    final name = state.stores.get(Identity.componentType, spec.entity)?.name;
    final skillName = spec.skill == null
        ? null
        : _pack.skills.where((s) => s.id == spec.skill).firstOrNull?.name;
    DiceGroup group(String label, Term term) => DiceGroup(
      label: label,
      dice: [
        if (term is DiceTerm)
          for (final roll in term.rolls)
            for (var i = 0; i < roll.faces.length; i++)
              DieResult(roll.faces[i], exploded: i < roll.faces.length - 1),
      ],
      subtotal: term.value.toInt(),
    );
    final proficiency = b.proficiency;
    return DiceBreakdownData(
      title: '${name ?? '?'}: ${skillName ?? b.attribute}',
      groups: [
        group('Primary d6', b.primary),
        if (proficiency != null) group('Proficiency', proficiency),
      ],
      modifiers: [
        ModifierLine(b.attribute, b.attributeScore),
        for (final m in b.modifiers) ModifierLine(m.label, m.value),
      ],
      total: b.total.toInt(),
      dc: spec.dc,
      dcLabel: _pack.difficultyCategories
          .where((d) => d.key == spec.category)
          .firstOrNull
          ?.name,
      outcome: switch (event.outcome) {
        CheckOutcome.success => CheckOutcomeKind.success,
        CheckOutcome.partialSuccess => CheckOutcomeKind.partial,
        CheckOutcome.failure => CheckOutcomeKind.failure,
      },
    );
  }
}

/// One-device mode has no links, so no identity is ever verified here.
class _NoLinksVerifier implements IdentityVerifier {
  @override
  Future<Principal?> verify(Hello hello) async => null;
}
