import 'package:flutter/material.dart';

import '../../app/composition.dart';
import '../../data/report_saver.dart';

/// The log-collection notice every tester accepts before hosting or
/// joining. PLACEHOLDER wording until R or D supplies the final text.
const String consentText =
    'PLACEHOLDER: This test session records a game log and a diagnostic log '
    'on this machine, and the host keeps the game log of the episode. Logs '
    'stay on the machines that wrote them; a report leaves a machine only '
    'when you send its folder by hand.';

/// Asks the tester to accept log collection. True only when they accept.
Future<bool> showConsentDialog(
  BuildContext context, {
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Log collection'),
      content: const SizedBox(width: 420, child: Text(consentText)),
      actions: [
        TextButton(
          key: const ValueKey('consent-decline'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          key: const ValueKey('consent-accept'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Accept and $action'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// What a player typed to join a host.
class JoinRequest {
  /// Creates the request.
  const JoinRequest({
    required this.host,
    required this.port,
    required this.joinCode,
    required this.aliasId,
  });

  /// The host's address.
  final String host;

  /// The host's port.
  final int port;

  /// The code the host checks.
  final String joinCode;

  /// The agent code the Handler gave this player.
  final String aliasId;
}

/// Reads "host:port", trimmed. Null when it is not that shape.
({String host, int port})? parseHostAndPort(String text) {
  final value = text.trim();
  final colon = value.lastIndexOf(':');
  if (colon <= 0) return null;
  final host = value.substring(0, colon);
  final port = int.tryParse(value.substring(colon + 1));
  if (host.contains(RegExp(r'[\s/?#@]'))) return null;
  if (port == null || port < 1 || port > 65535) return null;
  return (host: host, port: port);
}

/// Asks for the host address, the join code and the agent code. Null when
/// the player cancels.
Future<JoinRequest?> showJoinDialog(BuildContext context) =>
    showDialog<JoinRequest>(
      context: context,
      builder: (context) => const _JoinDialog(),
    );

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _address = TextEditingController();
  final _code = TextEditingController();
  final _alias = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    _alias.dispose();
    super.dispose();
  }

  void _submit() {
    final at = parseHostAndPort(_address.text);
    final code = _code.text.trim().toUpperCase();
    final alias = _alias.text.trim();
    final problem = at == null
        ? 'Type the host address as shown on the Handler\'s screen, '
              'for example 192.168.1.20:4040.'
        : code.isEmpty
        ? 'Type the join code.'
        : alias.isEmpty
        ? 'Type your agent code.'
        : null;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(
      JoinRequest(
        host: at!.host,
        port: at.port,
        joinCode: code,
        aliasId: alias,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join on LAN'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('join-address'),
            controller: _address,
            decoration: const InputDecoration(labelText: 'Host address'),
          ),
          TextField(
            key: const ValueKey('join-code'),
            controller: _code,
            decoration: const InputDecoration(labelText: 'Join code'),
          ),
          TextField(
            key: const ValueKey('join-alias'),
            controller: _alias,
            decoration: const InputDecoration(labelText: 'Agent code'),
            onSubmitted: (_) => _submit(),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _problem!,
                key: const ValueKey('join-problem'),
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
        key: const ValueKey('join-submit'),
        onPressed: _submit,
        child: const Text('Join'),
      ),
    ],
  );
}

/// Saves a report and says where it went. On the Handler's machine the
/// dialog offers the "include notes" tick (off by default).
Future<void> saveReport(BuildContext context, ReportSaver reports) async {
  final messenger = ScaffoldMessenger.of(context);
  final includeNotes = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _ReportDialog(canIncludeNotes: reports.canIncludeNotes),
  );
  if (includeNotes == null) return;
  try {
    final folder = await reports.save(includeNotes: includeNotes);
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('report-saved'),
        content: Text('Report saved to $folder. Send that folder by hand.'),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not save the report: $e')),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.canIncludeNotes});

  final bool canIncludeNotes;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  bool _notes = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save a report'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saves the logs of this session into a folder on this machine, '
            'so a problem can be reproduced.',
          ),
          if (widget.canIncludeNotes)
            CheckboxListTile(
              key: const ValueKey('report-include-notes'),
              contentPadding: EdgeInsets.zero,
              value: _notes,
              onChanged: (v) => setState(() => _notes = v ?? false),
              title: const Text('Include notes'),
              subtitle: const Text('Adds your NPC notes to the report.'),
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
        key: const ValueKey('report-save'),
        onPressed: () => Navigator.of(context).pop(_notes),
        child: const Text('Save'),
      ),
    ],
  );
}

/// One line for the Handler: where players connect, and the agent codes.
String hostingLine(HostInfo info, Map<String, String> agentCodes) {
  final addresses = info.addresses.isEmpty
      ? 'this machine\'s address'
      : info.addresses.join(' or ');
  final codes = agentCodes.entries
      .map((e) => '${e.value}: ${e.key}')
      .join(', ');
  return 'Hosting on $addresses, port ${info.port}. '
      'Join code ${info.joinCode}.'
      '${codes.isEmpty ? '' : ' Agent codes: $codes.'}';
}
