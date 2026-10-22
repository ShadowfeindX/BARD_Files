import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';

/// Renders one [LogEntry]: narrated text, a private GM note, or a roll with
/// its dice breakdown.
class LogEntryTile extends StatelessWidget {
  /// Creates a tile for [entry].
  const LogEntryTile({super.key, required this.entry});

  /// The line to show.
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      RollEntry(:final data) => DiceBreakdownView(data: data),
      TextEntry(:final text, :final gmNote) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(
          text,
          style: gmNote ? const TextStyle(fontStyle: FontStyle.italic) : null,
        ),
      ),
    };
  }
}
