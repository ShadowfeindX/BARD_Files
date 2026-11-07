import 'package:flutter/material.dart';

import 'theme/bard_tokens.dart';

/// A window of the workstation shell: a 1 px `windowEdge` border, a
/// `windowRaised` title bar and a `window` body (07-apps.md, Window edge).
///
/// With [expand] the window fills the height it is given and the body takes
/// the space under the title bar (put it in an `Expanded` or a sized box);
/// without it the window is as tall as its body.
class ShellWindow extends StatelessWidget {
  /// Creates a window titled [title] around [child].
  const ShellWindow({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.actions = const [],
    this.accent,
    this.expand = false,
  });

  /// Title bar text.
  final String title;

  /// Window body.
  final Widget child;

  /// Optional widget before the title, for example a kind chip.
  final Widget? leading;

  /// Optional title bar controls.
  final List<Widget> actions;

  /// Colour of a 4 px band above the title bar, for example the Handler
  /// accent (`supervisor`).
  final Color? accent;

  /// Whether the body fills the window's height.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = BardTokens.of(context);
    final text = Theme.of(context).textTheme;
    final bar = Container(
      color: tokens.windowRaised,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: Text(title, style: text.titleMedium)),
          ...actions,
        ],
      ),
    );
    // A Material, not a decorated box, so list tiles inside can paint their
    // selection and ink on the window.
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: tokens.window,
        shape: Border.all(color: tokens.windowEdge),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accent != null) Container(height: 4, color: accent),
            bar,
            Divider(height: 1, color: tokens.windowEdge),
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
