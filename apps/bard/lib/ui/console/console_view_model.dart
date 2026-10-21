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

  /// The GM's log.
  ReadonlySignal<List<LogEntry>> get log => _service.gmLog;

  /// Resolves the selected request with the chosen skill and DC.
  void resolveSelected() {
    final id = selectedRequest.value;
    if (id == null) return;
    _service.resolveRequest(id, skillId.value, difficultyKey.value);
    selectedRequest.value = null;
  }

  /// Declines the selected request.
  void declineSelected() {
    final id = selectedRequest.value;
    if (id == null) return;
    _service.declineRequest(id);
    selectedRequest.value = null;
  }

  /// Holds a Sanity loss of [amount] for [agentId] in the review tray.
  void proposeSanityLoss(String agentId, int amount) =>
      _service.proposeSanityLoss(agentId, amount);

  /// Edits a held amount.
  void editReview(String id, int amount) => _service.editReview(id, amount);

  /// Confirms a held consequence.
  void confirmReview(String id) => _service.confirmReview(id);

  /// Adds a private GM note.
  void addNote(String text) => _service.addGmNote(text);
}
