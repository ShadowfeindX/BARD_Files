import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../data/services/npc_notes_service.dart';
import 'npc_notes_view_model.dart';

/// The Handler's notes on one NPC at a time: free text, pinned details and
/// prepared messages. Handler-only; pass it to `ConsoleView.npcNotes`.
class NpcNotesPanel extends StatefulWidget {
  /// Creates the panel over [model].
  const NpcNotesPanel({super.key, required this.model});

  /// State and commands.
  final NpcNotesViewModel model;

  @override
  State<NpcNotesPanel> createState() => _NpcNotesPanelState();
}

class _NpcNotesPanelState extends State<NpcNotesPanel> {
  final _text = TextEditingController();
  final _pin = TextEditingController();
  final _label = TextEditingController();
  final _message = TextEditingController();
  late final void Function() _stop;

  @override
  void initState() {
    super.initState();
    // Fill the text box when another NPC's notes load.
    String? shown;
    _stop = effect(() {
      final n = widget.model.notes.value;
      final key = n?.npcId;
      if (key != shown) {
        shown = key;
        _text.text = n?.text ?? '';
      }
    });
  }

  @override
  void dispose() {
    _stop();
    _text.dispose();
    _pin.dispose();
    _label.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _addPin() async {
    final value = _pin.text.trim();
    if (value.isEmpty) return;
    if (await widget.model.pin(value) && _pin.text.trim() == value) {
      _pin.clear();
    }
  }

  Future<void> _addMessage() async {
    final text = _message.text;
    final label = _label.text.trim();
    if (text.trim().isEmpty) return;
    final kept = await widget.model.addPrepared(text, label: label);
    // Clear only what was sent, not anything typed while it was saving.
    if (kept && _message.text == text) {
      _message.clear();
      _label.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ShellWindow(
      title: 'NPC notes (Handler only)',
      child: SignalBuilder(
        builder: (context) {
          final notes = model.notes.value;
          final error = model.error.value;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  key: const ValueKey('npc-notes-picker'),
                  isExpanded: true,
                  hint: const Text('Choose an NPC'),
                  value: model.selected.value,
                  items: [
                    for (final n in model.npcs)
                      DropdownMenuItem(value: n.id, child: Text(n.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) model.select(id);
                  },
                ),
                if (error != null)
                  Text(
                    error,
                    key: const ValueKey('npc-notes-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (notes != null) ..._body(notes),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _body(NpcNotes notes) {
    final model = widget.model;
    return [
      const SizedBox(height: 8),
      Focus(
        onFocusChange: (focused) {
          if (!focused) model.saveText(_text.text);
        },
        child: TextField(
          key: const ValueKey('npc-notes-text'),
          controller: _text,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: const ValueKey('npc-notes-save'),
          onPressed: () => model.saveText(_text.text),
          child: const Text('Save notes'),
        ),
      ),
      const Text('Pinned'),
      for (var i = 0; i < notes.pinned.length; i++)
        ListTile(
          key: ValueKey('npc-pin-$i'),
          dense: true,
          leading: const Icon(Icons.push_pin_outlined),
          title: Text(notes.pinned[i]),
          trailing: IconButton(
            key: ValueKey('npc-unpin-$i'),
            tooltip: 'Unpin',
            icon: const Icon(Icons.close),
            onPressed: () => model.unpin(i),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('npc-pin-field'),
              controller: _pin,
              decoration: const InputDecoration(labelText: 'Pin a detail'),
              onSubmitted: (_) => _addPin(),
            ),
          ),
          IconButton(
            key: const ValueKey('npc-pin-add'),
            tooltip: 'Pin',
            icon: const Icon(Icons.push_pin),
            onPressed: _addPin,
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Prepared messages'),
      for (final m in notes.prepared)
        ListTile(
          key: ValueKey('npc-msg-${m.id}'),
          dense: true,
          title: Text(m.label.isEmpty ? m.text : m.label),
          subtitle: m.label.isEmpty ? null : Text(m.text),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (model.sendAs != null)
                IconButton(
                  key: ValueKey('npc-msg-send-${m.id}'),
                  tooltip: 'Send as this NPC',
                  icon: const Icon(Icons.send),
                  onPressed: () => model.send(m.id),
                ),
              IconButton(
                key: ValueKey('npc-msg-delete-${m.id}'),
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => model.removePrepared(m.id),
              ),
            ],
          ),
        ),
      TextField(
        key: const ValueKey('npc-msg-label'),
        controller: _label,
        decoration: const InputDecoration(labelText: 'Label (optional)'),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('npc-msg-field'),
              controller: _message,
              decoration: const InputDecoration(labelText: 'Prepared message'),
              onSubmitted: (_) => _addMessage(),
            ),
          ),
          IconButton(
            key: const ValueKey('npc-msg-add'),
            tooltip: 'Add message',
            icon: const Icon(Icons.add),
            onPressed: _addMessage,
          ),
        ],
      ),
    ];
  }
}
