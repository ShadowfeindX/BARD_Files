import 'package:flutter/material.dart';

import 'console_view_model.dart';

/// Lets the GM enter a name and attribute scores for a new agent. The pack's
/// creation limits are shown; the engine enforces them and its refusal text
/// is shown here.
class AddAgentDialog extends StatefulWidget {
  /// Creates the dialog over [model].
  const AddAgentDialog({super.key, required this.model});

  /// Console state and commands.
  final ConsoleViewModel model;

  @override
  State<AddAgentDialog> createState() => _AddAgentDialogState();
}

class _AddAgentDialogState extends State<AddAgentDialog> {
  final TextEditingController _name = TextEditingController();
  late final Map<String, TextEditingController> _scores = {
    for (final a in widget.model.creationLimits.attributes)
      a.key: TextEditingController(text: '${widget.model.creationLimits.min}'),
  };
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _scores.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    final scores = <String, int>{};
    for (final e in _scores.entries) {
      final value = int.tryParse(e.value.text.trim());
      if (value == null) {
        setState(() => _error = 'Scores must be whole numbers (${e.key}).');
        return;
      }
      scores[e.key] = value;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.model.addAgent(_name.text.trim(), scores);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final limits = widget.model.creationLimits;
    return AlertDialog(
      title: const Text('Add agent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${limits.points} points; each attribute '
              '${limits.min} to ${limits.max}.',
            ),
            TextField(
              key: const ValueKey('agent-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            for (final a in limits.attributes)
              TextField(
                key: ValueKey('score-${a.key}'),
                controller: _scores[a.key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: a.name),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const ValueKey('add-agent-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('agent-create'),
          onPressed: _busy ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
