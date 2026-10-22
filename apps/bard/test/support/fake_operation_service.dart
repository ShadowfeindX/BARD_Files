import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import 'package:bard/data/models.dart';
import 'package:bard/data/services/operation_service.dart';

/// In-memory stand-in for the session, for widget tests of the UI alone. It follows the same visibility shape as the engine (rolls public,
/// consequences held for review, GM notes private) but applies no game rules
/// of its own beyond a fixed fixture: scripted dice, exploding primary die and
/// a subset of the example pack's DC table and its partial band.
class FakeOperationService implements OperationService {
  /// Creates the fake with two agents. [dice] is the scripted die sequence;
  /// it repeats when exhausted.
  FakeOperationService({this.dice = const [6, 3, 4, 2, 5, 1]}) {
    _agents.value = const [
      AgentSheet(
        id: 'vale',
        name: 'Agent Vale',
        attributes: {'STR': 2, 'DEX': 3, 'PER': 3, 'WIS': 2},
        health: 12,
        sanity: 10,
      ),
      AgentSheet(
        id: 'quill',
        name: 'Agent Quill',
        attributes: {'STR': 1, 'DEX': 2, 'PER': 2, 'WIS': 3},
        health: 10,
        sanity: 14,
      ),
    ];
    _refreshPhones();
  }

  /// The scripted die sequence.
  final List<int> dice;
  int _nextDie = 0;
  int _nextId = 0;

  final Signal<List<AgentSheet>> _agents = signal(const []);
  final Signal<List<ActionRequestItem>> _requests = signal(const []);
  final Signal<List<ReviewItem>> _review = signal(const []);
  final Signal<List<LogEntry>> _gmLog = signal(const []);
  final Signal<List<LogEntry>> _tableLog = signal(const []);
  final Map<String, Signal<List<LogEntry>>> _playerLogs = {};
  final Map<String, String> _reviewAgent = {};
  final Signal<String?> _error = signal(null);

  @override
  Future<void> dispose() async {}

  @override
  ReadonlySignal<List<AgentSheet>> get agents => _agents;

  @override
  ReadonlySignal<List<ActionRequestItem>> get requests => _requests;

  @override
  ReadonlySignal<List<ReviewItem>> get reviewTray => _review;

  @override
  CreationLimits get creationLimits => const CreationLimits(
    points: 20,
    min: 1,
    max: 3,
    attributes: [
      AttributeOption(key: 'STR', name: 'Strength'),
      AttributeOption(key: 'DEX', name: 'Dexterity'),
    ],
  );

  @override
  Future<String?> addAgent(String name, Map<String, int> scores) async {
    if (name.trim().isEmpty) return 'A name is required.';
    _agents.value = [
      ..._agents.value,
      AgentSheet(
        id: 'agent${_agents.value.length}',
        name: name,
        attributes: scores,
        health: 10,
        sanity: 10,
      ),
    ];
    _refreshPhones();
    return null;
  }

  @override
  ReadonlySignal<String?> get lastError => _error;

  @override
  final List<SkillOption> skills = const [
    SkillOption(id: 'firearms', name: 'Firearms', attribute: 'DEX'),
    SkillOption(id: 'research', name: 'Research', attribute: 'PER'),
  ];

  @override
  final List<DifficultyOption> difficulties = const [
    DifficultyOption(key: 'F', name: 'Cat-F', dc: 3),
    DifficultyOption(key: 'D', name: 'Cat-D', dc: 7),
    DifficultyOption(key: 'C', name: 'Cat-C', dc: 10),
    DifficultyOption(key: 'B', name: 'Cat-B', dc: 13),
    DifficultyOption(key: 'A', name: 'Cat-A', dc: 17),
    DifficultyOption(key: 'S', name: 'Cat-S', dc: 21),
  ];

  @override
  ReadonlySignal<List<LogEntry>> get gmLog => _gmLog;

  @override
  ReadonlySignal<List<LogEntry>> get tableLog => _tableLog;

  @override
  ReadonlySignal<List<LogEntry>> playerLog(String agentId) =>
      _playerLog(agentId);

  Signal<List<LogEntry>> _playerLog(String id) =>
      _playerLogs.putIfAbsent(id, () => signal(const []));

