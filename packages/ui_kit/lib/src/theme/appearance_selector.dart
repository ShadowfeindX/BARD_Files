import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:theme_core/theme_core.dart';

import 'theme_controller.dart';

/// Theme and variant drop-downs plus "Reset to System" (07-apps.md, Theme
/// selector). Custom themes and the editor are not part of this selector yet.
class AppearanceSelector extends StatelessWidget {
  /// Creates the selector over [controller].
  const AppearanceSelector({super.key, required this.controller});

  /// The setting being edited.
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final setting = controller.setting.value;
        final applied = controller.applied.value;
        final themeValue = applied.themeMissing
            ? systemThemeId
            : setting.themeId;
        final variantValue = applied.variantUnavailable
            ? ThemeVariant.normal
            : setting.variant;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Theme'),
              child: DropdownButton<String>(
                key: const ValueKey('appearance-theme'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: themeValue,
                items: [
                  for (final c in controller.choices)
                    DropdownMenuItem(value: c.id, child: Text(c.label)),
                ],
                onChanged: (id) {
                  if (id != null) controller.selectTheme(id);
                },
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Rendering'),
              child: DropdownButton<ThemeVariant>(
                key: const ValueKey('appearance-variant'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: variantValue,
                items: [
                  for (final v in controller.variants)
                    DropdownMenuItem(value: v, child: Text(v.label)),
                ],
                onChanged: (v) {
                  if (v != null) controller.selectVariant(v);
                },
              ),
            ),
            if (applied.themeMissing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'The chosen theme is not installed; System is used.',
                  key: ValueKey('appearance-theme-missing'),
                ),
              ),
            if (applied.variantUnavailable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${setting.variant.label} is not available in this theme; '
                  'using Normal.',
                  key: const ValueKey('appearance-variant-note'),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('appearance-reset'),
              onPressed: controller.resetToSystem,
              child: const Text('Reset to System'),
            ),
          ],
        );
      },
    );
  }
}

/// Opens the selector in a dialog.
Future<void> showAppearanceDialog(
  BuildContext context,
  ThemeController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Appearance'),
    content: SizedBox(
      width: 320,
      child: AppearanceSelector(controller: controller),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
