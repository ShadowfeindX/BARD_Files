import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';
import '../../data/services/operation_service.dart';
import '../shared/log_entry_tile.dart';

/// The public table panel; it can sit on a second display.
class TablePanel extends StatelessWidget {
  /// Creates the panel over [service].
  const TablePanel({super.key, required this.service});

  /// Source of the public log.
  final OperationService service;

  @override
  Widget build(BuildContext context) {
    return PerspectivePanel<LogEntry>(
      kind: PerspectiveKind.table,
      title: 'Table',
      items: service.tableLog,
      itemBuilder: (context, e) => LogEntryTile(entry: e),
      emptyText: 'Nothing shared yet.',
    );
  }
}