  void _append(Signal<List<LogEntry>> log, LogEntry entry) =>
      log.value = [...log.value, entry];

  AgentSheet _agent(String id) => _agents.value.firstWhere((a) => a.id == id);

  @override
  Future<void> requestAction(String agentId, String description) async {
    final agent = _agent(agentId);
    final id = 'req${_nextId++}';
    _requests.value = [
      ..._requests.value,
      ActionRequestItem(
        id: id,
        agentId: agentId,
        agentName: agent.name,
        description: description,
        status: RequestStatus.pending,
      ),
    ];
    _append(_gmLog, TextEntry('${agent.name} asks to act: "$description".'));
    _append(_playerLog(agentId), TextEntry('You ask to act: "$description".'));
  }

  void _setStatus(String id, RequestStatus status) {
    _requests.value = [
      for (final r in _requests.value)
        if (r.id == id)
          ActionRequestItem(
            id: r.id,
            agentId: r.agentId,
            agentName: r.agentName,
            description: r.description,
            status: status,
          )
        else
          r,
    ];
  }

  @override
  Future<void> resolveRequest(
    String requestId,
    String skillId,
    String difficultyKey,
  ) async {
    final request = _requests.value.firstWhere((r) => r.id == requestId);
    final agent = _agent(request.agentId);
    final skill = skills.firstWhere((s) => s.id == skillId);
    final difficulty = difficulties.firstWhere((d) => d.key == difficultyKey);
    final score = agent.attributes[skill.attribute] ?? 0;
    final chain = _rollExploding();
    final subtotal = chain.fold<int>(0, (a, d) => a + d.value);
    final total = subtotal + score;
    final outcome = total >= difficulty.dc
        ? CheckOutcomeKind.success
        : total >= difficulty.dc - 2
        ? CheckOutcomeKind.partial
        : CheckOutcomeKind.failure;
    final data = DiceBreakdownData(
      title: '${agent.name}: ${skill.name}',
      groups: [DiceGroup(label: 'Primary d6', dice: chain, subtotal: subtotal)],
      modifiers: [ModifierLine(skill.attribute, score)],
      total: total,
      dc: difficulty.dc,
      dcLabel: difficulty.name,
      outcome: outcome,
    );
    _setStatus(requestId, RequestStatus.resolved);
    final entry = RollEntry(data);
    _append(_gmLog, entry);
    _append(_playerLog(agent.id), entry);
    _append(_tableLog, entry);
  }

  List<DieResult> _rollExploding() {
    final chain = <DieResult>[];
    while (true) {
      final face = dice[_nextDie++ % dice.length];
      final exploded = face == 6;
      chain.add(DieResult(face, exploded: exploded));
      if (!exploded) return chain;
    }
  }

  @override
  Future<void> declineRequest(String requestId) async {
    final request = _requests.value.firstWhere((r) => r.id == requestId);
    _setStatus(requestId, RequestStatus.declined);
    _append(_gmLog, const TextEntry('The Handler declined the request.'));
    _append(
      _playerLog(request.agentId),
      const TextEntry('The Handler declined the request.'),
    );
  }

  @override
  Future<void> proposeSanityLoss(String agentId, int amount) async {
    final agent = _agent(agentId);
    final id = 'rev${_nextId++}';
    _reviewAgent[id] = agentId;
    _review.value = [
      ..._review.value,
      ReviewItem(
        id: id,
        agentName: agent.name,
        label: 'Sanity loss',
        amount: amount,
      ),
    ];
    _append(
      _gmLog,
      TextEntry('${agent.name} would lose $amount Sanity (held).'),
    );
  }

  @override
  Future<void> editReview(String reviewId, int amount) async {
    _review.value = [
      for (final r in _review.value)
        if (r.id == reviewId)
          ReviewItem(
            id: r.id,
            agentName: r.agentName,
            label: r.label,
            amount: amount,
            originalAmount: r.originalAmount ?? r.amount,
          )
        else
          r,
    ];
  }

