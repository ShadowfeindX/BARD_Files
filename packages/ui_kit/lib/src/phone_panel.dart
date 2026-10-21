import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// One message bubble in a phone thread. Plain data: the app maps the
/// engine's phone events into it.
class PhoneMessageData {
  /// Creates a message.
  const PhoneMessageData({required this.text, required this.fromMe});

  /// The message text.
  final String text;

  /// Whether the viewer sent it (shown on the right).
  final bool fromMe;
}

/// A conversation with one counterpart.
class PhoneThreadData {
  /// Creates a thread.
  const PhoneThreadData({
    required this.id,
    required this.title,
    required this.messages,
  });

  /// Stable id the app maps back to the counterpart when sending.
  final String id;

  /// Who the thread is with ("the Handler", "Hall", ...).
  final String title;

  /// The messages, oldest first.
  final List<PhoneMessageData> messages;
}

/// Mirrors the engine's `invisiblePhoneChars` (ui_kit cannot import the
/// engine): text made only of these and whitespace is refused, so Send stays
/// off for it.
final _invisible = RegExp(
  '[\u00AD\u115F\u1160\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064'
  '\u3164\uFE00-\uFE0F\uFEFF\uFFA0]',
);

/// The in-game phone: a thread list, the open thread and a compose box.
///
/// It shows what it is given and sends nothing itself: [onSend] reports the
/// thread id and text, and the app turns that into a `SendPhoneMessage`
/// command. The engine decides whether the message is accepted. Placeholder
/// look (see `docs/ui-kit.md`); the hook into the player and GM consoles is
/// row 8's.
class PhonePanel extends StatefulWidget {
  /// Creates the panel.
  const PhonePanel({
    super.key,
    required this.threads,
    required this.onSend,
    this.maxLength = 2000,
    this.sendDisabledReason,
    this.notice,
    this.emptyText = 'No messages yet.',
  });

  /// The threads for this viewer, already filtered for their perspective.
  final ReadonlySignal<List<PhoneThreadData>> threads;

  /// Called with the open thread's id and the text to send.
  final void Function(String threadId, String text) onSend;

  /// Longest message in UTF-16 code units: the engine's cap, which equals the
  /// relay rules' cap (2,000).
  final int maxLength;

  /// When not null the compose box is replaced by this text (for example
  /// anonymous accounts, which may not message).
  final String? sendDisabledReason;

  /// Optional line above the compose box, for example telling a player that
  /// the Handler can read every message.
  final String? notice;

  /// Shown when there are no threads.
  final String emptyText;

  @override
  State<PhonePanel> createState() => _PhonePanelState();
}

class _PhonePanelState extends State<PhonePanel> {
  final _controller = TextEditingController();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Dart's String.length counts UTF-16 code units, the unit the cap uses.
  int get _length => _controller.text.length;

  /// The thread that is open: the selected one while it still exists, else the
  /// first. Read fresh each time so a thread that disappears can never be the
  /// recipient of a send.
  PhoneThreadData? get _open {
    final threads = widget.threads.peek();
    return threads.where((t) => t.id == _selected).firstOrNull ??
        threads.firstOrNull;
  }

  bool get _canSend =>
      _open != null &&
      _controller.text.replaceAll(_invisible, '').trim().isNotEmpty &&
      _length <= widget.maxLength;

  void _send() {
    final open = _open;
    if (open == null || !_canSend) return;
    widget.onSend(open.id, _controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final threads = widget.threads.value;
        if (threads.isEmpty) return Center(child: Text(widget.emptyText));
        final open =
            threads.where((t) => t.id == _selected).firstOrNull ??
            threads.first;
        return Row(
          children: [
            SizedBox(width: 160, child: _threadList(threads, open)),
            const VerticalDivider(width: 1),
            Expanded(child: _conversation(context, open)),
          ],
        );
      },
    );
  }

  Widget _threadList(List<PhoneThreadData> threads, PhoneThreadData open) {
    return ListView(
      children: [
        for (final thread in threads)
          ListTile(
            title: Text(thread.title),
            selected: thread.id == open.id,
            onTap: () => setState(() => _selected = thread.id),
          ),
      ],
    );
  }

  Widget _conversation(BuildContext context, PhoneThreadData open) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final m in open.messages)
                Align(
                  alignment: m.fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: BoxDecoration(
                      color: m.fromMe
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Semantics(
                      label: m.fromMe ? 'You said' : '${open.title} said',
                      child: Text(m.text),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (widget.sendDisabledReason case final reason?)
          Padding(padding: const EdgeInsets.all(12), child: Text(reason))
        else ...[
          if (widget.notice case final notice?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(notice, style: Theme.of(context).textTheme.bodySmall),
            ),
          _compose(context),
        ],
      ],
    );
  }

  Widget _compose(BuildContext context) {
    final over = _length > widget.maxLength;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Message',
                // Counted in UTF-16 units, so what the field accepts is what
                // the engine and the relay accept.
                helperText: '$_length / ${widget.maxLength}',
                errorText: over ? 'Too long' : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send',
            icon: const Icon(Icons.send),
            onPressed: _canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}
