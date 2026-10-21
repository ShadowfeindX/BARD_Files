import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../data/services/operation_service.dart';
import '../console/console_view.dart';
import '../console/console_view_model.dart';
import '../dossier/dossier_view.dart';
import '../dossier/dossier_view_model.dart';
import '../table/table_panel.dart';

/// "In person, one device" layout: GM console, a player dossier and the table
/// panel side by side (04 §Play modes).
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({super.key, required this.service, required this.console});

  /// The running operation.
  final OperationService service;

  /// GM console state.
  final ConsoleViewModel console;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _agentId = widget.service.agents.value.first.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B.A.R.D. Files'),
        actions: [
          SignalBuilder(
            builder: (context) => DropdownButton<String>(
              key: const ValueKey('player-picker'),
              value: _agentId,
              items: [
                for (final a in widget.service.agents.value)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _agentId = v ?? _agentId),
            ),
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
              child: DossierView(
                key: ValueKey('dossier-$_agentId'),
                model: DossierViewModel(widget.service, _agentId),
              ),
            ),
            Expanded(flex: 2, child: TablePanel(service: widget.service)),
          ],
        ),
      ),
    );
  }
}
