import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';
import '../shared/log_entry_tile.dart';

/// The public table panel; it can sit on a second display.
class TablePanel extends StatelessWidget {
  /// Creates the panel over the public [log].
  const TablePanel({super.key, required this.log});

  /// The public log.
  final ReadonlySignal<List<LogEntry>> log;

  @override
  Widget build(BuildContext context) {
    return PerspectivePanel<LogEntry>(
      kind: PerspectiveKind.table,
      title: 'Table',
      items: log,
      itemBuilder: (context, e) => LogEntryTile(entry: e),
      emptyText: 'Nothing shared yet.',
    );
  }
}
