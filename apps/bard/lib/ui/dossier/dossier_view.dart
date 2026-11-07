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
        Expanded(
          flex: 3,
          child: ListView(
            key: ValueKey('dossier-top-${model.agentId}'),
            children: [
              _WhisperAlert(model: model),
              ShellWindow(
                title: 'Request',
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
                      const SizedBox(width: 8),
                      FilledButton(
                        key: ValueKey('request-send-${model.agentId}'),
                        onPressed: _send,
                        child: const Text('Request action'),
                      ),
                    ],
                  ),
                ),
              ),
              SignalBuilder(
                builder: (context) => _RecordCardOf(sheet: model.sheet.value),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: PerspectivePanel<LogEntry>(
            kind: PerspectiveKind.player,
            title: 'Your log',
            items: model.log,
            itemBuilder: (context, e) => LogEntryTile(entry: e),
            emptyText: 'Nothing yet.',
          ),
        ),
        Expanded(
          flex: 3,
          child: ShellWindow(
            key: ValueKey('phone-${model.agentId}'),
            title: 'Phone',
            expand: true,
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

/// The player's own record card: attributes, vitals and conditions.
///
/// The section labels are generic placeholders. The Operator-derived table
/// label of the design (DEC-24) is not used, and no other field is added
/// until D decides the record's content.
class _RecordCardOf extends StatelessWidget {
  const _RecordCardOf({required this.sheet});

  final AgentSheet sheet;

  @override
  Widget build(BuildContext context) {
    return RecordCard(
      title: sheet.name,
      sections: [
        RecordSection(
          label: 'Attributes',
          rows: [
            for (final e in sheet.attributes.entries)
              RecordRow(e.key, '${e.value}'),
          ],
        ),
        RecordSection(
          label: 'Vitals',
          rows: [
            RecordRow(
              'Health',
              '${sheet.health}',
              valueKey: ValueKey('health-${sheet.id}'),
            ),
            RecordRow(
              'Sanity',
              '${sheet.sanity}',
              valueKey: ValueKey('sanity-${sheet.id}'),
            ),
          ],
        ),
        RecordSection(
          label: 'Conditions',
          tags: [for (final c in sheet.conditions) c.name],
          emptyText: 'None.',
        ),
      ],
    );
  }
}

/// An alert for a stat-gated whisper, outside the phone (DEC-17).
class _WhisperAlert extends StatelessWidget {
  const _WhisperAlert({required this.model});

  final DossierViewModel model;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final text = model.whisper.value;
        if (text == null) return const SizedBox.shrink();
        final tokens = BardTokens.of(context);
        return ShellWindow(
          key: ValueKey('whisper-${model.agentId}'),
          title: 'Whisper',
          accent: tokens.supervisor,
          actions: [
            TextButton(
              key: ValueKey('whisper-dismiss-${model.agentId}'),
              onPressed: model.dismissWhisper,
              child: const Text('Dismiss'),
            ),
          ],
          child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
        );
      },
    );
  }
}
