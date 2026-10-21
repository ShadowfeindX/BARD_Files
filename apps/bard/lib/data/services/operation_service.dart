import 'package:signals_flutter/signals_flutter.dart';

import '../models.dart';

/// What the UI needs from a running operation.
///
/// A session-backed implementation replaces the in-memory fake later;
/// view models only see this interface (07 §Layering).
/// Perspective signals hold already-filtered lines for one viewer.
abstract interface class OperationService {
  /// Releases the host. The service is unusable afterwards.
  Future<void> dispose();

  /// All agents with current vitals.
  ReadonlySignal<List<AgentSheet>> get agents;

  /// Action requests in arrival order.
  ReadonlySignal<List<ActionRequestItem>> get requests;

  /// Consequences held for GM review.
  ReadonlySignal<List<ReviewItem>> get reviewTray;

  /// The pack's agent creation limits.
  CreationLimits get creationLimits;

  /// GM adds an agent with these attribute scores. Returns the engine's
  /// refusal message, or null when the agent was created.
  Future<String?> addAgent(String name, Map<String, int> scores);

  /// The last refusal or problem message, or null.
  ReadonlySignal<String?> get lastError;

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
  Future<void> requestAction(String agentId, String description);

  /// GM requires and resolves a check for a request.
  Future<void> resolveRequest(
    String requestId,
    String skillId,
    String difficultyKey,
  );

  /// GM declines a request.
  Future<void> declineRequest(String requestId);

  /// GM proposes a Sanity loss; it waits in the review tray.
  Future<void> proposeSanityLoss(String agentId, int amount);

  /// GM edits a held amount.
  Future<void> editReview(String reviewId, int amount);

  /// GM confirms a held consequence; the player then sees it.
  Future<void> confirmReview(String reviewId);

  /// GM adds a private note.
  Future<void> addGmNote(String text);
}
