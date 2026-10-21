import 'package:signals_flutter/signals_flutter.dart';

import '../../data/models.dart';
import '../../data/services/operation_service.dart';

/// State and commands for one player's dossier.
class DossierViewModel {
  /// Creates the view model for [agentId].
  DossierViewModel(this._service, this.agentId) {
    sheet = computed(
      () => _service.agents.value.firstWhere((a) => a.id == agentId),
    );
  }

  final OperationService _service;

  /// The agent this dossier belongs to.
  final String agentId;

  /// The agent's sheet, with vitals from the read model.
  late final ReadonlySignal<AgentSheet> sheet;

  /// What this player sees.
  ReadonlySignal<List<LogEntry>> get log => _service.playerLog(agentId);

  /// Sends an action request; blank text is ignored.
  void requestAction(String description) {
    final text = description.trim();
    if (text.isEmpty) return;
    _service.requestAction(agentId, text);
  }
}
