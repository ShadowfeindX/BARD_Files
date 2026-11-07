import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/services/episode_service.dart';
import '../console/console_view.dart';
import '../console/console_view_model.dart';
import '../dossier/dossier_view.dart';
import '../dossier/dossier_view_model.dart';
import '../table/table_panel.dart';

/// "In person, one device" layout: GM console, a player dossier and the table
/// panel side by side (04 §Play modes).
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({
    super.key,
    required this.service,
    required this.console,
    required this.appearance,
    required this.onNewEpisode,
  });

  /// The running episode.
  final EpisodeService service;

  /// GM console state.
  final ConsoleViewModel console;

  /// The player's theme and variant setting.
  final ThemeController appearance;

  /// Replaces the episode with a fresh, empty one.
  final VoidCallback onNewEpisode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _agentId;

  /// One model per agent, so a dismissed whisper stays dismissed across
  /// the rebuilds every engine refresh causes.
  final Map<String, DossierViewModel> _dossiers = {};

  Future<void> _confirmNew() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New episode'),
        content: const Text(
          'This closes the current episode and starts an empty one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('new-episode-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start new'),
          ),
        ],
      ),
    );
    if (ok ?? false) widget.onNewEpisode();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final agents = widget.service.agents.value;
        final selected = agents.any((a) => a.id == _agentId)
            ? _agentId
            : agents.firstOrNull?.id;
        return Scaffold(
          appBar: AppBar(
            title: const Text('B.A.R.D. Files'),
            actions: [
              TextButton.icon(
                key: const ValueKey('appearance'),
                onPressed: () =>
                    showAppearanceDialog(context, widget.appearance),
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Appearance'),
              ),
              TextButton.icon(
                key: const ValueKey('new-episode'),
                onPressed: _confirmNew,
                icon: const Icon(Icons.add),
                label: const Text('New episode'),
              ),
              if (selected != null)
                DropdownButton<String>(
                  key: const ValueKey('player-picker'),
                  value: selected,
                  items: [
                    for (final a in agents)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _agentId = v),
                ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(flex: 3, child: ConsoleView(model: widget.console)),
                Expanded(
                  flex: 3,
                  child: selected == null
                      ? const Center(
                          child: Text('Add an agent to start playing.'),
                        )
                      : DossierView(
                          key: ValueKey('dossier-$selected'),
                          model: _dossiers.putIfAbsent(
                            selected,
                            () => DossierViewModel(widget.service, selected),
                          ),
                        ),
                ),
                Expanded(flex: 2, child: TablePanel(service: widget.service)),
              ],
            ),
          ),
        );
      },
    );
  }
}