  @override
  Future<void> confirmReview(String reviewId) async {
    final item = _review.value.firstWhere((r) => r.id == reviewId);
    final agentId = _reviewAgent.remove(reviewId)!;
    _review.value = [
      for (final r in _review.value)
        if (r.id != reviewId) r,
    ];
    _agents.value = [
      for (final a in _agents.value)
        if (a.id == agentId)
          AgentSheet(
            id: a.id,
            name: a.name,
            attributes: a.attributes,
            health: a.health,
            sanity: a.sanity - item.amount,
          )
        else
          a,
    ];
    final was = item.originalAmount == null
        ? ''
        : ' (changed by the Handler from ${item.originalAmount})';
    _append(
      _gmLog,
      TextEntry('${item.agentName} loses ${item.amount} Sanity$was.'),
    );
    _append(
      _playerLog(agentId),
      TextEntry('${item.agentName} loses ${item.amount} Sanity.'),
    );
  }

  @override
  Future<void> addGmNote(String text) async =>
      _append(_gmLog, TextEntry('GM note: $text', gmNote: true));

  bool _meets(AgentSheet a, String attribute, BroadcastOp op, int value) {
    final score = a.attributes[attribute];
    if (score == null) return false;
    return switch (op) {
      BroadcastOp.lt => score < value,
      BroadcastOp.le => score <= value,
      BroadcastOp.eq => score == value,
      BroadcastOp.ne => score != value,
      BroadcastOp.ge => score >= value,
      BroadcastOp.gt => score > value,
    };
  }

  @override
  Future<List<BroadcastPreviewItem>> previewBroadcast(
    String attribute,
    BroadcastOp op,
    int value,
  ) async => [
    for (final a in _agents.value)
      BroadcastPreviewItem(
        agentName: a.name,
        qualifies: _meets(a, attribute, op, value),
        score: a.attributes[attribute],
      ),
  ];

  @override
  Future<String?> broadcast(
    String text,
    String attribute,
    BroadcastOp op,
    int value,
  ) async {
    if (text.trim().isEmpty) return 'A message is required.';
    final names = <String>[];
    for (final a in _agents.value) {
      if (!_meets(a, attribute, op, value)) continue;
      names.add(a.name);
      _append(_playerLog(a.id), TextEntry(text));
    }
    _append(
      _gmLog,
      TextEntry(
        'Broadcast to ${names.isEmpty ? 'no one' : names.join(', ')}: '
        '$text',
      ),
    );
    return null;
  }

  // Phone messages as (from, to, text); null is the Handler.
  final List<(String?, String?, String)> _phoneLog = [];
  final Signal<List<PhoneThreadData>> _gmPhone = signal(const []);
  final Map<String, Signal<List<PhoneThreadData>>> _playerPhones = {};

  @override
  ReadonlySignal<List<PhoneThreadData>> get gmPhone => _gmPhone;

  @override
  ReadonlySignal<List<PhoneThreadData>> playerPhone(String agentId) =>
      _playerPhones.putIfAbsent(agentId, () => signal(_threadsFor(agentId)));

  @override
  Future<void> sendPhone(
    String? fromAgentId,
    String threadId,
    String text,
  ) async {
    final to = threadId == 'gm' ? null : threadId.substring('alias:'.length);
    _phoneLog.add((fromAgentId, to, text));
    _refreshPhones();
  }

  void _refreshPhones() {
    _gmPhone.value = [
      for (final a in _agents.value)
        PhoneThreadData(
          id: 'alias:${a.id}',
          title: a.name,
          messages: [
            for (final (from, to, text) in _phoneLog)
              if ((from == null && to == a.id) || (from == a.id && to == null))
                PhoneMessageData(text: text, fromMe: from == null),
          ],
        ),
    ];
    for (final e in _playerPhones.entries) {
      e.value.value = _threadsFor(e.key);
    }
  }

  List<PhoneThreadData> _threadsFor(String me) {
    List<PhoneMessageData> between(String? other) => [
      for (final (from, to, text) in _phoneLog)
        if ((from == me && to == other) || (from == other && to == me))
          PhoneMessageData(text: text, fromMe: from == me),
    ];
    return [
      PhoneThreadData(id: 'gm', title: 'The Handler', messages: between(null)),
      for (final a in _agents.value)
        if (a.id != me)
          PhoneThreadData(
            id: 'alias:${a.id}',
            title: a.name,
            messages: between(a.id),
          ),
    ];
  }
}
