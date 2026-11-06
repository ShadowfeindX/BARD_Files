import 'colour.dart';
import 'variant.dart';

/// Id reserved for the selector's System option. It is never a document.
const String systemThemeId = 'system';

/// Selector label of the System option, as agreed by D on 2026-11-05 (T13).
const String systemThemeLabel = 'System';

/// Ids of the built-in themes.
abstract final class BuiltInIds {
  /// Phosphor (dark green).
  static const String phosphor = 'phosphor';

  /// Manila (light beige).
  static const String manila = 'manila';

  /// Night Desk (dark blue).
  static const String nightDesk = 'night-desk';

  /// All built-in ids.
  static const List<String> all = [phosphor, manila, nightDesk];
}

/// A token-name to colour map for one variant.
typedef TokenMap = Map<String, ThemeColor>;

/// Where a derived theme gets its unset values from.
class ThemeBase {
  /// Creates a base reference.
  const ThemeBase({required this.id, required this.tokenSet});

  /// Id of a built-in or custom theme.
  final String id;

  /// The base's token set when this theme was derived or last saved.
  final int tokenSet;
}

/// One theme document: **full** (`variants`) or **derived** (`base` plus
/// sparse `overrides`). Built-in, custom and imported themes share this shape
/// (07-apps.md, Theme document).
class ThemeDocument {
  /// A full theme holding complete token maps.
  ThemeDocument.full({
    required this.id,
    required this.name,
    required this.brightness,
    required this.tokenSet,
    required Map<ThemeVariant, TokenMap> variants,
    this.copiedFrom,
  }) : base = null,
       _maps = variants;

  /// A derived theme holding only the tokens it overrides.
  ThemeDocument.derived({
    required this.id,
    required this.name,
    required this.brightness,
    required this.tokenSet,
    required ThemeBase this.base,
    required Map<ThemeVariant, TokenMap> overrides,
  }) : copiedFrom = null,
       _maps = overrides;

  /// Stable id. Custom themes use a locally generated UUID.
  final String id;

  /// Display name; plain text only.
  final String name;

  /// Light or dark hint.
  final ThemeBrightness brightness;

  /// The token set the theme was made for.
  final int tokenSet;

  /// The theme a full theme was duplicated from, used only to find the
  /// fallback built-in.
  final String? copiedFrom;

  /// Base reference; non-null exactly for derived themes.
  final ThemeBase? base;

  final Map<ThemeVariant, TokenMap> _maps;

  /// Whether the theme is derived.
  bool get isDerived => base != null;

  /// The variants the document itself stores, in enum order.
  List<ThemeVariant> get ownVariants => [
    for (final v in ThemeVariant.values)
      if (_maps.containsKey(v)) v,
  ];

  /// The stored map for [variant] (complete when full, sparse when derived),
  /// or null when the document does not store it.
  TokenMap? mapFor(ThemeVariant variant) => _maps[variant];
}
