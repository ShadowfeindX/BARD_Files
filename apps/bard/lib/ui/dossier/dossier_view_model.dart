import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';
import '../../data/services/episode_service.dart';

/// State and commands for one player's dossier.
class DossierViewModel {
  /// Creates the view model for [agentId].
  DossierViewModel(this._service, this.agentId) {
    sheet = computed(
      () => _service.agents.value.firstWhere((a) => a.id == agentId),
    );
    whisper = computed(() {
      final received = _receivedWhispers();
      return received.length > _dismissed.value ? received.last : null;
    });
  }

  final Signal<int> _dismissed = signal(0);

  List<String> _receivedWhispers() => [
    for (final e in log.value)
      if (e is TextEntry && e.whisper) e.text,
  ];

  /// The newest whisper this player has not dismissed, or null. The dossier
  /// shows it as an alert outside the phone (DEC-17); the log line stays.
  late final ReadonlySignal<String?> whisper;

  /// Hides the alert for the whispers received so far.
  void dismissWhisper() => _dismissed.value = _receivedWhispers().length;

  final EpisodeService _service;

  /// The agent this dossier belongs to.
  final String agentId;

  /// The agent's sheet, with vitals from the read model.
  late final ReadonlySignal<AgentSheet> sheet;

  /// What this player sees.
  ReadonlySignal<List<LogEntry>> get log => _service.playerLog(agentId);

  /// Sends an action request; blank text is ignored.
  Future<void> requestAction(String description) async {
    final text = description.trim();
    if (text.isEmpty) return;
    await _service.requestAction(agentId, text);
  }

  /// This player's phone threads.
  ReadonlySignal<List<PhoneThreadData>> get phone =>
      _service.playerPhone(agentId);

  /// Sends a phone message from this player on [threadId].
  Future<void> sendPhone(String threadId, String text) =>
      _service.sendPhone(agentId, threadId, text);
}
