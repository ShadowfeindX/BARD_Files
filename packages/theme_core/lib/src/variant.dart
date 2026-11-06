/// How a theme renders: the four variants of 07-apps.md (Theme document).
enum ThemeVariant {
  /// The theme's default look. Every theme provides it.
  normal('normal', 'Normal'),

  /// Result chips separated by lightness.
  highContrast('highContrast', 'High contrast'),

  /// Result chips safe for protan and deutan vision.
  redGreenSafe('redGreenSafe', 'Red-green safe'),

  /// Result chips safe for tritan vision.
  blueYellowSafe('blueYellowSafe', 'Blue-yellow safe');

  const ThemeVariant(this.jsonKey, this.label);

  /// The key used in theme files.
  final String jsonKey;

  /// Drop-down label, as agreed by D on 2026-11-05 (T13). The UI may look
  /// the text up by [labelKey] instead, for translation.
  final String label;

  /// Key for looking the label up in a string table.
  String get labelKey => 'themeVariant.$jsonKey';

  /// The variant with [jsonKey], or null.
  static ThemeVariant? fromJsonKey(String key) {
    for (final variant in values) {
      if (variant.jsonKey == key) return variant;
    }
    return null;
  }
}

/// Light or dark: a hint for platform chrome and the last-resort fallback
/// built-in (07-apps.md, Fallback built-in).
enum ThemeBrightness {
  /// Dark surfaces (Phosphor, Night Desk).
  dark,

  /// Light surfaces (Manila).
  light,
}
