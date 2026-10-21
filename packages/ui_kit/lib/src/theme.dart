import 'package:flutter/material.dart';

/// Plain placeholder theme for the D demo.
///
/// The "Top Secret" dossier look (07 §Shared UI kit) is designed after D's
/// feedback; until then result colors come from this one place so the
/// real theme replaces it without touching widgets. Result colors live here;
/// small layout sizes stay in the widgets for now.
abstract final class BardTheme {
  /// Semantic colors for check outcomes, shared by widgets that show results.
  static const Color success = Color(0xFF2E7D32);

  /// Partial-success color.
  static const Color partial = Color(0xFFF9A825);

  /// Failure color.
  static const Color failure = Color(0xFFC62828);

  /// Light placeholder theme.
  static ThemeData light() => _build(Brightness.light);

  /// Dark placeholder theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF37474F),
        brightness: brightness,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
