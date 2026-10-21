import 'package:signals_flutter/signals_flutter.dart';

import '../../data/models.dart';
import '../../data/services/operation_service.dart';

/// State and commands for the GM console. It forwards intents to the service
/// and never computes an outcome (07 §The app shell never affects outcomes).
class ConsoleViewModel {
  /// Creates the view model over [_service].
  ConsoleViewModel(this._service) {
    skillId = signal(_service.skills.first.id);
    difficultyKey = signal(_service.difficulties.first.key);
  }

  final OperationService _service;

  /// The request the GM is working on, or null.
  final Signal<String?> selectedRequest = signal(null);

  /// Chosen skill for the check.
  late final Signal<String> skillId;

  /// Chosen DC category for the check.
  late final Signal<String> difficultyKey;

  /// Skills offered.
  List<SkillOption> get skills => _service.skills;

  /// DC categories offered.
  List<DifficultyOption> get difficulties => _service.difficulties;

  /// Agents, for the Sanity control.
  ReadonlySignal<List<AgentSheet>> get agents => _service.agents;

  /// Requests, newest last.
  ReadonlySignal<List<ActionRequestItem>> get requests => _service.requests;

  /// Consequences held for review.
  ReadonlySignal<List<ReviewItem>> get reviewTray => _service.reviewTray;

  /// The last refusal or problem, or null.
  ReadonlySignal<String?> get lastError => _service.lastError;

  /// The GM's log.
  ReadonlySignal<List<LogEntry>> get log => _service.gmLog;

  /// The pack's agent creation limits.
  CreationLimits get creationLimits => _service.creationLimits;

  /// Adds an agent; returns the engine's refusal message, or null on success.
  Future<String?> addAgent(String name, Map<String, int> scores) =>
      _service.addAgent(name, scores);

  /// Resolves the selected request with the chosen skill and DC.
  Future<void> resolveSelected() async {
    final id = selectedRequest.value;
    if (id == null) return;
    selectedRequest.value = null;
    await _service.resolveRequest(id, skillId.value, difficultyKey.value);
  }

  /// Declines the selected request.
  Future<void> declineSelected() async {
    final id = selectedRequest.value;
    if (id == null) return;
    selectedRequest.value = null;
    await _service.declineRequest(id);
  }

  /// Holds a Sanity loss of [amount] for [agentId] in the review tray.
  Future<void> proposeSanityLoss(String agentId, int amount) =>
      _service.proposeSanityLoss(agentId, amount);

  /// Edits a held amount.
  Future<void> editReview(String id, int amount) =>
      _service.editReview(id, amount);

  /// Raises or lowers a held amount by [delta], never below zero.
  Future<void> adjustReview(String id, int delta) async {
    final item = reviewTray.value.firstWhere((r) => r.id == id);
    final next = item.amount + delta;
    if (next >= 0) await _service.editReview(id, next);
  }

  /// Confirms a held consequence.
  Future<void> confirmReview(String id) => _service.confirmReview(id);

  /// Adds a private GM note.
  Future<void> addNote(String text) => _service.addGmNote(text);
}
