import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/models.dart';
import '../shared/log_entry_tile.dart';
import 'console_view_model.dart';

/// GM console: request queue, check controls, review tray and the GM log.
class ConsoleView extends StatelessWidget {
  /// Creates the console over [model].
  const ConsoleView({super.key, required this.model});

  /// State and commands.
  final ConsoleViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: PerspectivePanel<LogEntry>(
            kind: PerspectiveKind.gm,
            title: 'Handler log',
            items: model.log,
            itemBuilder: (context, e) => LogEntryTile(entry: e),
            emptyText: 'No activity yet.',
          ),
        ),
        Expanded(
          flex: 2,
          child: ListView(
            children: [
              _ErrorBanner(model: model),
              _RequestQueue(model: model),
              _CheckControls(model: model),
              _ReviewTray(model: model),
              _SanityControl(model: model),
              _NoteField(model: model),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestQueue extends StatelessWidget {
  const _RequestQueue({required this.model});

  final ConsoleViewModel model;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final pending = [
          for (final r in model.requests.value)
            if (r.status == RequestStatus.pending) r,
        ];
        final selected = model.selectedRequest.value;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text('Requests')),
              if (pending.isEmpty)
                const ListTile(title: Text('No pending requests.')),
              for (final r in pending)
                ListTile(
                  key: ValueKey('request-${r.id}'),
                  selected: r.id == selected,
                  title: Text(r.description),
                  subtitle: Text(r.agentName),
                  onTap: () => model.selectedRequest.value = r.id,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckControls extends StatelessWidget {
  const _CheckControls({required this.model});

  final ConsoleViewModel model;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final enabled = model.selectedRequest.value != null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    key: const ValueKey('skill-picker'),
                    value: model.skillId.value,
                    items: [
                      for (final s in model.skills)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => model.skillId.value = v!,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    key: const ValueKey('difficulty-picker'),
                    value: model.difficultyKey.value,
                    items: [
                      for (final d in model.difficulties)
                        DropdownMenuItem(
                          value: d.key,
                          child: Text('${d.name} (DC ${d.dc})'),
                        ),
                    ],
                    onChanged: (v) => model.difficultyKey.value = v!,
                  ),
                ),
                FilledButton(
                  key: const ValueKey('resolve'),
                  onPressed: enabled ? model.resolveSelected : null,
                  child: const Text('Require and resolve'),
                ),
                OutlinedButton(
                  key: const ValueKey('decline'),
                  onPressed: enabled ? model.declineSelected : null,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewTray extends StatelessWidget {
  const _ReviewTray({required this.model});

  final ConsoleViewModel model;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final items = model.reviewTray.value;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                title: Text('Review tray'),
                subtitle: Text(
                  'Held until you confirm. Players cannot see it.',
                ),
              ),
              if (items.isEmpty) const ListTile(title: Text('Nothing held.')),
              for (final item in items)
                ListTile(
                  key: ValueKey('review-${item.id}'),
                  title: Text(
                    '${item.agentName}: ${item.label} ${item.amount}',
                  ),
                  subtitle: item.originalAmount == null
                      ? null
                      : Text('Proposed ${item.originalAmount}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('review-dec-${item.id}'),
                        tooltip: 'Lower by 1',
                        icon: const Icon(Icons.remove),
                        onPressed: item.amount > 0
                            ? () => model.adjustReview(item.id, -1)
                            : null,
                      ),
                      IconButton(
                        key: ValueKey('review-inc-${item.id}'),
                        tooltip: 'Raise by 1',
                        icon: const Icon(Icons.add),
                        onPressed: () => model.adjustReview(item.id, 1),
                      ),
                      FilledButton(
                        key: ValueKey('review-confirm-${item.id}'),
                        onPressed: () => model.confirmReview(item.id),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SanityControl extends StatefulWidget {
  const _SanityControl({required this.model});

  final ConsoleViewModel model;

  @override
  State<_SanityControl> createState() => _SanityControlState();
}

class _SanityControlState extends State<_SanityControl> {
  final TextEditingController _amount = TextEditingController(text: '2');
  String? _agent;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return SignalBuilder(
      builder: (context) {
        final agents = model.agents.value;
        final agent = _agent ?? agents.first.id;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Sanity loss'),
                DropdownButton<String>(
                  key: const ValueKey('sanity-agent'),
                  value: agent,
                  items: [
                    for (final a in agents)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _agent = v),
                ),
                SizedBox(
                  width: 64,
                  child: TextField(
                    key: const ValueKey('sanity-amount'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                  ),
                ),
                FilledButton(
                  key: const ValueKey('sanity-hold'),
                  onPressed: () {
                    final amount = int.tryParse(_amount.text);
                    if (amount != null && amount >= 0) {
                      model.proposeSanityLoss(agent, amount);
                    }
                  },
                  child: const Text('Hold for review'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({required this.model});

  final ConsoleViewModel model;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    widget.model.addNote(_text.text.trim());
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('note-field'),
                controller: _text,
                decoration: const InputDecoration(labelText: 'Private GM note'),
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              key: const ValueKey('note-add'),
              tooltip: 'Add note',
              icon: const Icon(Icons.send),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.model});

  final ConsoleViewModel model;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final error = model.lastError.value;
        if (error == null) return const SizedBox.shrink();
        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            key: const ValueKey('error-banner'),
            leading: const Icon(Icons.error_outline),
            title: Text(error),
          ),
        );
      },
    );
  }
}
