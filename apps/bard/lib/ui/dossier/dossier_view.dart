import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';
import '../shared/log_entry_tile.dart';
import 'dossier_view_model.dart';

/// A player's dossier: own sheet, action request, own log and phone.
class DossierView extends StatefulWidget {
  /// Creates the dossier over [model].
  const DossierView({super.key, required this.model});

  /// State and commands.
  final DossierViewModel model;

  @override
  State<DossierView> createState() => _DossierViewState();
}

class _DossierViewState extends State<DossierView> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    widget.model.requestAction(_text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Column(
      children: [
        SignalBuilder(
          builder: (context) {
            final sheet = model.sheet.value;
            return Card(
              child: ListTile(
                title: Text(sheet.name),
                subtitle: Text(
                  [
                    for (final e in sheet.attributes.entries)
                      '${e.key} ${e.value}',
                  ].join('  '),
                ),
                trailing: Text(
                  'Health ${sheet.health}   Sanity ${sheet.sanity}',
                  key: ValueKey('vitals-${sheet.id}'),
                ),
              ),
            );
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('request-field-${model.agentId}'),
                    controller: _text,
                    decoration: const InputDecoration(
                      labelText: 'What do you do?',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                FilledButton(
                  key: ValueKey('request-send-${model.agentId}'),
                  onPressed: _send,
                  child: const Text('Request action'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PerspectivePanel<LogEntry>(
            kind: PerspectiveKind.player,
            title: 'Your log',
            items: model.log,
            itemBuilder: (context, e) => LogEntryTile(entry: e),
            emptyText: 'Nothing yet.',
          ),
        ),
        Expanded(
          child: Card(
            key: ValueKey('phone-${model.agentId}'),
            child: PhonePanel(
              threads: model.phone,
              onSend: model.sendPhone,
              notice: 'The Handler can read every message.',
            ),
          ),
        ),
      ],
    );
  }
}
