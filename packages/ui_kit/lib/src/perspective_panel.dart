import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Whose view of the operation a panel shows (07 §Perspective panels).
enum PerspectiveKind {
  /// The GM's full view.
  gm,

  /// One player's alias view.
  player,

  /// The shared public view.
  table,
}

/// Frame for one perspective: a header naming the viewer and a list bound to
/// that perspective's stream. It fills its parent, so place it in a bounded
/// height (`Expanded`, `SizedBox`).
///
/// The panel knows nothing about the session. The app feeds it a signal of
/// items already filtered for this perspective and a builder for each item.
class PerspectivePanel<T> extends StatelessWidget {
  /// Creates a panel for [kind] titled [title] that renders [items].
  const PerspectivePanel({
    super.key,
    required this.kind,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.emptyText = 'Nothing yet.',
    this.actions = const [],
  });

  /// Which perspective this panel shows.
  final PerspectiveKind kind;

  /// Heading, for example the alias name.
  final String title;

  /// Items for this perspective, newest last. Rebuilds when the signal changes.
  final ReadonlySignal<List<T>> items;

  /// Builds the widget for one item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown when [items] is empty.
  final String emptyText;

  /// Optional header controls (buttons, menus).
  final List<Widget> actions;

  /// Short label for a [PerspectiveKind].
  static String kindLabel(PerspectiveKind kind) => switch (kind) {
    PerspectiveKind.gm => 'GM',
    PerspectiveKind.player => 'Player',
    PerspectiveKind.table => 'Table',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Chip(label: Text(kindLabel(kind))),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: text.titleMedium)),
                ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                final list = items.value;
                if (list.isEmpty) {
                  return Center(child: Text(emptyText));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, i) => itemBuilder(context, list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
