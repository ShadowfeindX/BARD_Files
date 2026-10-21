import 'package:signals_flutter/signals_flutter.dart';

import '../models.dart';

/// What the UI needs from a running operation.
///
/// A session-backed implementation replaces the in-memory fake later;
/// view models only see this interface (07 §Layering).
/// Perspective signals hold already-filtered lines for one viewer.
abstract interface class OperationService {
  /// All agents with current vitals.
  ReadonlySignal<List<AgentSheet>> get agents;

  /// Action requests in arrival order.
  ReadonlySignal<List<ActionRequestItem>> get requests;

  /// Consequences held for GM review.
  ReadonlySignal<List<ReviewItem>> get reviewTray;

  /// Skills the GM can require checks for.
  List<SkillOption> get skills;

  /// DC categories the GM can pick.
  List<DifficultyOption> get difficulties;

  /// Log as the GM sees it.
  ReadonlySignal<List<LogEntry>> get gmLog;

  /// Public log shown on the table panel.
  ReadonlySignal<List<LogEntry>> get tableLog;

  /// Log as one player sees it.
  ReadonlySignal<List<LogEntry>> playerLog(String agentId);

  /// Player asks to act.
  void requestAction(String agentId, String description);

  /// GM requires and resolves a check for a request.
  void resolveRequest(String requestId, String skillId, String difficultyKey);

  /// GM declines a request.
  void declineRequest(String requestId);

  /// GM proposes a Sanity loss; it waits in the review tray.
  void proposeSanityLoss(String agentId, int amount);

  /// GM edits a held amount.
  void editReview(String reviewId, int amount);

  /// GM confirms a held consequence; the player then sees it.
  void confirmReview(String reviewId);

  /// GM adds a private note.
  void addGmNote(String text);
}
