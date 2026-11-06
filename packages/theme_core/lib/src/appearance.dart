import 'resolver.dart';
import 'theme_document.dart';
import 'variant.dart';

/// The player's stored appearance choice (07-apps.md, The player's setting).
class AppearanceSetting {
  /// Creates a setting.
  const AppearanceSetting({
    required this.themeId,
    required this.variant,
    this.documentMode = false,
    this.updatedAt,
  });

  /// First-launch default: System, normal.
  const AppearanceSetting.initial()
    : themeId = systemThemeId,
      variant = ThemeVariant.normal,
      documentMode = false,
      updatedAt = null;

  /// Reads a setting stored by [toJson]; unreadable fields fall back to the
  /// first-launch values.
  factory AppearanceSetting.fromJson(Map<String, dynamic> json) {
    final id = json['themeId'];
    final variant = json['variant'];
    final at = json['updatedAt'];
    return AppearanceSetting(
      themeId: id is String && id.isNotEmpty ? id : systemThemeId,
      variant:
          (variant is String ? ThemeVariant.fromJsonKey(variant) : null) ??
          ThemeVariant.normal,
      documentMode: json['documentMode'] == true,
      updatedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  /// `system`, a built-in id or a custom theme id.
  final String themeId;

  /// The chosen variant.
  final ThemeVariant variant;

  /// Remembered Document mode preference.
  final bool documentMode;

  /// When the setting last changed.
  final DateTime? updatedAt;

  /// JSON-shaped form for local storage.
  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'variant': variant.jsonKey,
    'documentMode': documentMode,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };
}

/// The outcome of applying a setting. The stored setting is never changed by
/// applying it, so a later import or a theme with the variant restores it.
class AppliedAppearance {
  /// Creates an outcome.
  const AppliedAppearance({
    required this.theme,
    required this.usedSystem,
    required this.themeMissing,
    required this.variantUnavailable,
  });

  /// The resolved tokens to draw with.
  final ResolvedTheme theme;

  /// Whether System (OS brightness) chose the theme.
  final bool usedSystem;

  /// Whether the stored theme id was not found, so System was used. The
  /// settings screen says so.
  final bool themeMissing;

  /// Whether the stored variant is not provided, so `normal` was used. The
  /// drop-down shows a note.
  final bool variantUnavailable;
}

/// Resolution steps of 07-apps.md, The player's setting.
///
/// System picks Night Desk for a dark OS and Manila for a light one; call
/// again when [osBrightness] changes to follow it live.
AppliedAppearance applyAppearance(
  AppearanceSetting setting,
  ThemeResolver resolver, {
  required ThemeBrightness osBrightness,
}) {
  var themeId = setting.themeId;
  var usedSystem = themeId == systemThemeId;
  var themeMissing = false;
  if (!usedSystem && resolver.lookup(themeId) == null) {
    usedSystem = true;
    themeMissing = true;
  }
  if (usedSystem) {
    themeId = osBrightness == ThemeBrightness.dark
        ? BuiltInIds.nightDesk
        : BuiltInIds.manila;
  }
  final provided = resolver
      .availableVariants(themeId)
      .contains(setting.variant);
  return AppliedAppearance(
    theme: resolver.resolve(
      themeId,
      provided ? setting.variant : ThemeVariant.normal,
    ),
    usedSystem: usedSystem,
    themeMissing: themeMissing,
    variantUnavailable: !provided,
  );
}
