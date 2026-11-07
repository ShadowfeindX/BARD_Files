import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../app/composition.dart';
import '../../data/services/episode_service.dart';
import '../console/console_view.dart';
import '../console/console_view_model.dart';
import '../dossier/dossier_view.dart';
import '../dossier/dossier_view_model.dart';
import '../table/table_panel.dart';
import 'lan_dialogs.dart';

/// What the home screen can ask the app to do: each replaces the running
/// composition.
class PlayActions {
  /// Creates the actions.
  const PlayActions({
    required this.newEpisode,
    this.host,
    this.join,
    this.leave,
  });

  /// Replaces the episode with a fresh, empty one (hosted again when this
  /// machine hosts).
  final VoidCallback newEpisode;

  /// Hosts over the LAN, or null when this machine cannot (no local data).
  final VoidCallback? host;

  /// Joins a LAN host, or null when this machine cannot.
  final void Function(JoinRequest request)? join;

  /// Stops hosting or leaves the host, back to one-device play.
  final VoidCallback? leave;
}

/// The main screen. One device and hosting show the GM console, a player
/// dossier and the table panel side by side (04 §Play modes); a host also
/// shows where players connect. A joined machine shows its own dossier and
/// the state of the link.
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({
    super.key,
    required this.service,
    required this.console,
    required this.appearance,
    required this.actions,
    this.composition,
  });

  /// The running episode.
  final EpisodeService service;

  /// GM console state.
  final ConsoleViewModel console;

  /// The player's theme and variant setting.
  final ThemeController appearance;

  /// Mode changes the app performs.
  final PlayActions actions;

  /// The running composition, for the mode, the host's details and reports.
  /// Null shows one-device play with no reports.
  final Composition? composition;

  PlayMode get _mode => composition?.mode ?? PlayMode.oneDevice;

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
    if (ok ?? false) widget.actions.newEpisode();
  }

  Future<void> _host() async {
    final host = widget.actions.host;
    if (host == null) return;
    if (await showConsentDialog(context, action: 'host')) host();
  }

  Future<void> _join() async {
    final join = widget.actions.join;
    if (join == null) return;
    final request = await showJoinDialog(context);
    if (request == null || !mounted) return;
    if (await showConsentDialog(context, action: 'join')) join(request);
  }

  Future<void> _leave() async {
    final leave = widget.actions.leave;
    if (leave == null) return;
    final hosting = widget._mode == PlayMode.host;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hosting ? 'Stop hosting' : 'Leave the episode'),
        content: Text(
          hosting
              ? 'Players lose the link. The episode stays saved on this '
                    'machine and resumes the next time you host.'
              : 'You leave the host and return to one-device play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('leave-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(hosting ? 'Stop hosting' : 'Leave'),
          ),
        ],
      ),
    );
    if (ok ?? false) leave();
  }

  List<Widget> _modeActions() {
    final reports = widget.composition?.reports;
    return [
      if (widget._mode == PlayMode.oneDevice && widget.actions.host != null)
        TextButton.icon(
          key: const ValueKey('host-lan'),
          onPressed: _host,
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('Host on LAN'),
        ),
      if (widget._mode == PlayMode.oneDevice && widget.actions.join != null)
        TextButton.icon(
          key: const ValueKey('join-lan'),
          onPressed: _join,
          icon: const Icon(Icons.login),
          label: const Text('Join on LAN'),
        ),
      if (widget._mode != PlayMode.oneDevice && widget.actions.leave != null)
        TextButton.icon(
          key: const ValueKey('leave'),
          onPressed: _leave,
          icon: const Icon(Icons.logout),
          label: Text(widget._mode == PlayMode.host ? 'Stop hosting' : 'Leave'),
        ),
      if (reports != null)
        TextButton.icon(
          key: const ValueKey('save-report'),
          onPressed: () => saveReport(context, reports),
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Save a report'),
        ),
    ];
  }

  Widget _joined(BuildContext context, String? selected) {
    final status = widget.composition?.status?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(status, key: const ValueKey('join-status')),
          ),
        Expanded(
          child: selected == null
              ? const Center(child: Text('Waiting for your agent…'))
              : DossierView(
                  key: ValueKey('dossier-$selected'),
                  model: _dossiers.putIfAbsent(
                    selected,
                    () => DossierViewModel(widget.service, selected),
                  ),
                ),
        ),
      ],
    );
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
              ..._modeActions(),
              if (widget._mode != PlayMode.join)
                TextButton.icon(
                  key: const ValueKey('new-episode'),
                  onPressed: _confirmNew,
                  icon: const Icon(Icons.add),
                  label: const Text('New episode'),
                ),
              if (selected != null && widget._mode != PlayMode.join)
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
            child: widget._mode == PlayMode.join
                ? _joined(context, selected)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.composition?.hosting case final hosting?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            hostingLine(hosting, {
                              for (final a in agents) a.id: a.name,
                            }),
                            key: const ValueKey('hosting-line'),
                          ),
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ConsoleView(model: widget.console),
                            ),
                            Expanded(
                              flex: 3,
                              child: selected == null
                                  ? const Center(
                                      child: Text(
                                        'Add an agent to start playing.',
                                      ),
                                    )
                                  : DossierView(
                                      key: ValueKey('dossier-$selected'),
                                      model: _dossiers.putIfAbsent(
                                        selected,
                                        () => DossierViewModel(
                                          widget.service,
                                          selected,
                                        ),
                                      ),
                                    ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TablePanel(service: widget.service),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
