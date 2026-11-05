/// How a theme renders: the four variants of 07-apps.md (Theme document).
enum ThemeVariant {
  /// The theme's default look. Every theme provides it.
  normal('normal'),

  /// Result chips separated by lightness.
  highContrast('highContrast'),

  /// Result chips safe for protan and deutan vision.
  redGreenSafe('redGreenSafe'),

  /// Result chips safe for tritan vision.
  blueYellowSafe('blueYellowSafe');

  const ThemeVariant(this.jsonKey);

  /// The key used in theme files.
  final String jsonKey;

  /// Key for the drop-down label. The wording is D's to confirm (T7 e), so
  /// the UI looks the text up by this key instead of the package holding it.
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
