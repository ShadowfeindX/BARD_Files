import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:theme_core/theme_core.dart';

import 'theme_builder.dart';

/// Asset paths of the built-in themes, which `theme_core` ships as JSON.
const Map<String, String> builtInThemeAssets = {
  BuiltInIds.phosphor: 'packages/theme_core/assets/themes/phosphor.json',
  BuiltInIds.manila: 'packages/theme_core/assets/themes/manila.json',
  BuiltInIds.nightDesk: 'packages/theme_core/assets/themes/night-desk.json',
};

/// Reads and validates the built-in themes from [bundle]. Throws a
/// [StateError] naming every problem when a file is invalid, because the
/// built-ins ship with the app and a bad one is a build error.
Future<List<ThemeDocument>> loadBuiltInThemes(AssetBundle bundle) async {
  const codec = ThemeCodec();
  final documents = <ThemeDocument>[];
  for (final entry in builtInThemeAssets.entries) {
    final result = codec.decode(await bundle.loadString(entry.value));
    final document = result.document;
    if (document == null) {
      throw StateError(
        'Built-in theme ${entry.key} is invalid:\n'
        '${result.problems.join('\n')}',
      );
    }
    documents.add(document);
  }
  return documents;
}

/// One entry of the theme selector.
class ThemeChoice {
  /// Creates a choice.
  const ThemeChoice(this.id, this.label);

  /// `system` or a theme id.
  final String id;

  /// Drop-down label.
  final String label;
}

/// Holds the player's appearance setting and the Flutter theme it produces
/// (07-apps.md, The player's setting).
///
/// System follows [osBrightness], which the app updates when the platform
/// brightness changes. The controller never stores anything: it reports each
/// change through [onChanged] and the app's repository saves it.
class ThemeController {
  /// Creates a controller over [resolver].
  ThemeController({
    required this.resolver,
    AppearanceSetting initial = const AppearanceSetting.initial(),
    ThemeBrightness brightness = ThemeBrightness.dark,
    this.onChanged,
  }) : _setting = signal(initial),
       osBrightness = signal(brightness) {
    applied = computed(
      () => applyAppearance(
        _setting.value,
        resolver,
        osBrightness: osBrightness.value,
      ),
    );
    themeData = computed(() => buildBardThemeData(applied.value.theme));
  }

  /// Loads the built-ins from [bundle] and creates a controller over them.
  static Future<ThemeController> load(
    AssetBundle bundle, {
    AppearanceSetting initial = const AppearanceSetting.initial(),
    ThemeBrightness brightness = ThemeBrightness.dark,
    void Function(AppearanceSetting setting)? onChanged,
  }) async => ThemeController(
    resolver: ThemeResolver(builtIns: await loadBuiltInThemes(bundle)),
    initial: initial,
    brightness: brightness,
    onChanged: onChanged,
  );

  /// Looks themes up and resolves them.
  final ThemeResolver resolver;

  /// Called with the new setting after every change.
  final void Function(AppearanceSetting setting)? onChanged;

  final Signal<AppearanceSetting> _setting;

  /// The OS brightness System follows; the app keeps it current.
  final Signal<ThemeBrightness> osBrightness;

  /// The stored setting. Applying it never changes it.
  ReadonlySignal<AppearanceSetting> get setting => _setting;

  /// The setting applied: resolved tokens plus the notices for a missing
  /// theme or variant.
  late final ReadonlySignal<AppliedAppearance> applied;

  /// The Flutter theme for [applied].
  late final ReadonlySignal<ThemeData> themeData;

  /// System first, then the built-in themes.
  List<ThemeChoice> get choices => [
    const ThemeChoice(systemThemeId, systemThemeLabel),
    for (final id in BuiltInIds.all) ThemeChoice(id, resolver.lookup(id)!.name),
  ];

  /// The variants the applied theme provides, in drop-down order.
  List<ThemeVariant> get variants => [
    for (final v in ThemeVariant.values)
      if (applied.value.theme.availableVariants.contains(v)) v,
  ];

  /// Chooses a theme by id (`system` or a theme id). The variant is kept.
  void selectTheme(String themeId) => _change(
    AppearanceSetting(
      themeId: themeId,
      variant: _setting.value.variant,
      documentMode: _setting.value.documentMode,
      updatedAt: DateTime.now(),
    ),
  );

  /// Chooses how the theme renders.
  void selectVariant(ThemeVariant variant) => _change(
    AppearanceSetting(
      themeId: _setting.value.themeId,
      variant: variant,
      documentMode: _setting.value.documentMode,
      updatedAt: DateTime.now(),
    ),
  );

  /// Returns to System with the normal variant, the first-launch look.
  void resetToSystem() => _change(
    AppearanceSetting(
      themeId: systemThemeId,
      variant: ThemeVariant.normal,
      documentMode: _setting.value.documentMode,
      updatedAt: DateTime.now(),
    ),
  );

  void _change(AppearanceSetting next) {
    _setting.value = next;
    onChanged?.call(next);
  }
}
