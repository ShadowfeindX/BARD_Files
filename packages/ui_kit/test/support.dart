import 'dart:io';

import 'package:flutter/material.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

/// Reads the built-in themes straight from `theme_core`'s asset folder, so
/// widget tests do not need an asset bundle.
ThemeResolver testResolver() {
  const codec = ThemeCodec();
  return ThemeResolver(
    builtIns: [
      for (final file in const ['phosphor', 'manila', 'night-desk'])
        codec
            .decode(
              File('../theme_core/assets/themes/$file.json').readAsStringSync(),
            )
            .document!,
    ],
  );
}

/// A Flutter theme for widget tests: [themeId] in [variant].
ThemeData testTheme({
  String themeId = BuiltInIds.nightDesk,
  ThemeVariant variant = ThemeVariant.normal,
}) => buildBardThemeData(testResolver().resolve(themeId, variant));
