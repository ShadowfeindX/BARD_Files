import 'package:flutter/material.dart';
import 'package:theme_core/theme_core.dart';

import 'bard_tokens.dart';

/// Maps a resolved theme onto a Flutter [ThemeData] (07-apps.md, Layering:
/// `ui_kit` owns the mapping from tokens to `ThemeData`).
///
/// Every colour comes from [resolved]; nothing here is a literal. Windows are
/// square with a 1 px `windowEdge` border; the app bar and window title bars
/// are `windowRaised`.
ThemeData buildBardThemeData(ResolvedTheme resolved) {
  final t = BardTokens(resolved);
  final dark = ThemeData.estimateBrightnessForColor(t.desk) == Brightness.dark;
  final (failure, onFailure) = t.chip(ChipKind.failure);
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: t.signalFill,
    onPrimary: t.onSignalFill,
    primaryContainer: t.signalFill,
    onPrimaryContainer: t.onSignalFill,
    secondary: t.signal,
    onSecondary: t.window,
    error: failure,
    onError: onFailure,
    surface: t.window,
    onSurface: t.ink,
    onSurfaceVariant: t.inkMuted,
    outline: t.windowEdge,
    outlineVariant: t.rule,
    surfaceContainerLowest: t.desk,
    surfaceContainerLow: t.window,
    surfaceContainer: t.window,
    surfaceContainerHigh: t.windowRaised,
    surfaceContainerHighest: t.windowRaised,
    secondaryContainer: t.labelCell,
    onSecondaryContainer: t.ink,
    tertiaryContainer: t.signalFill,
    onTertiaryContainer: t.onSignalFill,
    errorContainer: failure,
    onErrorContainer: onFailure,
  );
  final edge = BorderSide(color: t.windowEdge);
  const square = RoundedRectangleBorder();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.desk,
    canvasColor: t.window,
    dividerColor: t.rule,
    dividerTheme: DividerThemeData(color: t.rule, space: 1, thickness: 1),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.windowRaised,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: edge),
    ),
    cardTheme: CardThemeData(
      color: t.window,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(side: edge),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.window,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: edge),
    ),
    listTileTheme: ListTileThemeData(
      textColor: t.ink,
      iconColor: t.signal,
      selectedColor: t.onSignalFill,
      selectedTileColor: t.signalFill,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.signalFill,
        foregroundColor: t.onSignalFill,
        shape: square,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.signal,
        side: BorderSide(color: t.signal),
        shape: square,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.signal, shape: square),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: edge,
        borderRadius: BorderRadius.zero,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: edge,
        borderRadius: BorderRadius.zero,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: t.signal, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      labelStyle: TextStyle(color: t.inkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.labelCell,
      labelStyle: TextStyle(color: t.ink),
      side: edge,
      shape: square,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.windowRaised,
      contentTextStyle: TextStyle(color: t.ink),
      shape: RoundedRectangleBorder(side: edge),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: ThemeData(brightness: scheme.brightness).textTheme
        .apply(bodyColor: t.ink, displayColor: t.ink),
  );
}
